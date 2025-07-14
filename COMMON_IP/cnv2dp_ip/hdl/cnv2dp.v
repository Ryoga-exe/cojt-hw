/// Convert to DisplayPort
module cnv2dp (
    input             DCLK,
    input             DSP_HSYNC_X,
    input             DSP_VSYNC_X,
    input             DSP_DE,
    input      [ 7:0] DSP_R,
    input      [ 7:0] DSP_G,
    input      [ 7:0] DSP_B,
    output reg        DP_HSYNC,
    output reg        DP_VSYNC,
    output reg        DP_DE,
    output reg [35:0] DP_DAT
);

  always @(posedge DCLK) begin
    DP_HSYNC     <= ~DSP_HSYNC_X;
    DP_VSYNC     <= ~DSP_VSYNC_X;
    DP_DE        <= DSP_DE;
    DP_DAT[35:0] <= {DSP_B[7:0], 4'h0, DSP_R[7:0], 4'h0, DSP_G[7:0], 4'h0};
  end

endmodule
