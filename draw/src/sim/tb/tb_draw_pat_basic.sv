// draw のテストベンチ (基本機能の確認)
`timescale 1ns / 1ps

`define VIPINST dut.design_1_i.axi_vip_0.inst

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module tb_draw_pat_basic;

  /* 各種定数 */
  localparam integer STEP = 8;
  localparam integer DSTEP = 40;

  localparam P_RESOL_VGA = 2'b00;
  localparam P_RESOL_XGA = 2'b01;
  localparam P_RESOL_SXGA = 2'b10;

  /* シミュレーションする解像度の設定 */
  localparam SIM_RESOL = P_RESOL_VGA;

  /* 解像度に応じて総画素数や画像ファイルを切り替える */
  localparam PIX_NUMBER   = (SIM_RESOL == P_RESOL_VGA) ? 640*480: (SIM_RESOL == P_RESOL_XGA) ? 1024*768: 1280*1024;
  localparam PIC_FILENAME = (SIM_RESOL == P_RESOL_VGA) ? "wcup2002_VGA.raw":
                          (SIM_RESOL == P_RESOL_XGA) ? "wcup2002_XGA.raw": "wcup2002_SXGA.raw";

  /* 描画回路信号 */
  logic        ACLK;
  logic        ARESETN;
  logic        DRW_IRQ;
  logic [ 1:0] RESOL;

  /* レジスタバス */
  reg   [15:0] WRADDR;
  reg   [ 3:0] BYTEEN;
  reg          WREN;
  reg   [31:0] WDATA;
  reg   [15:0] RDADDR;
  reg          RDEN;
  wire  [31:0] RDATA;

  reg   [31:0] status;

  /* DUTの接続 */
  design_1_wrapper dut (.*);

  /* クロック */
  always begin
    ACLK = 0;
    #(STEP / 2);
    ACLK = 1;
    #(STEP / 2);
  end

  /* レジスタアドレス */
  localparam DRAWCTRL = 16'h2000;
  localparam DRAWSTAT = 16'h2004;
  localparam DRAWBUFSTAT = 16'h2008;
  localparam DRAWCMD = 16'h200c;
  localparam DRAWINT = 16'h2010;

  /* レジスタ書き込み */
  task write_reg(input [15:0] addr, input [3:0] byteen, input [31:0] wdata);
    begin
      WRADDR = addr;
      BYTEEN = byteen;
      WDATA  = wdata;
      @(negedge ACLK);
      WREN = 1;
      @(negedge ACLK);
      WREN = 0;
    end
  endtask

  /* レジスタ読み出し（2クロック）*/
  task read_reg;
    input [15:0] addr;
    output [31:0] rdata;
    begin
      RDADDR = addr;
      @(negedge ACLK);
      RDEN = 1;
      @(negedge ACLK);
      @(negedge ACLK);
      rdata = RDATA;
      RDEN  = 0;
      @(negedge ACLK);
    end
  endtask

  /* コマンドレジスタへ書き込み */
  task command;
    input [31:0] cmddata;
    begin
      write_reg(DRAWCMD, 4'hf, cmddata);
    end
  endtask

  /* VRAMのクリア */
  task memclear();
    integer i;
    begin
      for (i = 0; i < PIX_NUMBER; i = i + 1) begin
        agent.mem_model.backdoor_memory_write_4byte(MEMBASE + i * 4, 32'h00000000, 4'hf);
      end
    end
  endtask

  /* VIP Slave用のエージェントを宣言しスレーブを起動 */
  design_1_axi_vip_0_0_slv_mem_t agent;

  task init_system();
    agent = new("AXI Slave Agent", `VIPINST.IF);
    agent.start_slave();
    memclear();
  endtask

  /* VRAMのアドレス */
  localparam MEMBASE = 32'h2000_0000;

  /* シミュレーン結果画像を文字ファイルで出力 */
  task fileout();
    reg [31:0] pic;
    integer fd, i;
    begin
      fd = $fopen("imagedata.txt");
      for (i = 0; i < PIX_NUMBER; i = i + 1) begin
        pic = agent.mem_model.backdoor_memory_read_4byte(MEMBASE + i * 4);
        $fdisplay(fd, "%06x", pic[23:0]);
      end
      $fdisplay(fd, "vsync");
      $fclose(fd);
    end
  endtask

  /* この宣言をex1〜ex4まで書き換えて検証する */
  `define ex1
  //`define ex2
  //`define ex3
  //`define ex4

  initial begin
    RESOL = SIM_RESOL;
    ARESETN = 1;
    WRADDR = 0;
    BYTEEN = 0;
    WREN = 0;
    WDATA = 0;
    RDEN = 0;
    RDADDR = 0;

    #STEP;
    ARESETN = 0;
    #(STEP * 100);
    ARESETN = 1;
    #(STEP * 100);

    init_system();
    user_gen_arready();
    user_gen_awready();
    user_gen_wready();

`ifdef ex1  // 描画例1
    /**************************************************************************/
    // SETFRAME
    command(32'h20000000);
    command(32'h20000000);  // VRAMADR = 0x20000000
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETDRAWAREA
    command(32'h21000000);
    command(32'h00000000);  // POSX=0, POSY=0
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETFCOLOR
    command(32'h23000000);
    command(32'h00FF0000);  // RED

    // PATBLT
    command(32'h81000000);
    command(32'h00000000);  // POSX, POSY
    command(640 << 16 | 480);  // DSIZEX, DSIZEY

    // EODL
    command(32'h0F000000);
    /**************************************************************************/
`endif
    `undef ex1


`ifdef ex2  // 描画例2
    /**************************************************************************/
    // SETFRAME
    command(32'h20000000);
    command(32'h20000000);  // VRAMADR = 0x20000000
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETDRAWAREA
    command(32'h21000000);
    command(32'h00000000);  // POSX=0, POSY=0
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETFCOLOR
    command(32'h23000000);
    command(32'h0000FF00);  // GREEN

    // PATBLT
    command(32'h81000000);
    command(160 << 16 | 120);  // POSX, POSY
    command(320 << 16 | 240);  // DSIZEX, DSIZEY

    // EODL
    command(32'h0F000000);
    /**************************************************************************/
`endif
    `undef ex2


`ifdef ex3  // 描画例3
    /**************************************************************************/
    // SETFRAME
    command(32'h20000000);
    command(32'h20000000);  // VRAMADR = 0x20000000
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETDRAWAREA
    command(32'h21000000);
    command(160 << 16 | 120);  // POSX, POSY
    command(320 << 16 | 240);  // WIDTH=320, HEIGHT=240

    // SETFCOLOR
    command(32'h23000000);
    command(32'h000000FF);  // BLUE

    // PATBLT
    command(32'h81000000);
    command(0 << 16 | 0);  // POSX, POSY
    command(640 << 16 | 480);  // DSIZEX, DSIZEY

    // EODL
    command(32'h0F000000);
    /**************************************************************************/
`endif
    `undef ex3


`ifdef ex4  // 描画例4
    /**************************************************************************/
    // SETFRAME
    command(32'h20000000);
    command(32'h20000000);  // VRAMADR = 0x20000000
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETDRAWAREA
    command(32'h21000000);
    command(32'h00000000);  // POSX=0, POSY=0
    command(640 << 16 | 480);  // WIDTH=640, HEIGHT=480

    // SETFCOLOR
    command(32'h23000000);
    command(32'h00FFFF00);  // YELLOW

    // PATBLT
    command(32'h81000000);
    command(480 << 16 | 360);  // POSX, POSY
    command(320 << 16 | 240);  // DSIZEX, DSIZEY

    // EODL
    command(32'h0F000000);
    /**************************************************************************/
`endif
    `undef ex4


    // 描画開始
    write_reg(DRAWCTRL, 4'hf, 32'h00000001);
    #(STEP * 100);

    // 描画終了待ち
    read_reg(DRAWSTAT, status);
    while (status[0] != 1'b0) read_reg(DRAWSTAT, status);

    #(STEP * 100);
    fileout();
    $stop;
  end

  /* ARREADYの挙動をランダム化 */
  task user_gen_arready();
    axi_ready_gen arready_gen;
    arready_gen = agent.wr_driver.create_ready("arready");
    arready_gen.set_ready_policy(XIL_AXI_READY_GEN_RANDOM);
    agent.rd_driver.send_arready(arready_gen);
  endtask

  /* AWREADYの挙動をランダム化 */
  task user_gen_awready();
    axi_ready_gen awready_gen;
    awready_gen = agent.wr_driver.create_ready("awready");
    awready_gen.set_ready_policy(XIL_AXI_READY_GEN_RANDOM);
    agent.wr_driver.send_awready(awready_gen);
  endtask

  /* WREADYの挙動をランダム化 */
  task user_gen_wready();
    axi_ready_gen wready_gen;
    wready_gen = agent.wr_driver.create_ready("wready");
    wready_gen.set_ready_policy(XIL_AXI_READY_GEN_RANDOM);
    agent.wr_driver.send_wready(wready_gen);
  endtask

endmodule
