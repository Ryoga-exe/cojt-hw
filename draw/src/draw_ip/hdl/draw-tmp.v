//-----------------------------------------------------------------------------
// Title       : 描画回路の最上位階層
// File        : draw.v
//-----------------------------------------------------------------------------

module draw #(
    parameter integer C_M_AXI_THREAD_ID_WIDTH = 1,
    parameter integer C_M_AXI_ADDR_WIDTH      = 32,
    parameter integer C_M_AXI_DATA_WIDTH      = 32,
    parameter integer C_M_AXI_AWUSER_WIDTH    = 1,
    parameter integer C_M_AXI_ARUSER_WIDTH    = 1,
    parameter integer C_M_AXI_WUSER_WIDTH     = 4,
    parameter integer C_M_AXI_RUSER_WIDTH     = 4,
    parameter integer C_M_AXI_BUSER_WIDTH     = 1
) (
    // System Signals
    input wire ACLK,
    input wire ARESETN,

    // Master Interface Write Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_AWID,
    output wire [     C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output wire [                      8-1:0] M_AXI_AWLEN,
    output wire [                      3-1:0] M_AXI_AWSIZE,
    output wire [                      2-1:0] M_AXI_AWBURST,
    output wire [                      2-1:0] M_AXI_AWLOCK,
    output wire [                      4-1:0] M_AXI_AWCACHE,
    output wire [                      3-1:0] M_AXI_AWPROT,
    output wire [                      4-1:0] M_AXI_AWQOS,
    output wire [   C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
    output wire                               M_AXI_AWVALID,
    input  wire                               M_AXI_AWREADY,

    // Master Interface Write Data
    output wire [  C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                            M_AXI_WLAST,
    output wire [ C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER,
    output wire                            M_AXI_WVALID,
    input  wire                            M_AXI_WREADY,

    // Master Interface Write Response
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_BID,
    input  wire [                      2-1:0] M_AXI_BRESP,
    input  wire [    C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                               M_AXI_BVALID,
    output wire                               M_AXI_BREADY,

    // Master Interface Read Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_ARID,
    output wire [     C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output wire [                      8-1:0] M_AXI_ARLEN,
    output wire [                      3-1:0] M_AXI_ARSIZE,
    output wire [                      2-1:0] M_AXI_ARBURST,
    output wire [                      2-1:0] M_AXI_ARLOCK,
    output wire [                      4-1:0] M_AXI_ARCACHE,
    output wire [                      3-1:0] M_AXI_ARPROT,
    output wire [                      4-1:0] M_AXI_ARQOS,
    output wire [   C_M_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER,
    output wire                               M_AXI_ARVALID,
    input  wire                               M_AXI_ARREADY,

    // Master Interface Read Data
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_RID,
    input  wire [     C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  wire [                      2-1:0] M_AXI_RRESP,
    input  wire                               M_AXI_RLAST,
    input  wire [    C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                               M_AXI_RVALID,
    output wire                               M_AXI_RREADY,

    /* 解像度切り替え */
    input  [1:0] RESOL,
    /* 割り込み */
    output       DRW_IRQ,

    /* レジスタバス */
    input  [15:0] WRADDR,
    input  [ 3:0] BYTEEN,
    input         WREN,
    input  [31:0] WDATA,
    input  [15:0] RDADDR,
    input         RDEN,
    output [31:0] RDATA
);

  //---------------------------------------------------------------------------
  // 内部信号定義
  //---------------------------------------------------------------------------
  // リセット
  wire        arst = ~ARESETN;
  wire        soft_rst;  // ソフトリセット (DRAWCTRL.RST)

  // レジスタ制御 -> メイン制御
  wire        drw_start;  // DRAWCTRL.EXE
  wire        drw_busy;  // DRAWSTAT.BUSY
  wire        drw_irq_in;  // 割り込み要求

  // コマンドFIFO関連
  wire        cmd_fifo_wr;
  wire [31:0] cmd_fifo_wdata;
  wire        cmd_fifo_rd;
  wire [31:0] cmd_fifo_rdata;
  wire        cmd_fifo_empty;
  wire        cmd_fifo_full;
  wire [10:0] cmd_fifo_count;  // 2048深度なので11bit必要

  // メイン制御 -> VRAM制御 (ライン単位のキック)
  wire        line_start;  // 1ライン処理開始
  wire        line_busy;  // 1ライン処理中
  wire [31:0] line_addr_dst;  // 書き込み先(背景)アドレス
  wire [31:0] line_addr_src;  // テクスチャアドレス
  wire [10:0] line_len;  // ピクセル数 (11bit幅: max 2048)

  // メイン制御 -> ピクセル処理 (パラメータ)
  wire [31:0] param_fcolor;  // 描画色
  wire        param_blend;  // ブレンド有効
  // ※その他、ステンシル設定などのパラメータが必要ですが、一旦省略

  // 画像データFIFO関連
  // SRC (Texture)
  wire src_fifo_wr, src_fifo_rd;
  wire [31:0] src_fifo_wdata, src_fifo_rdata;
  wire src_fifo_empty, src_fifo_full;
  wire [11:0] src_fifo_count;  // FIFO IPのdata_countは12bit

  // DST (Background Read)
  wire dst_fifo_wr, dst_fifo_rd;
  wire [31:0] dst_fifo_wdata, dst_fifo_rdata;
  wire dst_fifo_empty, dst_fifo_full;
  wire [11:0] dst_fifo_count;

  // WRT (Write Back)
  wire wrt_fifo_wr, wrt_fifo_rd;
  wire [31:0] wrt_fifo_wdata, wrt_fifo_rdata;
  wire wrt_fifo_empty, wrt_fifo_full;
  wire [11:0] wrt_fifo_count;


  //---------------------------------------------------------------------------
  // AXI固定値割り当て (Write Address / Data / Response)
  //---------------------------------------------------------------------------
  // 描画回路は32bitデータ幅、バースト転送を行う
  assign M_AXI_AWID    = 'b0;
  assign M_AXI_AWSIZE  = 3'b010; // 4 Byte (32bit)
  assign M_AXI_AWBURST = 2'b01;  // INCR
  assign M_AXI_AWLOCK  = 1'b0;
  assign M_AXI_AWCACHE = 4'b0011;
  assign M_AXI_AWPROT  = 3'h0;
  assign M_AXI_AWQOS   = 4'h0;
  assign M_AXI_AWUSER  = 'b0;
  assign M_AXI_WUSER   = 'b0;

  // Read Address
  assign M_AXI_ARID    = 'b0;
  assign M_AXI_ARSIZE  = 3'b010; // 4 Byte (32bit)
  assign M_AXI_ARBURST = 2'b01;  // INCR
  assign M_AXI_ARLOCK  = 1'b0;
  assign M_AXI_ARCACHE = 4'b0011;
  assign M_AXI_ARPROT  = 3'h0;
  assign M_AXI_ARQOS   = 4'h0;
  assign M_AXI_ARUSER  = 'b0;


  //---------------------------------------------------------------------------
  // サブモジュール接続
  //---------------------------------------------------------------------------

  // 1. レジスタ制御
  drw_regctrl u_drw_regctrl (
      .CLK (ACLK),
      .ARST(arst),

      // RegBus
      .WRADDR(WRADDR),
      .BYTEEN(BYTEEN),
      .WREN  (WREN),
      .WDATA (WDATA),
      .RDADDR(RDADDR),
      .RDEN  (RDEN),
      .RDATA (RDATA),

      // Status / Control
      .DRW_BUSY   (drw_busy),
      .DRW_IRQ_IN (drw_irq_in),
      .DRW_IRQ_OUT(DRW_IRQ),
      .SOFT_RST   (soft_rst),
      .DRW_START  (drw_start),

      // Command FIFO Interface (Push)
      .CMD_FIFO_FULL (cmd_fifo_full),
      .CMD_FIFO_WR   (cmd_fifo_wr),
      .CMD_FIFO_WDATA(cmd_fifo_wdata),
      .CMD_FIFO_COUNT(cmd_fifo_count)
  );

  // 2. コマンドバッファ (FIFO)
  // Xilinx FIFO IP (Common Clock Built-in FIFO想定)
  // 32bit x 2048depth
  fifo_32in32out_2048depth u_cmd_fifo (
      .clk       (ACLK),
      .rst       (arst | soft_rst),
      .din       (cmd_fifo_wdata),
      .wr_en     (cmd_fifo_wr),
      .rd_en     (cmd_fifo_rd),
      .dout      (cmd_fifo_rdata),
      .full      (cmd_fifo_full),
      .empty     (cmd_fifo_empty),
      .data_count({1'b0, cmd_fifo_count})  // data_countが12bitの場合
  );

  // 3. メイン制御 (コマンド解析 & アドレス生成)
  drw_mainctrl u_drw_mainctrl (
      .CLK      (ACLK),
      .ARST     (arst),
      .SOFT_RST (soft_rst),
      .DRW_START(drw_start),  // 開始トリガ
      .DRW_BUSY (drw_busy),   // Busy出力
      .DRW_IRQ  (drw_irq_in), // 完了割り込み

      // Command FIFO Interface (Pop)
      .CMD_FIFO_EMPTY(cmd_fifo_empty),
      .CMD_FIFO_RD   (cmd_fifo_rd),
      .CMD_FIFO_RDATA(cmd_fifo_rdata),

      // VRAM Control Interface (Line Kick)
      .LINE_START   (line_start),
      .LINE_BUSY    (line_busy),
      .LINE_ADDR_DST(line_addr_dst),
      .LINE_ADDR_SRC(line_addr_src),
      .LINE_LEN     (line_len),

      // Parameters to Pixel Proc
      .PARAM_FCOLOR(param_fcolor),
      .PARAM_BLEND (param_blend)
  );

  // 4. VRAM制御 (AXI Master & FIFO Control)
  drw_vramctrl u_drw_vramctrl (
      .CLK (ACLK),
      .ARST(arst | soft_rst),

      // AXI4 Read/Write Signals
      .M_AXI_ARADDR (M_AXI_ARADDR),
      .M_AXI_ARLEN  (M_AXI_ARLEN),
      .M_AXI_ARVALID(M_AXI_ARVALID),
      .M_AXI_ARREADY(M_AXI_ARREADY),
      .M_AXI_RDATA  (M_AXI_RDATA),
      .M_AXI_RLAST  (M_AXI_RLAST),
      .M_AXI_RVALID (M_AXI_RVALID),
      .M_AXI_RREADY (M_AXI_RREADY),

      .M_AXI_AWADDR (M_AXI_AWADDR),
      .M_AXI_AWLEN  (M_AXI_AWLEN),
      .M_AXI_AWVALID(M_AXI_AWVALID),
      .M_AXI_AWREADY(M_AXI_AWREADY),
      .M_AXI_WDATA  (M_AXI_WDATA),
      .M_AXI_WSTRB  (M_AXI_WSTRB),
      .M_AXI_WLAST  (M_AXI_WLAST),
      .M_AXI_WVALID (M_AXI_WVALID),
      .M_AXI_WREADY (M_AXI_WREADY),
      .M_AXI_BVALID (M_AXI_BVALID),
      .M_AXI_BREADY (M_AXI_BREADY),

      // Main Control Interface
      .LINE_START   (line_start),
      .LINE_BUSY    (line_busy),
      .LINE_ADDR_DST(line_addr_dst),
      .LINE_ADDR_SRC(line_addr_src),
      .LINE_LEN     (line_len),
      .PARAM_BLEND  (param_blend),    // ブレンド有効時はDST読み出しが必要

      // Data FIFO Interfaces
      // SRC (Write to FIFO)
      .SRC_FIFO_FULL (src_fifo_full),
      .SRC_FIFO_WR   (src_fifo_wr),
      .SRC_FIFO_WDATA(src_fifo_wdata),
      // DST (Write to FIFO)
      .DST_FIFO_FULL (dst_fifo_full),
      .DST_FIFO_WR   (dst_fifo_wr),
      .DST_FIFO_WDATA(dst_fifo_wdata),
      // WRT (Read from FIFO)
      .WRT_FIFO_EMPTY(wrt_fifo_empty),
      .WRT_FIFO_RD   (wrt_fifo_rd),
      .WRT_FIFO_RDATA(wrt_fifo_rdata),
      .WRT_FIFO_COUNT(wrt_fifo_count)
  );

  // 5. データFIFO (3つ)
  // SRC FIFO (Texture Data)
  fifo_32in32out_2048depth u_src_fifo (
      .clk(ACLK),
      .rst(arst | soft_rst),
      .din(src_fifo_wdata),
      .wr_en(src_fifo_wr),
      .full(src_fifo_full),
      .data_count(src_fifo_count),
      .dout(src_fifo_rdata),
      .rd_en(src_fifo_rd),
      .empty(src_fifo_empty)
  );
  // DST FIFO (Background Data)
  fifo_32in32out_2048depth u_dst_fifo (
      .clk(ACLK),
      .rst(arst | soft_rst),
      .din(dst_fifo_wdata),
      .wr_en(dst_fifo_wr),
      .full(dst_fifo_full),
      .data_count(dst_fifo_count),
      .dout(dst_fifo_rdata),
      .rd_en(dst_fifo_rd),
      .empty(dst_fifo_empty)
  );
  // WRT FIFO (Result Data)
  fifo_32in32out_2048depth u_wrt_fifo (
      .clk(ACLK),
      .rst(arst | soft_rst),
      .din(wrt_fifo_wdata),
      .wr_en(wrt_fifo_wr),
      .full(wrt_fifo_full),
      .data_count(wrt_fifo_count),
      .dout(wrt_fifo_rdata),
      .rd_en(wrt_fifo_rd),
      .empty(wrt_fifo_empty)
  );

  // 6. ピクセル処理
  drw_pixelproc u_drw_pixelproc (
      .CLK (ACLK),
      .ARST(arst | soft_rst),

      // Parameters
      .PARAM_FCOLOR(param_fcolor),
      .PARAM_BLEND (param_blend),

      // FIFO Interface
      .SRC_FIFO_EMPTY(src_fifo_empty),
      .SRC_FIFO_RD   (src_fifo_rd),
      .SRC_FIFO_RDATA(src_fifo_rdata),

      .DST_FIFO_EMPTY(dst_fifo_empty),
      .DST_FIFO_RD   (dst_fifo_rd),
      .DST_FIFO_RDATA(dst_fifo_rdata),

      .WRT_FIFO_FULL (wrt_fifo_full),
      .WRT_FIFO_WR   (wrt_fifo_wr),
      .WRT_FIFO_WDATA(wrt_fifo_wdata)
  );

endmodule
