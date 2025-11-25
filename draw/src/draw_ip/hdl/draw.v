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

endmodule
