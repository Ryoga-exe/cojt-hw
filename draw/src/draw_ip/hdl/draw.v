//-----------------------------------------------------------------------------
// Title       : 描画回路の最上位階層
// Project     : draw
// Filename    : draw.v
//-----------------------------------------------------------------------------

module draw #(
    parameter integer C_M_AXI_THREAD_ID_WIDTH = 1,
    parameter integer C_M_AXI_ADDR_WIDTH      = 32,
    parameter integer C_M_AXI_DATA_WIDTH      = 32,
    parameter integer C_M_AXI_AWUSER_WIDTH    = 1,
    parameter integer C_M_AXI_ARUSER_WIDTH    = 1,
    parameter integer C_M_AXI_WUSER_WIDTH     = 4,   // Warning対策
    parameter integer C_M_AXI_RUSER_WIDTH     = 4,   // Warning対策
    parameter integer C_M_AXI_BUSER_WIDTH     = 1,

    /* 以下は未対応だけどコンパイルエラー回避のため付加しておく */
    parameter integer C_INTERCONNECT_M_AXI_WRITE_ISSUING = 0,
    parameter integer C_M_AXI_SUPPORTS_READ              = 1,
    parameter integer C_M_AXI_SUPPORTS_WRITE             = 1,
    parameter integer C_M_AXI_TARGET                     = 0,
    parameter integer C_M_AXI_BURST_LEN                  = 0,
    parameter integer C_OFFSET_WIDTH                     = 0
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
    // AXI3 output wire [4-1:0]                  M_AXI_AWREGION,
    output wire [                      4-1:0] M_AXI_AWQOS,
    output wire [   C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER,
    output wire                               M_AXI_AWVALID,
    input  wire                               M_AXI_AWREADY,

    // Master Interface Write Data
    // AXI3 output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]     M_AXI_WID,
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
    // AXI3 output wire [4-1:0]                  M_AXI_ARREGION,
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

  //-------------------------------------------------------------------------
  // AXI4 Master Interface Fixed Signals (Write Address Channel)
  //-------------------------------------------------------------------------
  assign M_AXI_AWID    = {C_M_AXI_THREAD_ID_WIDTH{1'b0}};
  assign M_AXI_AWSIZE  = 3'b010;  // 4 Bytes (32bit) [cite: 16]
  assign M_AXI_AWBURST = 2'b01;   // INCR type [cite: 17]
  assign M_AXI_AWLOCK  = 2'b00;   // Normal access
  assign M_AXI_AWCACHE = 4'b0011; // Bufferable and Modifiable [cite: 17]
  assign M_AXI_AWPROT  = 3'h0;
  assign M_AXI_AWQOS   = 4'h0;
  assign M_AXI_AWUSER  = {C_M_AXI_AWUSER_WIDTH{1'b0}};

  //-------------------------------------------------------------------------
  // AXI4 Master Interface Fixed Signals (Write Data Channel)
  //-------------------------------------------------------------------------
  assign M_AXI_WUSER   = {C_M_AXI_WUSER_WIDTH{1'b0}};

  //-------------------------------------------------------------------------
  // AXI4 Master Interface Fixed Signals (Read Address Channel)
  //-------------------------------------------------------------------------
  assign M_AXI_ARID    = {C_M_AXI_THREAD_ID_WIDTH{1'b0}};
  assign M_AXI_ARSIZE  = 3'b010;  // 4 Bytes (32bit) [cite: 20]
  assign M_AXI_ARBURST = 2'b01;   // INCR type [cite: 20]
  assign M_AXI_ARLOCK  = 2'b00;
  assign M_AXI_ARCACHE = 4'b0011; // Bufferable and Modifiable [cite: 21]
  assign M_AXI_ARPROT  = 3'h0;
  assign M_AXI_ARQOS   = 4'h0;
  assign M_AXI_ARUSER  = {C_M_AXI_ARUSER_WIDTH{1'b0}};

  //-------------------------------------------------------------------------
  // Reset Synchronization (ACLK Domain)
  //-------------------------------------------------------------------------
  reg [1:0] arst_ff;
  always @(posedge ACLK) begin
    arst_ff <= {arst_ff[0], ~ARESETN};
  end
  wire ARST = arst_ff[1];  // Active High Reset [cite: 22, 23]

  //-------------------------------------------------------------------------
  // Resolution Synchronization
  //-------------------------------------------------------------------------
  reg [1:0] RESOL_ff;
  always @(posedge ACLK) begin
    RESOL_ff <= RESOL;
  end

  //-------------------------------------------------------------------------
  // Internal Signals
  //-------------------------------------------------------------------------
  // Register Control <-> VRAM Control Interface
  wire        draw_busy;  // 描画実行中フラグ (DRAWSTAT.BUSY)
  wire        cmd_fifo_empty;  // コマンドFIFO空フラグ
  wire        cmd_fifo_full;  // コマンドFIFO満杯フラグ (Option)
  wire        cmd_fifo_rd_en;  // コマンドFIFO読み出し要求
  wire [31:0] cmd_fifo_rdata;  // コマンドFIFO読み出しデータ

  //-------------------------------------------------------------------------
  // Submodule Instances
  //-------------------------------------------------------------------------

  // 描画レジスタ制御 & コマンドFIFO管理
  draw_regctrl u_draw_regctrl (
      .CLK (ACLK),
      .ARST(ARST),

      // レジスタバス I/F
      .WRADDR(WRADDR),
      .BYTEEN(BYTEEN),
      .WREN  (WREN),
      .WDATA (WDATA),
      .RDADDR(RDADDR),
      .RDEN  (RDEN),
      .RDATA (RDATA),

      // ステータス・割り込み
      .DRAW_BUSY(draw_busy),
      .DRW_IRQ  (DRW_IRQ),

      // コマンドFIFO I/F (Write側は内部、Read側を出力)
      .CMD_RD_EN(cmd_fifo_rd_en),
      .CMD_RDATA(cmd_fifo_rdata),
      .CMD_EMPTY(cmd_fifo_empty),
      .CMD_FULL (cmd_fifo_full)
  );

  // 描画VRAM制御 & コマンド解析・実行エンジン
  draw_vramctrl u_draw_vramctrl (
      .CLK  (ACLK),
      .ARST (ARST),
      .RESOL(RESOL_ff),

      // コマンドFIFO I/F (Read側)
      .CMD_RD_EN(cmd_fifo_rd_en),
      .CMD_RDATA(cmd_fifo_rdata),
      .CMD_EMPTY(cmd_fifo_empty),

      // ステータス出力
      .DRAW_BUSY(draw_busy),

      // AXI4 Master Write Address
      .M_AXI_AWADDR (M_AXI_AWADDR),
      .M_AXI_AWLEN  (M_AXI_AWLEN),
      .M_AXI_AWVALID(M_AXI_AWVALID),
      .M_AXI_AWREADY(M_AXI_AWREADY),

      // AXI4 Master Write Data
      .M_AXI_WDATA (M_AXI_WDATA),
      .M_AXI_WSTRB (M_AXI_WSTRB),
      .M_AXI_WLAST (M_AXI_WLAST),
      .M_AXI_WVALID(M_AXI_WVALID),
      .M_AXI_WREADY(M_AXI_WREADY),

      // AXI4 Master Write Response
      .M_AXI_BVALID(M_AXI_BVALID),
      .M_AXI_BREADY(M_AXI_BREADY),

      // AXI4 Master Read Address (STEP-2以降で使用)
      .M_AXI_ARADDR (M_AXI_ARADDR),
      .M_AXI_ARLEN  (M_AXI_ARLEN),
      .M_AXI_ARVALID(M_AXI_ARVALID),
      .M_AXI_ARREADY(M_AXI_ARREADY),

      // AXI4 Master Read Data (STEP-2以降で使用)
      .M_AXI_RDATA (M_AXI_RDATA),
      .M_AXI_RLAST (M_AXI_RLAST),
      .M_AXI_RVALID(M_AXI_RVALID),
      .M_AXI_RREADY(M_AXI_RREADY)
  );

endmodule
