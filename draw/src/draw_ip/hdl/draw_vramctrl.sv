//-----------------------------------------------------------------------------
// Title       : 描画VRAM制御 (SystemVerilog版)
// Module      : draw_vramctrl
// Description : STEP-1 (PATBLT) 対応 + バースト分割対応
//-----------------------------------------------------------------------------

module draw_vramctrl (
    input wire       CLK,
    input wire       ARST,
    input wire [1:0] RESOL,

    // コマンドFIFO I/F
    output logic        CMD_RD_EN,
    input  wire  [31:0] CMD_RDATA,
    input  wire         CMD_EMPTY,

    // ステータス出力
    output logic DRAW_BUSY,

    // AXI4 Master Write Address
    output logic [31:0] M_AXI_AWADDR,
    output logic [ 7:0] M_AXI_AWLEN,
    output logic        M_AXI_AWVALID,
    input  wire         M_AXI_AWREADY,

    // AXI4 Master Write Data
    output logic [31:0] M_AXI_WDATA,
    output logic [ 3:0] M_AXI_WSTRB,
    output logic        M_AXI_WLAST,
    output logic        M_AXI_WVALID,
    input  wire         M_AXI_WREADY,

    // AXI4 Master Write Response
    input  wire  M_AXI_BVALID,
    output logic M_AXI_BREADY,

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

  //-------------------------------------------------------------------------
  // 内部レジスタ (コマンドパラメータ保持)
  //-------------------------------------------------------------------------
  // SETFRAME
  logic [31:0] r_vram_base;
  logic [10:0] r_frm_width;
  logic [10:0] r_frm_height;

  // SETDRAWAREA
  logic [10:0] r_area_posx, r_area_posy;
  logic [10:0] r_area_sizx, r_area_sizy;

  // SETFCOLOR
  logic [31:0] r_fcolor;

  // PATBLT parameters
  logic signed [11:0] r_pat_dposx, r_pat_dposy;
  logic [10:0] r_pat_dsizx, r_pat_dsizy;

  // 作業用
  logic [31:0] current_opcode;
  logic [10:0] line_counter;  // Yループ
  logic [10:0] pixel_counter;  // バースト内カウンタ
  logic [10:0] rem_pixels_in_line;  // 1ライン内の残りピクセル数
  logic [31:0] current_wr_addr;  // 現在の書き込みアドレス

  //-------------------------------------------------------------------------
  // ステートマシン (enum)
  //-------------------------------------------------------------------------
  typedef enum logic [4:0] {
    S_IDLE,
    S_FETCH_CMD,
    S_DECODE,
    // パラメータ取得
    S_GET_FRAME_1,
    S_GET_FRAME_2,
    S_GET_AREA_1,
    S_GET_AREA_2,
    S_GET_COLOR_1,
    S_GET_PAT_1,
    S_GET_PAT_2,
    // PATBLT実行
    S_PAT_LINE_INIT,  // ライン開始準備
    S_PAT_SUB_START,  // 分割バースト計算
    S_PAT_REQ,        // AW発行
    S_PAT_DATA,       // W発行
    S_PAT_RESP,       // B応答待ち
    S_PAT_SUB_NEXT,   // 次の分割バーストへ
    S_PAT_LINE_NEXT   // 次のラインへ
  } state_t;

  state_t state;

  always_ff @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      state <= S_IDLE;
      CMD_RD_EN <= 1'b0;
      DRAW_BUSY <= 1'b0;

      M_AXI_AWVALID <= 1'b0;
      M_AXI_WVALID <= 1'b0;
      M_AXI_BREADY <= 1'b0;
      M_AXI_AWADDR <= '0;
      M_AXI_AWLEN <= '0;
      M_AXI_WDATA <= '0;
      M_AXI_WSTRB <= 4'b1111;
      M_AXI_WLAST <= 1'b0;
    end else begin
      case (state)
        //-------------------------------------------------------------
        // IDLE
        //-------------------------------------------------------------
        S_IDLE: begin
          CMD_RD_EN <= 1'b0;
          if (!CMD_EMPTY) begin
            DRAW_BUSY <= 1'b1;
            CMD_RD_EN <= 1'b1;
            state <= S_FETCH_CMD;
          end else begin
            DRAW_BUSY <= 1'b0;
          end
        end

        S_FETCH_CMD: begin
          CMD_RD_EN <= 1'b0;
          current_opcode <= CMD_RDATA;
          state <= S_DECODE;
        end

        //-------------------------------------------------------------
        // DECODE
        //-------------------------------------------------------------
        S_DECODE: begin
          case (current_opcode[7:0])
            8'h00:   state <= S_IDLE;  // NOP
            8'h20: begin  // SETFRAME
              CMD_RD_EN <= 1'b1;
              state <= S_GET_FRAME_1;
            end
            8'h21: begin  // SETDRAWAREA
              CMD_RD_EN <= 1'b1;
              state <= S_GET_AREA_1;
            end
            8'h23: begin  // SETFCOLOR
              CMD_RD_EN <= 1'b1;
              state <= S_GET_COLOR_1;
            end
            8'h81: begin  // PATBLT
              CMD_RD_EN <= 1'b1;
              state <= S_GET_PAT_1;
            end
            8'h0F: begin  // EODL
              // 本当はここで割り込み発生指示をREGCTRLへ送るなどの処理が必要
              state <= S_IDLE;
            end
            default: state <= S_IDLE;
          endcase
        end

        //-------------------------------------------------------------
        // パラメータ取得 (SETFRAME)
        //-------------------------------------------------------------
        S_GET_FRAME_1: begin
          CMD_RD_EN <= 1'b1;
          r_vram_base <= CMD_RDATA;
          state <= S_GET_FRAME_2;
        end
        S_GET_FRAME_2: begin
          CMD_RD_EN <= 1'b0;
          r_frm_width <= CMD_RDATA[26:16];
          r_frm_height <= CMD_RDATA[10:0];
          state <= S_IDLE;
        end

        //-------------------------------------------------------------
        // パラメータ取得 (SETDRAWAREA)
        //-------------------------------------------------------------
        S_GET_AREA_1: begin
          CMD_RD_EN <= 1'b1;
          r_area_posx <= CMD_RDATA[26:16];
          r_area_posy <= CMD_RDATA[10:0];
          state <= S_GET_AREA_2;
        end
        S_GET_AREA_2: begin
          CMD_RD_EN <= 1'b0;
          r_area_sizx <= CMD_RDATA[26:16];
          r_area_sizy <= CMD_RDATA[10:0];
          state <= S_IDLE;
        end

        //-------------------------------------------------------------
        // パラメータ取得 (SETFCOLOR)
        //-------------------------------------------------------------
        S_GET_COLOR_1: begin
          CMD_RD_EN <= 1'b0;
          r_fcolor <= CMD_RDATA;
          state <= S_IDLE;
        end

        //-------------------------------------------------------------
        // パラメータ取得 (PATBLT)
        //-------------------------------------------------------------
        S_GET_PAT_1: begin
          CMD_RD_EN <= 1'b1;
          r_pat_dposx <= CMD_RDATA[27:16];  // signed
          r_pat_dposy <= CMD_RDATA[11:0];  // signed
          state <= S_GET_PAT_2;
        end
        S_GET_PAT_2: begin
          CMD_RD_EN <= 1'b0;
          r_pat_dsizx <= CMD_RDATA[26:16];
          r_pat_dsizy <= CMD_RDATA[10:0];

          line_counter <= 0;
          state <= S_PAT_LINE_INIT;
        end

        //-------------------------------------------------------------
        // PATBLT 実行ループ
        //-------------------------------------------------------------

        // 1. ライン描画開始の初期計算
        S_PAT_LINE_INIT: begin
          // 現在のYラインの先頭アドレス計算
          // Address = Base + ((DPOSY + line) * FrameWidth + DPOSX) * 4
          current_wr_addr <= r_vram_base +
                        (( (r_pat_dposy + line_counter) * r_frm_width + r_pat_dposx ) << 2);

          // 残りピクセル数を初期化
          rem_pixels_in_line <= r_pat_dsizx;

          state <= S_PAT_SUB_START;
        end

        // 2. 分割バースト計算 (AXI4 Max Burst Length = 256)
        S_PAT_SUB_START: begin
          M_AXI_AWADDR <= current_wr_addr;

          // 残りが256ピクセルより多い場合は256回(AWLEN=255)バースト、それ以下なら残り全部
          if (rem_pixels_in_line > 256) begin
            M_AXI_AWLEN <= 8'd255;  // 256 beats
          end else begin
            M_AXI_AWLEN <= rem_pixels_in_line[7:0] - 8'd1;
          end

          pixel_counter <= 0;
          state <= S_PAT_REQ;
        end

        // 3. アドレス発行
        S_PAT_REQ: begin
          M_AXI_AWVALID <= 1'b1;
          if (M_AXI_AWREADY && M_AXI_AWVALID) begin
            M_AXI_AWVALID <= 1'b0;
            state <= S_PAT_DATA;
          end
        end

        // 4. データ転送
        S_PAT_DATA: begin
          M_AXI_WDATA  <= r_fcolor;
          M_AXI_WVALID <= 1'b1;

          // Last判定
          if (pixel_counter == M_AXI_AWLEN) begin
            M_AXI_WLAST <= 1'b1;
          end else begin
            M_AXI_WLAST <= 1'b0;
          end

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

        // 5. 書き込み応答待機
        S_PAT_RESP: begin
          M_AXI_BREADY <= 1'b1;
          if (M_AXI_BVALID && M_AXI_BREADY) begin
            M_AXI_BREADY <= 1'b0;
            state <= S_PAT_SUB_NEXT;
          end
        end

        // 6. 次の分割バーストへの更新
        S_PAT_SUB_NEXT: begin
          // 今回転送したピクセル数 (AWLEN + 1)
          logic [8:0] transferred;
          transferred <= M_AXI_AWLEN + 9'd1;

          // アドレスと残りピクセル数を更新
          current_wr_addr    <= current_wr_addr + (transferred << 2);
          rem_pixels_in_line <= rem_pixels_in_line - transferred;

          if (rem_pixels_in_line > transferred) begin
            // まだ同じラインに描画残りがある -> 次のバーストへ
            state <= S_PAT_SUB_START;
          end else begin
            // 1ライン完了 -> 次のラインへ
            state <= S_PAT_LINE_NEXT;
          end
        end

        // 7. 次のラインへ
        S_PAT_LINE_NEXT: begin
          line_counter <= line_counter + 1;
          if (line_counter + 1 >= r_pat_dsizy) begin
            // 全描画完了
            state <= S_IDLE;
          end else begin
            // 次のライン
            state <= S_PAT_LINE_INIT;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
