//-----------------------------------------------------------------------------
// Title       : 描画回路 VRAM制御 (AXI Master)
// File        : drw_vramctrl.sv
//-----------------------------------------------------------------------------
module drw_vramctrl (
    input wire CLK,
    input wire ARST,

    // AXI4 Interface
    output reg  [31:0] M_AXI_ARADDR,
    output reg  [ 7:0] M_AXI_ARLEN,
    output reg         M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire        M_AXI_RLAST,
    input  wire        M_AXI_RVALID,
    output reg         M_AXI_RREADY,

    output reg  [31:0] M_AXI_AWADDR,
    output reg  [ 7:0] M_AXI_AWLEN,
    output reg         M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,
    output wire [31:0] M_AXI_WDATA,
    output wire [ 3:0] M_AXI_WSTRB,
    output reg         M_AXI_WLAST,
    output reg         M_AXI_WVALID,
    input  wire        M_AXI_WREADY,
    input  wire        M_AXI_BVALID,
    output wire        M_AXI_BREADY,

    // Main Control Interface
    input  wire        LINE_START,
    output reg         LINE_BUSY,
    input  wire [31:0] LINE_ADDR_DST,  // 背景・書込先
    input  wire [31:0] LINE_ADDR_SRC,  // テクスチャ
    input  wire [10:0] LINE_LEN,       // 画素数
    input  wire        CMD_MODE,       // 0:PATBLT, 1:BITBLT (追加推奨)
    input  wire        PARAM_BLEND,    // 1:Blend Enable

    // FIFO Interface
    input  wire        SRC_FIFO_FULL,
    output wire        SRC_FIFO_WR,
    output wire [31:0] SRC_FIFO_WDATA,

    input  wire        DST_FIFO_FULL,
    output wire        DST_FIFO_WR,
    output wire [31:0] DST_FIFO_WDATA,

    input  wire        WRT_FIFO_EMPTY,
    output wire        WRT_FIFO_RD,
    input  wire [31:0] WRT_FIFO_RDATA,
    input  wire [11:0] WRT_FIFO_COUNT
);

  //-------------------------------------------------------------------------
  // 定数・パラメータ
  //-------------------------------------------------------------------------
  localparam BURST_LEN = 32;  // バースト長
  localparam BURST_VAL = 8'd31;  // ARLEN設定値 (32-1)

  //-------------------------------------------------------------------------
  // 内部信号
  //-------------------------------------------------------------------------
  // 書き込み完了判定用
  reg [10:0] w_pixel_cnt;

  // Read系ステートマシン用
  reg [ 1:0] r_state;
  localparam R_IDLE = 2'd0, R_ADDR = 2'd1, R_DATA = 2'd2;

  reg [31:0] r_addr_current_src;
  reg [31:0] r_addr_current_dst;
  reg [10:0] r_pixel_cnt;
  reg        r_target;  // 0:SRC(Texture), 1:DST(Background)

  // Write系ステートマシン用
  reg [ 1:0] w_state;
  localparam W_IDLE = 2'd0, W_ADDR = 2'd1, W_DATA = 2'd2, W_RESP = 2'd3;

  reg [31:0] w_addr_current;
  reg [ 7:0] w_burst_cnt;

  //-------------------------------------------------------------------------
  // 全体制御 (BUSY)
  //-------------------------------------------------------------------------
  always @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      LINE_BUSY <= 1'b0;
    end else begin
      if (LINE_START) LINE_BUSY <= 1'b1;
      else if (LINE_BUSY && (w_pixel_cnt >= LINE_LEN)) LINE_BUSY <= 1'b0;
    end
  end

  //-------------------------------------------------------------------------
  // Read Channel Control (SRC & DST Interleaved)
  //-------------------------------------------------------------------------
  // 読み出しデータの振り分け
  // r_target が 0ならSRC FIFOへ、1ならDST FIFOへ
  assign SRC_FIFO_WR    = M_AXI_RVALID && M_AXI_RREADY && (r_target == 1'b0);
  assign SRC_FIFO_WDATA = M_AXI_RDATA;

  assign DST_FIFO_WR    = M_AXI_RVALID && M_AXI_RREADY && (r_target == 1'b1);
  assign DST_FIFO_WDATA = M_AXI_RDATA;

  // 読み出しが必要かどうか
  wire need_src_read = (CMD_MODE == 1'b1);  // BITBLTなら読む
  wire need_dst_read = (PARAM_BLEND == 1'b1);  // Blendなら読む

  always @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      r_state       <= R_IDLE;
      M_AXI_ARVALID <= 1'b0;
      M_AXI_RREADY  <= 1'b0;
      r_pixel_cnt   <= 11'd0;
      r_target      <= 1'b0;
    end else begin
      case (r_state)
        R_IDLE: begin
          if (LINE_START) begin
            r_pixel_cnt <= 0;
            r_addr_current_src <= LINE_ADDR_SRC;
            r_addr_current_dst <= LINE_ADDR_DST;
            r_target <= 1'b0;  // SRCから開始(仮)
          end

          M_AXI_ARVALID <= 1'b0;

          // 読み出し残量があり、FIFOに空きがあればリクエスト発行
          if (LINE_BUSY && (r_pixel_cnt < LINE_LEN)) begin
            // 優先順位: SRC -> DST の順で交互に、あるいは必要に応じて発行
            // 簡易ロジック:
            // 1. SRCが必要かつ、未読込ならSRC発行
            // 2. DSTが必要かつ、SRC読込済み(または不要)ならDST発行
            // ここでは「バースト単位」で切り替えるステート制御を行う必要があるが、
            // 簡略化のため「SRCが必要ならSRC発行」→「完了」→「DSTが必要ならDST発行」のようなシーケンスか、
            // FIFOの空き状況を見て動的に切り替える。

            // 今回はシンプルに:
            // 「SRC読み出しモード」かつ「SRC FIFO空きあり」 -> Go
            // 「DST読み出しモード」かつ「DST FIFO空きあり」 -> Go

            // 制御変数 r_target をトグルさせて制御する

            if (need_src_read && !SRC_FIFO_FULL && (r_target == 0)) begin
              M_AXI_ARADDR  <= r_addr_current_src;
              M_AXI_ARLEN   <= BURST_VAL;  // 端数処理省略(常に32)
              M_AXI_ARVALID <= 1'b1;
              r_state       <= R_ADDR;
            end
             else if (need_dst_read && !DST_FIFO_FULL && ((r_target == 1) || !need_src_read)) begin
              M_AXI_ARADDR  <= r_addr_current_dst;
              M_AXI_ARLEN   <= BURST_VAL;
              M_AXI_ARVALID <= 1'b1;
              r_state       <= R_ADDR;
              r_target      <= 1'b1;  // DST状態を明示
            end else begin
              // どちらも発行できない、または読み出し不要の場合
              // ターゲットを切り替えて次のチャンスを待つ
              if (need_src_read && need_dst_read) r_target <= ~r_target;
              else if (need_src_read) r_target <= 0;
              else r_target <= 1;

              // そもそも読み出し不要ならカウントを進めて終了扱いにする等の処理が必要
              // (PATBLTかつBlendOffならReadは一切走らない)
              if (!need_src_read && !need_dst_read) begin
                // Read完了とみなす(Write側だけで終わるのを待つ)
              end
            end
          end
        end

        R_ADDR: begin
          if (M_AXI_ARREADY) begin
            M_AXI_ARVALID <= 1'b0;
            M_AXI_RREADY  <= 1'b1;
            r_state       <= R_DATA;
          end
        end

        R_DATA: begin
          if (M_AXI_RVALID) begin
            if (M_AXI_RLAST) begin
              M_AXI_RREADY <= 1'b0;
              r_state      <= R_IDLE;

              // アドレス更新
              if (r_target == 0) begin  // SRC
                r_addr_current_src <= r_addr_current_src + (BURST_LEN * 4);
                // DST不要ならここで画素カウントアップ、DST必要ならDST読了後にアップなど
                // 同期をとるのが難しいので、Read側の画素カウントは「FIFOに投入した数」ではなく
                // 「発行したバースト数」で管理するか、Write側で全体終了を管理するのが無難。

                if (!need_dst_read) r_pixel_cnt <= r_pixel_cnt + BURST_LEN;
                r_target <= 1'b1;  // 次はDSTへ
              end else begin  // DST
                r_addr_current_dst <= r_addr_current_dst + (BURST_LEN * 4);
                r_pixel_cnt <= r_pixel_cnt + BURST_LEN;  // DSTまで読んで1単位完了
                r_target <= 1'b0;  // 次はSRCへ
              end
            end
          end
        end
      endcase
    end
  end

  //-------------------------------------------------------------------------
  // Write Channel Control (WRT FIFO -> VRAM)
  //-------------------------------------------------------------------------
  assign M_AXI_WSTRB = 4'b1111;
  assign M_AXI_BREADY = 1'b1;  // 応答は常に受け取る
  assign M_AXI_WDATA = WRT_FIFO_RDATA;

  // 先読み制御 (flt_vramctrlでの教訓を適用)
  // アドレス握手時 または データ転送中(最後以外) にReadEnable
  assign WRT_FIFO_RD = (w_state == W_ADDR && M_AXI_AWREADY) ||
                       (w_state == W_DATA && M_AXI_WREADY && (w_burst_cnt != M_AXI_AWLEN));

  always @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      w_state       <= W_IDLE;
      M_AXI_AWVALID <= 1'b0;
      M_AXI_WVALID  <= 1'b0;
      M_AXI_WLAST   <= 1'b0;
      w_pixel_cnt   <= 11'd0;
    end else begin
      case (w_state)
        W_IDLE: begin
          if (LINE_START) begin
            w_pixel_cnt    <= 0;
            w_addr_current <= LINE_ADDR_DST;
          end

          M_AXI_AWVALID <= 1'b0;

          // 書き込み残りがあり、FIFOに十分なデータがあれば発行
          if (LINE_BUSY && (w_pixel_cnt < LINE_LEN)) begin
            // 端数処理
            reg [10:0] rem;
            rem = LINE_LEN - w_pixel_cnt;

            // FIFOにバースト分溜まったか、またはこれが最後の半端バーストか
            if (WRT_FIFO_COUNT >= BURST_LEN || (rem <= BURST_LEN && WRT_FIFO_COUNT >= rem)) begin
              M_AXI_AWADDR  <= w_addr_current;
              M_AXI_AWVALID <= 1'b1;

              if (rem < BURST_LEN) M_AXI_AWLEN <= rem - 1;
              else M_AXI_AWLEN <= BURST_VAL;

              w_state <= W_ADDR;
            end
          end
        end

        W_ADDR: begin
          if (M_AXI_AWREADY) begin
            M_AXI_AWVALID <= 1'b0;
            w_state       <= W_DATA;
            M_AXI_WVALID  <= 1'b1;
            w_burst_cnt   <= 0;
            M_AXI_WLAST   <= (M_AXI_AWLEN == 0);
          end
        end

        W_DATA: begin
          if (M_AXI_WREADY) begin
            if (w_burst_cnt == M_AXI_AWLEN) begin
              // バースト終了
              M_AXI_WVALID   <= 1'b0;
              M_AXI_WLAST    <= 1'b0;
              w_state        <= W_RESP;

              w_addr_current <= w_addr_current + ((M_AXI_AWLEN + 1) * 4);
              w_pixel_cnt    <= w_pixel_cnt + (M_AXI_AWLEN + 1);
            end else begin
              w_burst_cnt <= w_burst_cnt + 1;
              if (w_burst_cnt == (M_AXI_AWLEN - 1)) M_AXI_WLAST <= 1'b1;
            end
          end
        end

        W_RESP: begin
          if (M_AXI_BVALID) begin
            w_state <= W_IDLE;
          end
        end
      endcase
    end
  end

endmodule
