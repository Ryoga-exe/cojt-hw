module filter #(
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
    output       FLT_IRQ,

    /* レジスタバス */
    input  [15:0] WRADDR,
    input  [ 3:0] BYTEEN,
    input         WREN,
    input  [31:0] WDATA,
    input  [15:0] RDADDR,
    input         RDEN,
    output [31:0] RDATA
);

  // Write Address (AW)
  assign M_AXI_AWID    = 'b0;
  assign M_AXI_AWSIZE  = 2;     // 4 Byte
  assign M_AXI_AWBURST = 2'b01;
  assign M_AXI_AWLOCK  = 1'b0;
  assign M_AXI_AWCACHE = 4'b0011;
  assign M_AXI_AWPROT  = 3'h0;
  assign M_AXI_AWQOS   = 4'h0;
  assign M_AXI_AWUSER  = 'b0;

  // Write Data(W)
  assign M_AXI_WUSER  = 'b0;

  // Read Address (AR)
  assign M_AXI_ARID    = 'b0;
  assign M_AXI_ARSIZE  = 2;     // 4 Byte
  assign M_AXI_ARBURST = 2'b01;
  assign M_AXI_ARLOCK  = 1'b0;
  assign M_AXI_ARCACHE = 4'b0011;
  assign M_AXI_ARPROT  = 3'h0;
  assign M_AXI_ARQOS   = 4'h0;
  assign M_AXI_ARUSER  = 'b0;

  /* ACLKで同期化したリセット信号ARSTの作成 */
  reg [1:0] arst_ff;

  always @(posedge ACLK) begin
    arst_ff <= {arst_ff[0], ~ARESETN};
  end

  wire ARST = arst_ff[1];

  /* RESOLをFFに取り込んでから利用（vramctrl用） */
  reg [1:0] RESOL_ff;

  always @(posedge ACLK) begin
    RESOL_ff <= RESOL;
  end

  wire        fltvc_INT;
  wire        fltrg_RSTS;
  wire        fltrg_START;
  wire [31:0] fltrg_VRAMSRC;
  wire [31:0] fltrg_VRAMFRM;
  wire [31:0] fltrg_COLOR;

  wire        fltpc_WDATAVLD;
  wire [31:0] fltpc_WDATA;

  wire        fltvc_SDATAVLD;
  wire [31:0] fltvc_SDATA;
  wire        fltvc_BUSY;

  flt_regctrl u_flt_regctrl (
      .CLK   (ACLK),
      .ARST  (ARST),
      .WRADDR(WRADDR),
      .BYTEEN(BYTEEN),
      .WREN  (WREN),
      .WDATA (WDATA),
      .RDADDR(RDADDR),
      .RDEN  (RDEN),
      .RDATA (RDATA),

      .FLTVC_INT    (fltvc_INT),
      .FLTVC_BUSY   (fltvc_BUSY),
      .FLTRG_IRQ    (FLT_IRQ),
      .FLTRG_RSTS   (fltrg_RSTS),
      .FLTRG_START  (fltrg_START),
      .FLTRG_VRAMSRC(fltrg_VRAMSRC),
      .FLTRG_VRAMFRM(fltrg_VRAMFRM),
      .FLTRG_COLOR  (fltrg_COLOR)
  );

  flt_proc u_flt_proc (
      .CLK (ACLK),
      .ARST(ARST),
      .RSTS(fltrg_RSTS),

      .FLTRG_COLOR(fltrg_COLOR),

      .FLTVC_SDATAVLD(fltvc_SDATAVLD),
      .FLTVC_SDATA   (fltvc_SDATA),

      .FLTPC_WDATAVLD(fltpc_WDATAVLD),
      .FLTPC_WDATA   (fltpc_WDATA)
  );

  /* アドレスはpython制御プログラムで指定 */
  wire [31:0] VRAMCTRL_ARADDR;
  wire [31:0] VRAMCTRL_AWADDR;
  assign M_AXI_ARADDR = VRAMCTRL_ARADDR[31:0];
  assign M_AXI_AWADDR = VRAMCTRL_AWADDR[31:0];

  flt_vramctrl u_flt_vramctrl (
      .CLK  (ACLK),
      .ARST (ARST),
      .RSTS (fltrg_RSTS),
      .RESOL(RESOL_ff),

      .ARADDR (VRAMCTRL_ARADDR),
      .ARVALID(M_AXI_ARVALID),
      .ARLEN  (M_AXI_ARLEN),
      .ARREADY(M_AXI_ARREADY),
      .RDATA  (M_AXI_RDATA),
      .RLAST  (M_AXI_RLAST),
      .RVALID (M_AXI_RVALID),
      .RREADY (M_AXI_RREADY),

      .AWADDR (VRAMCTRL_AWADDR),
      .AWVALID(M_AXI_AWVALID),
      .AWLEN  (M_AXI_AWLEN),
      .AWREADY(M_AXI_AWREADY),
      .WDATA  (M_AXI_WDATA),
      .WLAST  (M_AXI_WLAST),
      .WVALID (M_AXI_WVALID),
      .WSTRB  (M_AXI_WSTRB),
      .WREADY (M_AXI_WREADY),
      .BVALID (M_AXI_BVALID),
      .BREADY (M_AXI_BREADY),

      .FLTRG_START  (fltrg_START),
      .FLTRG_VRAMSRC(fltrg_VRAMSRC),
      .FLTRG_VRAMFRM(fltrg_VRAMFRM),

      .FLTPC_WDATAVLD(fltpc_WDATAVLD),
      .FLTPC_WDATA   (fltpc_WDATA),

      .FLTVC_SDATAVLD(fltvc_SDATAVLD),
      .FLTVC_SDATA   (fltvc_SDATA),

      .FLTVC_BUSY(fltvc_BUSY),
      .FLTVC_INT (fltvc_INT)
  );

endmodule  // filter
