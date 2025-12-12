//-----------------------------------------------------------------------------
// Title       : 描画レジスタ制御 (SystemVerilog版)
// Module      : draw_regctrl
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
    input  wire  DRAW_BUSY,  // 描画実行中
    output logic DRW_IRQ,    // 割り込み出力
    output logic REG_EXE,    // 実行開始信号 (DRAWCTRL[0])
    output logic REG_RST,    // ソフトリセット (DRAWCTRL[1])

    // コマンドFIFO I/F
    input  wire         CMD_RD_EN,  // FIFO読み出し
    output logic [31:0] CMD_RDATA,  // FIFOデータ
    output logic        CMD_EMPTY,  // FIFO空
    output logic        CMD_FULL    // FIFO満杯
);

  //-------------------------------------------------------------------------
  // レジスタ定義
  //-------------------------------------------------------------------------
  logic [31:0] reg_drawctrl;  // 0x2000
  logic [31:0] reg_drawint;  // 0x2010

  // アドレスデコード
  logic [15:0] waddr_mask;
  logic [15:0] raddr_mask;
  assign waddr_mask = WRADDR & 16'hFFFF;
  assign raddr_mask = RDADDR & 16'hFFFF;

  // ソフトリセット・実行信号
  assign REG_RST = reg_drawctrl[1];
  assign REG_EXE = reg_drawctrl[0];

  // 内部リセット
  logic internal_rst;
  assign internal_rst = ARST | REG_RST;

  // FIFO書き込み信号
  logic cmd_fifo_we;
  assign cmd_fifo_we = WREN && (waddr_mask == 16'h200C);

  // FIFOステータス用
  logic [10:0] cmd_count;

  //-------------------------------------------------------------------------
  // レジスタ書き込み (always_ff)
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

      // レジスタ書き込み処理
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

      // ソフトリセットの自動クリア (1サイクルパルス的動作)
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
  // コマンドFIFO (簡易実装)
  //-------------------------------------------------------------------------
  logic [31:0] mem[0:2047];
  logic [10:0] wptr, rptr;
  logic [11:0] count;

  assign CMD_EMPTY = (count == 0);
  assign CMD_FULL  = (count == 2048);
  assign cmd_count = count[10:0];
  assign CMD_RDATA = mem[rptr];

  always_ff @(posedge CLK or posedge internal_rst) begin
    if (internal_rst) begin
      wptr  <= 0;
      rptr  <= 0;
      count <= 0;
    end else begin
      // Write
      if (cmd_fifo_we && !CMD_FULL) begin
        mem[wptr] <= WDATA;
        wptr <= wptr + 1;
      end
      // Read
      if (CMD_RD_EN && !CMD_EMPTY) begin
        rptr <= rptr + 1;
      end
      // Count update
      if (cmd_fifo_we && !CMD_FULL && !(CMD_RD_EN && !CMD_EMPTY)) count <= count + 1;
      else if (!(cmd_fifo_we && !CMD_FULL) && (CMD_RD_EN && !CMD_EMPTY)) count <= count - 1;
    end
  end

endmodule
