module flt_proc (
    input CLK,
    input ARST,  // システムリセット
    input RSTS,  // コマンドによるリセット

    input [2:0] FLTRG_COLOR,

    input        FLTVC_SDATAVLD,
    input [31:0] FLTVC_SDATA,

    output logic        FLTPC_WDATAVLD,
    output logic [31:0] FLTPC_WDATA
);

  //++++++++++++++++++++++++++++++
  // ユーザ記述
  //++++++++++++++++++++++++++++++






endmodule  // flt_proc
