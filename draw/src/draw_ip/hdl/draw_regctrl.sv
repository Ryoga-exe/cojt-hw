//-----------------------------------------------------------------------------
// Title       : 描画レジスタ制御
// Filename    : draw_regctrl.sv
//-----------------------------------------------------------------------------

module draw_regctrl (
    input wire CLK,
    input wire ARST,

    // レジスタバス
    input  wire  [15:0] WRADDR,
    input  wire  [ 3:0] BYTEEN,
    input  wire         WREN,
    input  wire  [31:0] WDATA,
    input  wire  [15:0] RDADDR,
    input  wire         RDEN,
    output logic [31:0] RDATA,

    // ステータス・制御信号
    input  wire  DRAW_BUSY,
    output logic DRW_IRQ,
    output logic REG_EXE,
    output logic REG_RST,

    // コマンドFIFO I/F
    input  wire        CMD_RD_EN,
    output wire [31:0] CMD_RDATA,
    output wire        CMD_EMPTY,
    output wire        CMD_FULL
);

  // レジスタ定義
  logic [31:0] reg_drawctrl;  // 0x2000
  logic [31:0] reg_drawint;  // 0x2010

  // アドレスデコード
  logic [15:0] waddr_mask;
  logic [15:0] raddr_mask;
  assign waddr_mask = WRADDR & 16'hFFFF;
  assign raddr_mask = RDADDR & 16'hFFFF;

  // 制御信号出力
  assign REG_RST = reg_drawctrl[1];
  assign REG_EXE = reg_drawctrl[0];

  // 内部リセット
  logic internal_rst;
  assign internal_rst = ARST | REG_RST;

  // FIFO書き込み制御
  logic cmd_fifo_we;
  assign cmd_fifo_we = WREN && (waddr_mask == 16'h200C);

  // FIFOデータカウント
  logic [10:0] cmd_count;

  //-------------------------------------------------------------------------
  // レジスタ書き込み
  //-------------------------------------------------------------------------
  always_ff @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      reg_drawctrl <= '0;
      reg_drawint  <= '0;
      DRW_IRQ      <= 1'b0;
    end else begin
      // 割り込みクリア (Write 1 to Clear)
      if (WREN && (waddr_mask == 16'h2010) && WDATA[1]) begin
        DRW_IRQ <= 1'b0;
      end

      if (WREN) begin
        case (waddr_mask)
          16'h2000: begin  // DRAWCTRL
            if (BYTEEN[0]) reg_drawctrl[7:0] <= WDATA[7:0];
          end
          16'h2010: begin  // DRAWINT
            if (BYTEEN[0]) reg_drawint[0] <= WDATA[0];  // INTENBL
          end
          default: ;
        endcase
      end

      // ソフトリセットの自動クリア (パルス動作)
      if (reg_drawctrl[1]) begin
        reg_drawctrl[1] <= 1'b0;
      end
    end
  end

  //-------------------------------------------------------------------------
  // レジスタ読み出し
  //-------------------------------------------------------------------------
  always_ff @(posedge CLK) begin
    RDATA <= '0;
    if (RDEN) begin
      case (raddr_mask)
        16'h2000: RDATA <= reg_drawctrl;
        16'h2004: RDATA <= {13'h0, 3'b000, 15'h0, DRAW_BUSY};  // DRAWSTAT
        16'h2008: RDATA <= {14'h0, CMD_FULL, CMD_EMPTY, 5'h0, cmd_count};  // DRAWBUFSTAT
        16'h2010: RDATA <= reg_drawint;
        default:  RDATA <= '0;
      endcase
    end
  end

  //-------------------------------------------------------------------------
  // コマンドFIFO インスタンス化
  //-------------------------------------------------------------------------
  // 32bit input / 32bit output / 2048 depth
  // 独立クロック用IPポート仕様に合わせて接続 (wr_clk = rd_clk = CLK)

  fifo_32in32out_2048depth u_cmd_fifo (
      .rst          (internal_rst),  // Reset
      .wr_clk       (CLK),           // Write Clock
      .rd_clk       (CLK),           // Read Clock
      .din          (WDATA),         // [31:0] Write Data
      .wr_en        (cmd_fifo_we),   // Write Enable
      .rd_en        (CMD_RD_EN),     // Read Enable
      .dout         (CMD_RDATA),     // [31:0] Read Data
      .full         (CMD_FULL),      // Full Flag
      .overflow     (),              // Overflow (Unused)
      .empty        (CMD_EMPTY),     // Empty Flag
      .valid        (),              // Valid (Unused)
      .underflow    (),              // Underflow (Unused)
      .wr_data_count(cmd_count)      // [10:0] Write Data Count
  );

endmodule
