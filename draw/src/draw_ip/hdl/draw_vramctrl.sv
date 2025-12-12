//-----------------------------------------------------------------------------
// Title       : 描画VRAM制御
// Filename    : draw_vramctrl.sv
// Description : STEP-1 (PATBLT) + バースト分割 + FIFOレイテンシ対応
//-----------------------------------------------------------------------------

module draw_vramctrl (
    input wire       CLK,
    input wire       ARST,
    input wire [1:0] RESOL,
    input wire       REG_EXE, // 実行開始信号

    // コマンドFIFO I/F
    output logic        CMD_RD_EN,
    input  wire  [31:0] CMD_RDATA,
    input  wire         CMD_EMPTY,

    // ステータス出力
    output logic DRAW_BUSY,

    // AXI4 Master Write
    output logic [31:0] M_AXI_AWADDR,
    output logic [ 7:0] M_AXI_AWLEN,
    output logic        M_AXI_AWVALID,
    input  wire         M_AXI_AWREADY,
    output logic [31:0] M_AXI_WDATA,
    output logic [ 3:0] M_AXI_WSTRB,
    output logic        M_AXI_WLAST,
    output logic        M_AXI_WVALID,
    input  wire         M_AXI_WREADY,
    input  wire         M_AXI_BVALID,
    output logic        M_AXI_BREADY,

    // AXI4 Master Read (STEP-1 未使用)
    output logic [31:0] M_AXI_ARADDR,
    output logic [ 7:0] M_AXI_ARLEN,
    output logic        M_AXI_ARVALID,
    input  wire         M_AXI_ARREADY,
    input  wire  [31:0] M_AXI_RDATA,
    input  wire         M_AXI_RLAST,
    input  wire         M_AXI_RVALID,
    output logic        M_AXI_RREADY
);

  // Readチャンネル未使用固定
  assign M_AXI_ARADDR  = '0;
  assign M_AXI_ARLEN   = '0;
  assign M_AXI_ARVALID = 1'b0;
  assign M_AXI_RREADY  = 1'b0;

  // 内部レジスタ
  logic [31:0] r_vram_base;
  logic [10:0] r_frm_width;
  logic [10:0] r_frm_height;
  logic [10:0] r_area_posx, r_area_posy;
  logic [10:0] r_area_sizx, r_area_sizy;
  logic [31:0] r_fcolor;
  logic signed [11:0] r_pat_dposx, r_pat_dposy;
  logic [10:0] r_pat_dsizx, r_pat_dsizy;

  logic [31:0] current_opcode;
  logic [10:0] line_counter;
  logic [10:0] pixel_counter;
  logic [10:0] rem_pixels_in_line;
  logic [31:0] current_wr_addr;

  // 実行許可フラグ (REG_EXEでセット、IDLEに戻るまで維持)
  logic running;

  // ステートマシン
  typedef enum logic [4:0] {
    S_IDLE,
    // Opcode Fetch
    S_FETCH_REQ,
    S_FETCH_DAT,
    S_DECODE,
    // Parameter Fetch
    S_PRM_REQ_1,
    S_PRM_DAT_1,
    S_PRM_REQ_2,
    S_PRM_DAT_2,
    // PATBLT Execution
    S_PAT_LINE_INIT,
    S_PAT_SUB_START,
    S_PAT_REQ,
    S_PAT_DATA,
    S_PAT_RESP,
    S_PAT_SUB_NEXT,
    S_PAT_LINE_NEXT
  } state_t;

  state_t state;

  // どのコマンドのパラメータを取得中かを示すフラグ
  typedef enum logic [1:0] {
    CMD_NONE,
    CMD_FRAME,
    CMD_AREA,
    CMD_PAT
  } cmd_type_t;
  cmd_type_t processing_cmd;

  //-------------------------------------------------------------------------
  // Main Process
  //-------------------------------------------------------------------------
  always_ff @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      state <= S_IDLE;
      CMD_RD_EN <= 1'b0;
      DRAW_BUSY <= 1'b0;
      running <= 1'b0;
      processing_cmd <= CMD_NONE;

      M_AXI_AWVALID <= 1'b0;
      M_AXI_WVALID <= 1'b0;
      M_AXI_BREADY <= 1'b0;
      M_AXI_AWADDR <= '0;
      M_AXI_AWLEN <= '0;
      M_AXI_WDATA <= '0;
      M_AXI_WSTRB <= 4'b1111;
      M_AXI_WLAST <= 1'b0;
    end else begin
      // 実行開始トリガー
      if (REG_EXE) running <= 1'b1;

      case (state)
        //-------------------------------------------------------------
        // IDLE: コマンド待ち
        //-------------------------------------------------------------
        S_IDLE: begin
          CMD_RD_EN <= 1'b0;
          // FIFOにデータがあり、かつ実行許可が出ている場合
          if (!CMD_EMPTY && (running || REG_EXE)) begin
            DRAW_BUSY <= 1'b1;
            state <= S_FETCH_REQ;
          end else begin
            DRAW_BUSY <= 1'b0;
            if (CMD_EMPTY) running <= 1'b0;  // 空になったら停止
          end
        end

        //-------------------------------------------------------------
        // Opcode Fetch
        //-------------------------------------------------------------
        S_FETCH_REQ: begin
          CMD_RD_EN <= 1'b1;  // Read Request
          state <= S_FETCH_DAT;
        end

        S_FETCH_DAT: begin
          CMD_RD_EN <= 1'b0;
          current_opcode <= CMD_RDATA;  // Capture Data (Latency 1)
          state <= S_DECODE;
        end

        //-------------------------------------------------------------
        // DECODE
        //-------------------------------------------------------------
        S_DECODE: begin
          case (current_opcode[7:0])
            8'h00:   state <= S_IDLE;  // NOP
            8'h20: begin  // SETFRAME (3 words)
              processing_cmd <= CMD_FRAME;
              state <= S_PRM_REQ_1;
            end
            8'h21: begin  // SETDRAWAREA (3 words)
              processing_cmd <= CMD_AREA;
              state <= S_PRM_REQ_1;
            end
            8'h23: begin  // SETFCOLOR (2 words)
              state <= S_PRM_REQ_1;  // Special case: only 1 param word
              processing_cmd <= CMD_NONE;  // No 2nd param
            end
            8'h81: begin  // PATBLT (3 words)
              processing_cmd <= CMD_PAT;
              state <= S_PRM_REQ_1;
            end
            8'h0F: begin  // EODL
              running <= 1'b0;  // Stop execution
              state   <= S_IDLE;
            end
            default: state <= S_IDLE;
          endcase
        end

        //-------------------------------------------------------------
        // Parameter 1 Fetch (SETFCOLOR finishes here)
        //-------------------------------------------------------------
        S_PRM_REQ_1: begin
          CMD_RD_EN <= 1'b1;
          state <= S_PRM_DAT_1;
        end

        S_PRM_DAT_1: begin
          CMD_RD_EN <= 1'b0;
          // Store Parameter 1 based on Opcode
          case (current_opcode[7:0])
            8'h20:   r_vram_base <= CMD_RDATA;
            8'h21: begin
              r_area_posx <= CMD_RDATA[26:16];
              r_area_posy <= CMD_RDATA[10:0];
            end
            8'h23: begin  // SETFCOLOR (Done)
              r_fcolor <= CMD_RDATA;
              state <= S_IDLE;
            end
            8'h81: begin
              r_pat_dposx <= CMD_RDATA[27:16];
              r_pat_dposy <= CMD_RDATA[11:0];
            end
            default: state <= S_IDLE;
          endcase

          // If command needs 2nd parameter
          if (current_opcode[7:0] != 8'h23) begin
            state <= S_PRM_REQ_2;
          end
        end

        //-------------------------------------------------------------
        // Parameter 2 Fetch
        //-------------------------------------------------------------
        S_PRM_REQ_2: begin
          CMD_RD_EN <= 1'b1;
          state <= S_PRM_DAT_2;
        end

        S_PRM_DAT_2: begin
          CMD_RD_EN <= 1'b0;
          // Store Parameter 2
          case (processing_cmd)
            CMD_FRAME: begin
              r_frm_width <= CMD_RDATA[26:16];
              r_frm_height <= CMD_RDATA[10:0];
              state <= S_IDLE;
            end
            CMD_AREA: begin
              r_area_sizx <= CMD_RDATA[26:16];
              r_area_sizy <= CMD_RDATA[10:0];
              state <= S_IDLE;
            end
            CMD_PAT: begin
              r_pat_dsizx <= CMD_RDATA[26:16];
              r_pat_dsizy <= CMD_RDATA[10:0];
              // Start PATBLT Execution
              line_counter <= 0;
              state <= S_PAT_LINE_INIT;
            end
            default: state <= S_IDLE;
          endcase
        end

        //-------------------------------------------------------------
        // PATBLT Execution (Line Loop)
        //-------------------------------------------------------------
        S_PAT_LINE_INIT: begin
          // Address Calculation
          current_wr_addr <= r_vram_base + 
                        (( (r_pat_dposy + line_counter) * r_frm_width + r_pat_dposx ) << 2);
          rem_pixels_in_line <= r_pat_dsizx;
          state <= S_PAT_SUB_START;
        end

        // Burst Split Calculation
        S_PAT_SUB_START: begin
          M_AXI_AWADDR <= current_wr_addr;
          if (rem_pixels_in_line > 256) begin
            M_AXI_AWLEN <= 8'd255;
          end else begin
            M_AXI_AWLEN <= rem_pixels_in_line[7:0] - 8'd1;
          end
          pixel_counter <= 0;
          state <= S_PAT_REQ;
        end

        // Address Request
        S_PAT_REQ: begin
          M_AXI_AWVALID <= 1'b1;
          if (M_AXI_AWREADY && M_AXI_AWVALID) begin
            M_AXI_AWVALID <= 1'b0;
            state <= S_PAT_DATA;
          end
        end

        // Data Transfer
        S_PAT_DATA: begin
          M_AXI_WDATA  <= r_fcolor;
          M_AXI_WVALID <= 1'b1;
          M_AXI_WSTRB  <= 4'b1111;

          if (pixel_counter == M_AXI_AWLEN) M_AXI_WLAST <= 1'b1;
          else M_AXI_WLAST <= 1'b0;

          if (M_AXI_WREADY && M_AXI_WVALID) begin
            if (M_AXI_WLAST) begin
              M_AXI_WVALID <= 1'b0;
              M_AXI_WLAST <= 1'b0;
              state <= S_PAT_RESP;
            end else begin
              pixel_counter <= pixel_counter + 1;
            end
          end
        end

        // Response Wait
        S_PAT_RESP: begin
          M_AXI_BREADY <= 1'b1;
          if (M_AXI_BVALID && M_AXI_BREADY) begin
            M_AXI_BREADY <= 1'b0;
            state <= S_PAT_SUB_NEXT;
          end
        end

        // Check Next Burst
        S_PAT_SUB_NEXT: begin
          logic [8:0] transferred;
          transferred = M_AXI_AWLEN + 9'd1;

          current_wr_addr    <= current_wr_addr + (transferred << 2);
          rem_pixels_in_line <= rem_pixels_in_line - transferred;

          if (rem_pixels_in_line > transferred) state <= S_PAT_SUB_START;
          else state <= S_PAT_LINE_NEXT;
        end

        // Check Next Line
        S_PAT_LINE_NEXT: begin
          line_counter <= line_counter + 1;
          if (line_counter + 1 >= r_pat_dsizy) state <= S_IDLE;
          else state <= S_PAT_LINE_INIT;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
