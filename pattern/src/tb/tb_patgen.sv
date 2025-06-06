`timescale 1ns / 1ps

module tb_patgen;
  //-----------------------------------------------------------------------------
  //    Internal Signals
  //-----------------------------------------------------------------------------
  logic DCLK;
  logic RST;
  logic BTNR_TGL;  //resolution signal xga=1, vga=0
  logic XGA;  //resolution signal synchronized to VSYNC_X
  logic DSP_HSYNC_X;
  logic DSP_VSYNC_X;
  logic DSP_DE;
  logic [7:0] DSP_R;
  logic [7:0] DSP_G;
  logic [7:0] DSP_B;

  //-----------------------------------------------------------------------------
  //    Parameter Definition
  //-----------------------------------------------------------------------------

  localparam real STEP25M = 40.0;
  localparam real STEP65M = 15.4;

  localparam string FILENAME1 = "vga_imagedata.txt";
  localparam string FILENAME2 = "xga_imagedata.txt";
  integer fd1, vflag1;
  integer fd2, vflag2;
  integer CLOCKNUM;
  real STEP;

  //-----------------------------------------------------------------------------
  //    Module Call
  //-----------------------------------------------------------------------------
  patgen i_patgen (
      .DCLK       (DCLK),
      .RST        (RST),
      .BTNR_TGL   (BTNR_TGL),
      .XGA        (XGA),
      .DSP_HSYNC_X(DSP_HSYNC_X),
      .DSP_VSYNC_X(DSP_VSYNC_X),
      .DSP_DE     (DSP_DE),
      .DSP_R      (DSP_R),
      .DSP_G      (DSP_G),
      .DSP_B      (DSP_B)
  );

  always_comb begin
    if (XGA) begin
      STEP = STEP65M;
      CLOCKNUM = 1344 * 806;
    end else begin
      STEP = STEP25M;
      CLOCKNUM = 800 * 525;
    end
  end

  always begin
    DCLK = 0;
    #(STEP / 2);
    DCLK = 1;
    #(STEP / 2);
  end

  initial begin
    fd1 = $fopen(FILENAME1);
    fd2 = $fopen(FILENAME2);
    vflag1 = 0;
    vflag2 = 0;
    RST = 0;
    BTNR_TGL = 0;  //vga:0, xga:1
    #STEP RST = 1;
    #(STEP * 4) RST = 0;
    #(STEP * CLOCKNUM * 2.4);
    BTNR_TGL = 1;  //vga:0, xga:1
    while (XGA == 0) begin
      #STEP;
    end
    #STEP;
    #(STEP * CLOCKNUM * 2.4);
    #STEP RST = 1;
    #(STEP * 4) RST = 0;
    #(STEP * 8);
    $fclose(fd1);
    $fclose(fd2);
    $stop;
    $finish;
  end

  //vga data output
  always @(posedge DCLK) begin
    if (DSP_DE && ~XGA) begin
      $fdisplay(fd1, "%06x", {DSP_R, DSP_G, DSP_B});
      vflag1 = 1;
    end else if (DSP_VSYNC_X == 0 && vflag1 == 1) begin
      $fdisplay(fd1, "vsync");
      vflag1 = 0;
    end
  end

  //xga data output
  always @(posedge DCLK) begin
    if (DSP_DE && XGA) begin
      $fdisplay(fd2, "%06x", {DSP_R, DSP_G, DSP_B});
      vflag2 = 1;
    end else if (DSP_VSYNC_X == 0 && vflag2 == 1) begin
      $fdisplay(fd2, "vsync");
      vflag2 = 0;
    end
  end

endmodule
