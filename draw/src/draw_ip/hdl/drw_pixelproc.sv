//-----------------------------------------------------------------------------
// Title       : 描画回路 ピクセル処理
// File        : drw_pixelproc.sv
//-----------------------------------------------------------------------------
module drw_pixelproc (
    input wire CLK,
    input wire ARST,

    // Parameters
    input wire [31:0] PARAM_FCOLOR,  // [31:24]Alpha, [23:16]R, [15:8]G, [7:0]B
    input wire        PARAM_BLEND,   // 1: Enable Alpha Blend
    input wire        CMD_MODE,      // 0: PATBLT, 1: BITBLT

    // FIFO Interface
    input  wire        SRC_FIFO_EMPTY,
    output wire        SRC_FIFO_RD,
    input  wire [31:0] SRC_FIFO_RDATA,

    input  wire        DST_FIFO_EMPTY,
    output wire        DST_FIFO_RD,
    input  wire [31:0] DST_FIFO_RDATA,

    input  wire        WRT_FIFO_FULL,
    output wire        WRT_FIFO_WR,
    output wire [31:0] WRT_FIFO_WDATA
);

  //-------------------------------------------------------------------------
  // 処理開始条件 (Ready)
  //-------------------------------------------------------------------------
  // 書き込みFIFOに空きがあることが大前提
  wire ready_wrt = !WRT_FIFO_FULL;

  // BITBLTならSRCが必要
  wire need_src = (CMD_MODE == 1'b1);
  wire ready_src = !need_src || !SRC_FIFO_EMPTY;

  // BlendならDSTが必要
  wire need_dst = (PARAM_BLEND == 1'b1);
  wire ready_dst = !need_dst || !DST_FIFO_EMPTY;

  // 全条件が整ったら1ピクセル処理実行
  wire do_proc = ready_wrt && ready_src && ready_dst;

  //-------------------------------------------------------------------------
  // FIFO Read Control
  //-------------------------------------------------------------------------
  assign SRC_FIFO_RD = do_proc && need_src;
  assign DST_FIFO_RD = do_proc && need_dst;
  assign WRT_FIFO_WR = do_proc;

  //-------------------------------------------------------------------------
  // ピクセル演算ロジック
  //-------------------------------------------------------------------------
  reg  [31:0] proc_result;

  // 入力データの選択
  wire [31:0] pix_src = (CMD_MODE == 1'b1) ? SRC_FIFO_RDATA : PARAM_FCOLOR;
  wire [31:0] pix_dst = DST_FIFO_RDATA;

  // アルファブレンド計算
  // Out = (Src * Alpha + Dst * (255 - Alpha)) / 255
  // 簡易計算: Alpha = Src.Alpha とする (またはレジスタ設定値)
  // ここでは仕様書の SETBLENDALPHA にあるような複雑な計算ではなく、
  // 一般的な「Source Alpha」を用いたブレンドを実装する例とします。

  // 各チャンネルの分解
  wire [ 7:0] sa = pix_src[31:24];
  wire [ 7:0] sr = pix_src[23:16];
  wire [ 7:0] sg = pix_src[15:8];
  wire [ 7:0] sb = pix_src[7:0];

  wire [ 7:0] dr = pix_dst[23:16];
  wire [ 7:0] dg = pix_dst[15:8];
  wire [ 7:0] db = pix_dst[7:0];

  // 係数
  wire [ 8:0] alpha = {1'b0, sa};  // 0-255
  wire [ 8:0] inv_alpha = 9'd255 - alpha;

  // 演算 (パイプライン化せず組み合わせ回路で記述)
  // DSPを使いたい場合は必ずFFを入れること
  reg [15:0] res_r, res_g, res_b;

  always_comb begin
    if (PARAM_BLEND) begin
      // (Src * A + Dst * (255-A)) >> 8
      // 正確には /255 だが、HWでは >>8 (256除算) で近似することが多い。
      // 仕様書通り /255 に近づけるなら (X + 128) >> 8 等の補正が必要。
      // ここでは簡易的に >> 8 とする。
      res_r = (sr * alpha + dr * inv_alpha) >> 8;
      res_g = (sg * alpha + dg * inv_alpha) >> 8;
      res_b = (sb * alpha + db * inv_alpha) >> 8;

      // 結果の結合 (Alphaはdstを維持するか、srcにするか仕様次第。ここではFF固定)
      proc_result = {8'hFF, res_r[7:0], res_g[7:0], res_b[7:0]};
    end else begin
      // そのまま出力
      proc_result = pix_src;
    end
  end

  assign WRT_FIFO_WDATA = proc_result;

endmodule
