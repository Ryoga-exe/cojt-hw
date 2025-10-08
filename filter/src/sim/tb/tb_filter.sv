// filter のテストベンチ
`timescale 1ns / 1ps

`define VIPINST dut.design_1_i.axi_vip_0.inst


import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module tb_filter;

  /* 各種定数 */
  localparam integer STEP = 8;
  localparam integer DSTEP = 40;

  localparam P_RESOL_VGA = 2'b00;
  localparam P_RESOL_XGA = 2'b01;
  localparam P_RESOL_SXGA = 2'b10;

  /* シミュレーションする解像度の設定 */
  localparam SIM_RESOL = P_RESOL_VGA;

  /* 解像度に応じて総画素数や画像ファイルを切り替える */
  localparam PIX_NUMBER   = (SIM_RESOL == P_RESOL_VGA) ? 640*480  :
                          (SIM_RESOL == P_RESOL_XGA) ? 1024*768 :
                                                       1280*1024;

  localparam PIC_FILENAME = (SIM_RESOL == P_RESOL_VGA) ? "wcup2002_VGA.raw" :
                          (SIM_RESOL == P_RESOL_XGA) ? "wcup2002_XGA.raw" :
                                                       "wcup2002_SXGA.raw";

  /* 描画回路信号 */
  logic        ACLK;
  logic        ARESETN;
  logic        FLT_IRQ;
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
  localparam FLTCTRL = 16'h4000;
  localparam FLTSTAT = 16'h4004;
  localparam FLTINT = 16'h4008;
  localparam FLTVRAM_SRC = 16'h400c;
  localparam FLTVRAM_FRM = 16'h4010;
  localparam FLTCOLOR = 16'h4014;

  /* VRAMのアドレス */
  localparam MEMBASE_SRC = 32'h2000_0000;
  localparam MEMBASE_FRM = MEMBASE_SRC + PIX_NUMBER * 4;

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

  /* VRAMのクリア */
  task memclear();
    integer i;
    begin
      for (i = 0; i < PIX_NUMBER * 2; i = i + 1) begin
        agent.mem_model.backdoor_memory_write_4byte(MEMBASE_SRC + i * 4, 32'h00000000, 4'hf);
      end
    end
  endtask

  /* 画像ファイル読み込み */
  task meminit_pic();
    reg [7:0] r, g, b;
    integer fd, i;
    begin
      fd = $fopen(PIC_FILENAME, "rb");
      for (i = 0; i < PIX_NUMBER; i = i + 1) begin
        r = $fgetc(fd);
        g = $fgetc(fd);
        b = $fgetc(fd);
        agent.mem_model.backdoor_memory_write_4byte(MEMBASE_SRC + i * 4, {8'h00, r, g, b}, 4'hf);
      end
      $fclose(fd);
    end
  endtask

  /* VIP Slave用のエージェントを宣言しスレーブを起動 */
  design_1_axi_vip_0_0_slv_mem_t agent;

  task init_system();
    agent = new("AXI Slave Agent", `VIPINST.IF);
    agent.start_slave();
    memclear();
    meminit_pic();
  endtask

  /* シミュレーン結果画像を文字ファイルで出力 */
  task fileout(input kind);
    reg [31:0] pic;
    integer fd, i;
    begin
      if (kind) fd = $fopen("imagedata.txt", "w");
      else fd = $fopen("imagedata.txt", "a");

      for (i = 0; i < PIX_NUMBER; i = i + 1) begin
        pic = agent.mem_model.backdoor_memory_read_4byte(MEMBASE_FRM + i * 4);
        $fdisplay(fd, "%06x", pic[23:0]);
      end
      $fdisplay(fd, "vsync");
      $fclose(fd);
    end
  endtask

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

    write_reg(FLTINT, 4'hf, 32'h00000001);
    write_reg(FLTVRAM_SRC, 4'hf, MEMBASE_SRC);
    write_reg(FLTVRAM_FRM, 4'hf, MEMBASE_FRM);

    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Frame#0 None-filter
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    write_reg(FLTCOLOR, 4'hf, 32'h00000007);

    // フィルタ処理開始
    write_reg(FLTCTRL, 4'hf, 32'h00000001);
    #(STEP * 100);

    // フィルタ処理終了待ち
    read_reg(FLTSTAT, status);
    while (status[0] != 1'b0) read_reg(FLTSTAT, status);

    #(STEP * 100);
    write_reg(FLTINT, 4'hf, 32'h00000003);
    fileout(1);

    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Frame#1 Blue-filter
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    write_reg(FLTCOLOR, 4'hf, 32'h00000001);

    // フィルタ処理開始
    write_reg(FLTCTRL, 4'hf, 32'h00000001);
    #(STEP * 100);

    // フィルタ処理終了待ち
    read_reg(FLTSTAT, status);
    while (status[0] != 1'b0) read_reg(FLTSTAT, status);

    #(STEP * 100);
    write_reg(FLTINT, 4'hf, 32'h00000003);
    fileout(0);

    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Frame#2 Green-filter
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    write_reg(FLTCOLOR, 4'hf, 32'h00000002);

    // フィルタ処理開始
    write_reg(FLTCTRL, 4'hf, 32'h00000001);
    #(STEP * 100);

    // フィルタ処理終了待ち
    read_reg(FLTSTAT, status);
    while (status[0] != 1'b0) read_reg(FLTSTAT, status);

    #(STEP * 100);
    write_reg(FLTINT, 4'hf, 32'h00000003);
    fileout(0);

    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Frame#3 Red-filter
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    write_reg(FLTCOLOR, 4'hf, 32'h00000004);

    // フィルタ処理開始
    write_reg(FLTCTRL, 4'hf, 32'h00000001);
    #(STEP * 100);

    // フィルタ処理終了待ち
    read_reg(FLTSTAT, status);
    while (status[0] != 1'b0) read_reg(FLTSTAT, status);

    #(STEP * 100);
    write_reg(FLTINT, 4'hf, 32'h00000003);
    fileout(0);

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
