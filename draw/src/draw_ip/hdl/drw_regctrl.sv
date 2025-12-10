//-----------------------------------------------------------------------------
// Title       : 描画回路 レジスタ制御
// File        : drw_regctrl.sv
//-----------------------------------------------------------------------------
module drw_regctrl (
    input wire CLK,
    input wire ARST,

    // RegBus Interface
    input  wire [15:0] WRADDR,
    input  wire [ 3:0] BYTEEN,
    input  wire        WREN,
    input  wire [31:0] WDATA,
    input  wire [15:0] RDADDR,
    input  wire        RDEN,
    output reg  [31:0] RDATA,

    // Internal Control / Status
    input  wire DRW_BUSY,     // 描画実行中フラグ
    input  wire DRW_IRQ_IN,   // 描画完了割り込み入力
    output reg  DRW_IRQ_OUT,  // CPUへの割り込み出力
    output reg  SOFT_RST,     // ソフトリセット出力
    output reg  DRW_START,    // 描画開始パルス

    // Command FIFO Interface
    input  wire        CMD_FIFO_FULL,
    output reg         CMD_FIFO_WR,
    output reg  [31:0] CMD_FIFO_WDATA,
    input  wire [10:0] CMD_FIFO_COUNT
);

  //-------------------------------------------------------------------------
  // アドレスデコード定数
  //-------------------------------------------------------------------------
  localparam ADDR_DRAWCTRL = 16'h2000;
  localparam ADDR_DRAWSTAT = 16'h2004;
  localparam ADDR_DRAWBUFSTAT = 16'h2008;
  localparam ADDR_DRAWCMD = 16'h200C;
  localparam ADDR_DRAWINT = 16'h2010;

  //-------------------------------------------------------------------------
  // 内部レジスタ
  //-------------------------------------------------------------------------
  reg  reg_int_en;  // 割り込み許可

  // アドレスヒット信号
  wire hit_drawctrl = (WRADDR == ADDR_DRAWCTRL);
  wire hit_drawcmd = (WRADDR == ADDR_DRAWCMD);
  wire hit_drawint = (WRADDR == ADDR_DRAWINT);

  //-------------------------------------------------------------------------
  // Write 動作
  //-------------------------------------------------------------------------
  always @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      SOFT_RST    <= 1'b0;
      DRW_START   <= 1'b0;
      reg_int_en  <= 1'b0;
      DRW_IRQ_OUT <= 1'b0;
      // FIFO
      CMD_FIFO_WR    <= 1'b0;
      CMD_FIFO_WDATA <= 32'h0;
    end else begin
      // パルス信号のクリア
      SOFT_RST    <= 1'b0;
      DRW_START   <= 1'b0;
      CMD_FIFO_WR <= 1'b0;

      // 割り込み信号の生成 (立ち上がりエッジ検出等を想定、あるいはレベル)
      if (DRW_IRQ_IN && reg_int_en) begin
        DRW_IRQ_OUT <= 1'b1;
      end

      if (WREN) begin
        // DRAWCTRL (0x2000)
        if (hit_drawctrl) begin
          if (BYTEEN[0] && WDATA[1]) SOFT_RST <= 1'b1;  // Bit1: RST
          if (BYTEEN[0] && WDATA[0]) DRW_START <= 1'b1;  // Bit0: EXE
        end

        // DRAWCMD (0x200C) -> FIFO Push
        // FULLの場合は書き込みをドロップするか、仕様次第。ここでは単純に書き込む。
        if (hit_drawcmd) begin
          CMD_FIFO_WR    <= 1'b1;
          CMD_FIFO_WDATA <= WDATA;
        end

        // DRAWINT (0x2010)
        if (hit_drawint) begin
          if (BYTEEN[0]) begin
            // Bit1: INTCLR (1書き込みでクリア)
            if (WDATA[1]) DRW_IRQ_OUT <= 1'b0;
            // Bit0: INTENBL
            reg_int_en <= WDATA[0];
          end
        end
      end
    end
  end

  //-------------------------------------------------------------------------
  // Read 動作
  //-------------------------------------------------------------------------
  always_comb begin
    RDATA = 32'h0;
    if (RDEN) begin
      case (RDADDR)
        ADDR_DRAWCTRL: RDATA = 32'h0;  // Write Only
        ADDR_DRAWSTAT: RDATA = {13'h0, 3'b000  /*ERR*/, 15'h0, DRW_BUSY};
        ADDR_DRAWBUFSTAT:
        RDATA = {
          14'h0,
          CMD_FIFO_FULL,
          (CMD_FIFO_COUNT == 0),  // EMPTY
          5'h0,
          CMD_FIFO_COUNT
        };
        ADDR_DRAWCMD: RDATA = 32'h0;  // Write Only
        ADDR_DRAWINT: RDATA = {30'h0, 1'b0  /*CLR*/, reg_int_en};
        default: RDATA = 32'h0;
      endcase
    end
  end

endmodule
