// patgen wrapper for Ultra96-V2
module patgen_wrap (
    input             DCLK,
    input             ARESETN,
    input      [ 1:0] RESOL,
    output reg        DP_HSYNC,
    output reg        DP_VSYNC,
    output reg        DP_DE,
    output reg [35:0] DP_DAT
);

  wire       DSP_HSYNC_X;
  wire       DSP_VSYNC_X;
  wire       DSP_DE;
  wire [7:0] DSP_R;
  wire [7:0] DSP_G;
  wire [7:0] DSP_B;

  patgen patgen (
      .DCLK       (DCLK),
      .RST        (~ARESETN),
      .BTNR_TGL   (RESOL[0]),
      .XGA        (),
      .DSP_HSYNC_X(DSP_HSYNC_X),
      .DSP_VSYNC_X(DSP_VSYNC_X),
      .DSP_DE     (DSP_DE),
      .DSP_R      (DSP_R[7:0]),
      .DSP_G      (DSP_G[7:0]),
      .DSP_B      (DSP_B[7:0])
  );


  always @(posedge DCLK) begin
    DP_HSYNC     <= ~DSP_HSYNC_X;
    DP_VSYNC     <= ~DSP_VSYNC_X;
    DP_DE        <= DSP_DE;
    DP_DAT[35:0] <= {DSP_B[7:0], 4'h0, DSP_R[7:0], 4'h0, DSP_G[7:0], 4'h0};
  end

endmodule
