// register controller for filter circuit
module flt_regctrl (
    input CLK,
    input ARST,

    /* レジスタバス */
    input        [15:0] WRADDR,
    input        [ 3:0] BYTEEN,
    input               WREN,
    input        [31:0] WDATA,
    input        [15:0] RDADDR,
    input               RDEN,
    output logic [31:0] RDATA,

    /* 割り込み */
    input        FLTVC_INT,   // 割り込み作成信号
    input        FLTVC_BUSY,
    output logic FLTRG_IRQ,

    output              FLTRG_RSTS,
    output logic        FLTRG_START,
    output logic [31:0] FLTRG_VRAMSRC,
    output logic [31:0] FLTRG_VRAMFRM,
    output logic [ 2:0] FLTRG_COLOR
);

  /*********************************/
  /***** Variable declarations *****/
  /*********************************/
  logic [3:0] reg_rsts;
  logic       flt_ien;

  logic       bWriteB0;
  logic       bWriteB1;
  logic       bWriteB2;
  logic       bWriteB3;
  logic       bSelectReg00;
  logic       bSelectReg04;
  logic       bSelectReg08;
  logic       bSelectReg0C;
  logic       bSelectReg10;
  logic       bSelectReg14;

  // output
  assign FLTRG_RSTS = (reg_rsts != 4'h0);

  // internal byte write
  logic write_reg;

  assign write_reg = WREN && WRADDR[15:12] == 4'h4;

  assign bWriteB0 = (write_reg & BYTEEN[0]);
  assign bWriteB1 = (write_reg & BYTEEN[1]);
  assign bWriteB2 = (write_reg & BYTEEN[2]);
  assign bWriteB3 = (write_reg & BYTEEN[3]);

  // address decode
  assign bSelectReg00 = (WRADDR[11:2] == 10'h000);
  assign bSelectReg04 = (WRADDR[11:2] == 10'h001);
  assign bSelectReg08 = (WRADDR[11:2] == 10'h002);
  assign bSelectReg0C = (WRADDR[11:2] == 10'h003);
  assign bSelectReg10 = (WRADDR[11:2] == 10'h004);
  assign bSelectReg14 = (WRADDR[11:2] == 10'h005);

  // ---------------------------------------------
  // FILTCTRL (0x4000)
  // ---------------------------------------------
  // FLTRG_START・・1クロックだけ1にする
  always_ff @(posedge CLK) begin
    if (ARST) FLTRG_START <= 1'b0;
    else if (FLTRG_START) FLTRG_START <= 1'b0;
    else FLTRG_START <= bWriteB0 && bSelectReg00 && WDATA[0];
  end

  // reg_rsts (4サイクルアサート)
  always_ff @(posedge CLK) begin
    if (ARST) reg_rsts <= 4'b0;
    else if (bWriteB0 && bSelectReg00) reg_rsts <= {3'b0, WDATA[1]};
    else reg_rsts <= {reg_rsts[2:0], 1'b0};
  end

  // ---------------------------------------------
  // FILTINT (0x4008)
  // ---------------------------------------------
  // 割り込みレジスタ（DRAWINT）・・INTENBL
  always_ff @(posedge CLK) begin
    if (ARST) flt_ien <= 1'b0;
    else if (bWriteB0 & bSelectReg08) flt_ien <= WDATA[0];
  end

  // 割り込み信号
  always_ff @(posedge CLK) begin
    if (ARST) FLTRG_IRQ <= 1'b0;
    else if (FLTVC_INT & flt_ien) FLTRG_IRQ <= 1'b1;
    else if (bWriteB0 & bSelectReg08 & WDATA[1]) FLTRG_IRQ <= 1'b0;
  end

  // ---------------------------------------------
  // FILTVRAM_SRC (0x400C)
  // ---------------------------------------------
  always_ff @(posedge CLK) begin
    if (ARST) FLTRG_VRAMSRC <= 32'h0;
    else begin
      if (bWriteB3 & bSelectReg0C) FLTRG_VRAMSRC[31:24] <= WDATA[31:24];
      if (bWriteB2 & bSelectReg0C) FLTRG_VRAMSRC[23:16] <= WDATA[23:16];
      if (bWriteB1 & bSelectReg0C) FLTRG_VRAMSRC[15:8] <= WDATA[15:8];
      if (bWriteB0 & bSelectReg0C) FLTRG_VRAMSRC[7:0] <= WDATA[7:0];
    end
  end

  // ---------------------------------------------
  // FILTVRAM_FRM (0x4010)
  // ---------------------------------------------
  always_ff @(posedge CLK) begin
    if (ARST) FLTRG_VRAMFRM <= 32'h0;
    else begin
      if (bWriteB3 & bSelectReg10) FLTRG_VRAMFRM[31:24] <= WDATA[31:24];
      if (bWriteB2 & bSelectReg10) FLTRG_VRAMFRM[23:16] <= WDATA[23:16];
      if (bWriteB1 & bSelectReg10) FLTRG_VRAMFRM[15:8] <= WDATA[15:8];
      if (bWriteB0 & bSelectReg10) FLTRG_VRAMFRM[7:0] <= WDATA[7:0];
    end
  end

  // ---------------------------------------------
  // FILTCOLOR (0x4014)
  // ---------------------------------------------
  always_ff @(posedge CLK) begin
    if (ARST) FLTRG_COLOR <= 3'b000;
    else begin
      if (bWriteB0 & bSelectReg14) FLTRG_COLOR <= WDATA[2:0];
    end
  end

  // ---------------------------------------------
  // register read mux
  // ---------------------------------------------
  always_comb
    case (RDADDR[11:2])
      10'h000: RDATA = 32'h0;
      10'h001: RDATA = {31'b0, FLTVC_BUSY};
      10'h002: RDATA = {31'h0, flt_ien};
      10'h003: RDATA = FLTRG_VRAMSRC[31:0];
      10'h004: RDATA = FLTRG_VRAMFRM[31:0];
      10'h005: RDATA = {29'b0, FLTRG_COLOR[2:0]};
      default: RDATA = 32'h0;
    endcase

endmodule  // flt_regctrl
