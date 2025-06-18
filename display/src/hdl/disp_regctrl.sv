module disp_regctrl (
    // System Signals
    input logic ACLK,
    input logic ARST,

    // VSYNC
    input logic DSP_VSYNC_X,

    // Register bus
    input  logic [15:0] WRADDR,
    input  logic [ 3:0] BYTEEN,
    input  logic        WREN,
    input  logic [31:0] WDATA,
    input  logic [15:0] RDADDR,
    input  logic        RDEN,
    output logic [31:0] RDATA,

    // Register output
    output logic        DISPON,
    output logic [31:0] DISPADDR,

    // Interrupt, FIFO flag
    output logic DSP_IRQ,
    input  logic BUF_UNDER,
    input  logic BUF_OVER
);
  assign DSP_IRQ = 1'b0;

  wire write_reg = WREN && WRADDR[15:12] == 4'h0;
  wire ctrlreg_wr = (write_reg && WRADDR[11:2] == 10'h001 && BYTEEN[0]);

  // DISPADDR
  always @(posedge ACLK) begin
    if (ARST) DISPADDR <= 32'h0;
    else if (write_reg) begin
      if (WRADDR[11:2] == 10'h000) begin
        if (BYTEEN[0]) DISPADDR[7:0] <= WDATA[7:0];
        if (BYTEEN[1]) DISPADDR[15:8] <= WDATA[15:8];
        if (BYTEEN[2]) DISPADDR[23:16] <= WDATA[23:16];
        if (BYTEEN[3]) DISPADDR[31:24] <= WDATA[31:24];
      end
    end
  end

  // DISPCTRL (DISPON)
  always @(posedge ACLK) begin
    if (ARST) DISPON <= 1'b0;
    else if (ctrlreg_wr) DISPON <= WDATA[0];
  end

  // Read register
  // FIXME: correct RDATA
  always_comb begin
    case (RDADDR[11:2])
      10'h000: RDATA = DISPADDR[31:0];
      10'h001: RDATA = 32'h0;  // DISPCTRLレジスタのリード値を記述
      10'h002: RDATA = 32'h0;  // DISPINTレジスタのリード値を記述
      10'h003: RDATA = 32'h0;  // DISPFIFOレジスタのリード値を記述
      default: RDATA = 32'h0;  //
    endcase
  end
endmodule
