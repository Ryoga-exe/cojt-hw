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
  // Reset synchronizer (ARESETN is async, internal ARST is sync / active-high)
  //-------------------------------------------------------------------------
  reg [1:0] arst_ff;
  always @(posedge ACLK) begin
    arst_ff <= {arst_ff[0], ~ARESETN};
  end
  wire ARST;
  assign ARST = arst_ff[1];

  //-------------------------------------------------------------------------
  // Resolution synchronizer (register once to avoid timing/sim glitches)
  //-------------------------------------------------------------------------
  reg [1:0] RESOL_ff;
  always @(posedge ACLK) begin
    RESOL_ff <= RESOL;
  end

  //-------------------------------------------------------------------------
  // AXI fixed signals (same policy as filter.v)
  //-------------------------------------------------------------------------
  assign M_AXI_AWID    = {C_M_AXI_THREAD_ID_WIDTH{1'b0}};
  assign M_AXI_AWSIZE  = 3'd2;  // 4 bytes / beat
  assign M_AXI_AWBURST = 2'b01;  // INCR
  assign M_AXI_AWLOCK  = 2'b00;
  assign M_AXI_AWCACHE = 4'b0000;
  assign M_AXI_AWPROT  = 3'b000;
  assign M_AXI_AWQOS   = 4'b0000;
  assign M_AXI_AWUSER  = {C_M_AXI_AWUSER_WIDTH{1'b0}};

  assign M_AXI_ARID    = {C_M_AXI_THREAD_ID_WIDTH{1'b0}};
  assign M_AXI_ARSIZE  = 3'd2;  // 4 bytes / beat
  assign M_AXI_ARBURST = 2'b01;  // INCR
  assign M_AXI_ARLOCK  = 2'b00;
  assign M_AXI_ARCACHE = 4'b0000;
  assign M_AXI_ARPROT  = 3'b000;
  assign M_AXI_ARQOS   = 4'b0000;
  assign M_AXI_ARUSER  = {C_M_AXI_ARUSER_WIDTH{1'b0}};

  assign M_AXI_WUSER   = {C_M_AXI_WUSER_WIDTH{1'b0}};

  //-------------------------------------------------------------------------
  // Internal wires (module partition)
  //-------------------------------------------------------------------------
  wire        DRWRG_RSTS;
  wire        DRWRG_START;

  // command buffer (DRAWCMD)
  wire        CMDFIFO_WREN;
  wire [31:0] CMDFIFO_WDATA;
  wire        CMDFIFO_FULL;

  wire        CMDFIFO_RDEN;
  wire [31:0] CMDFIFO_RDATA;
  wire        CMDFIFO_EMPTY;
  wire [15:0] CMDFIFO_COUNT;

  // draw proc <-> vramctrl
  wire        DRWVC_SDATAVLD;
  wire [31:0] DRWVC_SDATA;

  wire        DRWPC_WADDRVLD;
  wire [31:0] DRWPC_WADDR;
  wire        DRWPC_WDATAVLD;
  wire [31:0] DRWPC_WDATA;
  wire [ 3:0] DRWPC_WSTRB;
  wire        DRWPC_WLAST;
  wire        DRWVC_WREADY;

  wire        DRWPC_INT;
  wire        DRWPC_BUSY;
  wire        DRWVC_BUSY;

  wire        DRW_BUSY;
  assign DRW_BUSY = DRWPC_BUSY | DRWVC_BUSY;

  //-------------------------------------------------------------------------
  // AXI address wires from vramctrl (allow future target/offset manipulation)
  //-------------------------------------------------------------------------
  wire [C_M_AXI_ADDR_WIDTH-1:0] VRAMCTRL_ARADDR;
  wire [C_M_AXI_ADDR_WIDTH-1:0] VRAMCTRL_AWADDR;

  assign M_AXI_ARADDR = VRAMCTRL_ARADDR;
  assign M_AXI_AWADDR = VRAMCTRL_AWADDR;

  //-------------------------------------------------------------------------
  // Register control (CPU regbus + IRQ + DRAWCMD push)
  //-------------------------------------------------------------------------
  drw_regctrl u_drw_regctrl (
      .CLK (ACLK),
      .ARST(ARST),

      // reg-bus
      .WRADDR(WRADDR),
      .BYTEEN(BYTEEN),
      .WREN  (WREN),
      .WDATA (WDATA),
      .RDADDR(RDADDR),
      .RDEN  (RDEN),
      .RDATA (RDATA),

      // status/irq
      .INT    (DRWPC_INT),
      .BUSY   (DRW_BUSY),
      .DRW_IRQ(DRW_IRQ),

      // soft reset / start
      .DRWRG_RSTS (DRWRG_RSTS),
      .DRWRG_START(DRWRG_START),

      // command fifo write side
      .CMDFIFO_FULL (CMDFIFO_FULL),
      .CMDFIFO_COUNT(CMDFIFO_COUNT),
      .CMDFIFO_WREN (CMDFIFO_WREN),
      .CMDFIFO_WDATA(CMDFIFO_WDATA)
  );

  //-------------------------------------------------------------------------
  // Command FIFO (DRAWCMD buffer)
  //-------------------------------------------------------------------------
  drw_cmdfifo u_drw_cmdfifo (
      .CLK (ACLK),
      .ARST(ARST),
      .RSTS(DRWRG_RSTS),

      .WREN (CMDFIFO_WREN),
      .WDATA(CMDFIFO_WDATA),
      .FULL (CMDFIFO_FULL),

      .RDEN (CMDFIFO_RDEN),
      .RDATA(CMDFIFO_RDATA),
      .EMPTY(CMDFIFO_EMPTY),

      .COUNT(CMDFIFO_COUNT)
  );

  //-------------------------------------------------------------------------
  // Draw processor (command parse + param/state + address/pixel generation)
  //   - STEP-1 focuses on PATBLT / SETFRAME / SETDST / SETFCOLOR / EODL
  //-------------------------------------------------------------------------
  drw_proc u_drw_proc (
      .CLK  (ACLK),
      .ARST (ARST),
      .RSTS (DRWRG_RSTS),
      .START(DRWRG_START),
      .RESOL(RESOL_ff),

      // command stream
      .CMDFIFO_EMPTY(CMDFIFO_EMPTY),
      .CMDFIFO_RDATA(CMDFIFO_RDATA),
      .CMDFIFO_RDEN (CMDFIFO_RDEN),

      // source data (for BITBLT later)
      .DRWVC_SDATAVLD(DRWVC_SDATAVLD),
      .DRWVC_SDATA   (DRWVC_SDATA),

      // write stream (addr+data)
      .DRWVC_WREADY(DRWVC_WREADY),
      .WADDRVLD    (DRWPC_WADDRVLD),
      .WADDR       (DRWPC_WADDR),
      .WDATAVLD    (DRWPC_WDATAVLD),
      .WDATA       (DRWPC_WDATA),
      .WSTRB       (DRWPC_WSTRB),
      .WLAST       (DRWPC_WLAST),

      // status/interrupt
      .BUSY(DRWPC_BUSY),
      .INT (DRWPC_INT)
  );

  //-------------------------------------------------------------------------
  // VRAM controller (AXI master + internal FIFOs)
  //-------------------------------------------------------------------------
  drw_vramctrl u_drw_vramctrl (
      .CLK  (ACLK),
      .ARST (ARST),
      .RSTS (DRWRG_RSTS),
      .START(DRWRG_START),
      .RESOL(RESOL_ff),

      // write stream from proc
      .IN_WREADY(DRWVC_WREADY),
      .WADDRVLD (DRWPC_WADDRVLD),
      .WADDR    (DRWPC_WADDR),
      .WDATAVLD (DRWPC_WDATAVLD),
      .WDATA_IN (DRWPC_WDATA),
      .WSTRB_IN (DRWPC_WSTRB),
      .WLAST_IN (DRWPC_WLAST),

      // read stream to proc (for BITBLT later)
      .SDATAVLD(DRWVC_SDATAVLD),
      .SDATA   (DRWVC_SDATA),

      // status
      .BUSY(DRWVC_BUSY),

      // AXI (read)
      .ARADDR (VRAMCTRL_ARADDR),
      .ARLEN  (M_AXI_ARLEN),
      .ARVALID(M_AXI_ARVALID),
      .ARREADY(M_AXI_ARREADY),
      .RDATA  (M_AXI_RDATA),
      .RLAST  (M_AXI_RLAST),
      .RVALID (M_AXI_RVALID),
      .RREADY (M_AXI_RREADY),

      // AXI (write)
      .AWADDR (VRAMCTRL_AWADDR),
      .AWLEN  (M_AXI_AWLEN),
      .AWVALID(M_AXI_AWVALID),
      .AWREADY(M_AXI_AWREADY),
      .WDATA  (M_AXI_WDATA),
      .WSTRB  (M_AXI_WSTRB),
      .WLAST  (M_AXI_WLAST),
      .WVALID (M_AXI_WVALID),
      .WREADY (M_AXI_WREADY),
      .BRESP  (M_AXI_BRESP),
      .BVALID (M_AXI_BVALID),
      .BREADY (M_AXI_BREADY)
  );


endmodule
