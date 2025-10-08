// VRAM controller for filter circuit
module flt_vramctrl (
    input CLK,
    input ARST,
    input RSTS,  // 同期リセット

    /* 解像度切り替え */
    input [1:0] RESOL,

    // Read Address
    output logic [31:0] ARADDR,
    output              ARVALID,
    output logic [ 7:0] ARLEN,
    input               ARREADY,
    // Read Data
    input        [31:0] RDATA,
    input               RLAST,
    input               RVALID,
    output              RREADY,
    // Write Address
    output logic [31:0] AWADDR,
    output              AWVALID,
    output logic [ 7:0] AWLEN,
    input               AWREADY,
    // Write Data
    output       [31:0] WDATA,
    output              WLAST,
    output              WVALID,
    output       [ 3:0] WSTRB,
    input               WREADY,
    // Response
    input               BVALID,
    output              BREADY,

    input        FLTRG_START,
    input [31:0] FLTRG_VRAMSRC,
    input [31:0] FLTRG_VRAMFRM,

    input        FLTPC_WDATAVLD,
    input [31:0] FLTPC_WDATA,

    output        FLTVC_SDATAVLD,
    output [31:0] FLTVC_SDATA,

    output FLTVC_BUSY,
    output FLTVC_INT
);

  //++++++++++++++++++++++++++++++
  // ユーザ記述
  //++++++++++++++++++++++++++++++

















  /****************************************************************************************/
  // ソースデータFIFO
  /****************************************************************************************/

  fifo_32in32out_2048depth u_fifo_src (
      .clk       (),
      .din       (),
      .rd_en     (),
      .rst       (),
      .wr_en     (),
      .dout      (),
      .empty     (),
      .full      (),
      .overflow  (),
      .valid     (),
      .underflow (),
      .data_count()
  );

  /****************************************************************************************/
  // ライトデータFIFO
  /****************************************************************************************/

  fifo_32in32out_2048depth u_fifo_wrt (
      .clk       (),
      .din       (),
      .rd_en     (),
      .rst       (),
      .wr_en     (),
      .dout      (),
      .empty     (),
      .full      (),
      .overflow  (),
      .valid     (),
      .underflow (),
      .data_count()
  );

endmodule  // flt_vramctrl
