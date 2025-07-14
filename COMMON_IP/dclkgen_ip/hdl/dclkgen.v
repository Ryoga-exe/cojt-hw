/// Generate DCLK
module dclkgen (
    input        CLK40,
    input        ARESETN,
    input  [1:0] RESOL,
    output       DCLK
    //  output          DVI_CLK
);

  // Generation of the reset signal CRST synchronized with CLK40
  reg [1:0] crst_ff;

  always @(posedge CLK40) begin
    crst_ff <= {crst_ff[0], ~ARESETN};
  end

  wire CRST = crst_ff[1];

  // Capture RESOL with a 3-stage flip-flop synchronizer
  reg [1:0] resol_ff0, resol_ff1, resol_ff2;

  always @(posedge CLK40) begin
    if (CRST) begin
      resol_ff0 <= 2'b00;
      resol_ff1 <= 2'b00;
      resol_ff2 <= 2'b00;
    end else begin
      resol_ff2 <= resol_ff1;
      resol_ff1 <= resol_ff0;
      resol_ff0 <= RESOL;
    end
  end

  // Detect any change on RESOL
  wire change = (resol_ff2[0] ^ resol_ff1[0]) | (resol_ff2[1] ^ resol_ff1[1]);

  // Start-pulse generation -- create the pulse by delaying the detected change by eight clock cycles
  reg [7:0] start;

  always @(posedge CLK40) begin
    if (CRST) start <= 8'h00;
    else start <= {start[6:0], change};
  end

  // Connect to the MMCM dynamic-reconfiguration circuitry
  top_mmcme2 top_mmcme2 (
      .SSTEP  (start[7]),
      .STATE  (resol_ff1),  // Provide RESOL already synchronized to CLK40
      .RST    (CRST),
      .CLKIN  (CLK40),
      .SRDY   (),
      .LOCKED (),
      .CLK0OUT(DCLK),
      //    .CLK1OUT  (DVI_CLK)
      .CLK1OUT()
  );

endmodule
