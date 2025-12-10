//-----------------------------------------------------------------------------
// Title       : 描画回路 メイン制御 (コマンド解析・アドレス生成)
// File        : drw_mainctrl.sv
//-----------------------------------------------------------------------------
module drw_mainctrl (
    input wire CLK,
    input wire ARST,
    input wire SOFT_RST,

    // Control Signals
    input  wire DRW_START,
    output reg  DRW_BUSY,
    output reg  DRW_IRQ,

    // Command FIFO Interface
    input  wire        CMD_FIFO_EMPTY,
    output reg         CMD_FIFO_RD,
    input  wire [31:0] CMD_FIFO_RDATA,

    // VRAM Control Interface (Line Kick)
    output reg         LINE_START,
    input  wire        LINE_BUSY,
    output reg  [31:0] LINE_ADDR_DST,  // 背景/書込先アドレス
    output reg  [31:0] LINE_ADDR_SRC,  // テクスチャアドレス
    output reg  [10:0] LINE_LEN,       // 転送長 (pixels)
    output reg         CMD_MODE,       // 0:PATBLT, 1:BITBLT

    // Parameters to Pixel Proc
    output reg [31:0] PARAM_FCOLOR,
    output reg        PARAM_BLEND
);

  //-------------------------------------------------------------------------
  // ステートマシン定義
  //-------------------------------------------------------------------------
  localparam S_IDLE = 4'd0;
  localparam S_FETCH = 4'd1;  // コマンド読み出し
  localparam S_DECODE = 4'd2;  // コマンド解析
  localparam S_PARAM_WAIT = 4'd3;  // パラメータ読み出し待ち
  localparam S_EXEC_SETUP = 4'd4;  // 描画ループ初期化
  localparam S_EXEC_LINE = 4'd5;  // 1ライン描画キック
  localparam S_EXEC_WAIT = 4'd6;  // 1ライン完了待ち
  localparam S_EXEC_NEXT = 4'd7;  // 次ライン判定
  localparam S_FINISH = 4'd8;

  reg [ 3:0] state;
  reg [ 3:0] next_state;  // 必要なら使うが、今回はalways内で遷移記述

  //-------------------------------------------------------------------------
  // 内部レジスタ (パラメータ保持用)
  //-------------------------------------------------------------------------
  // SETFRAME
  reg [31:0] reg_frame_addr;
  reg [10:0] reg_frame_w, reg_frame_h;
  // SETDRAWAREA
  reg [10:0] reg_area_x, reg_area_y, reg_area_w, reg_area_h;
  // SETTEXTURE
  reg [31:0] reg_tex_addr;
  reg reg_tex_fmt;  // 0:ARGB, 1:RGB
  // SETFCOLOR
  reg [31:0] reg_fcolor;
  // SETBLEND
  reg reg_blend_en;  // 0:OFF, 1:ALPHA
  // ... 他、ブレンド係数などは省略

  // コマンド解析用
  reg [7:0] cmd_code;
  reg [3:0] param_count;  // 残りパラメータ数
  reg [31:0] cmd_params[0:3];  // パラメータ一時保存 (最大4つと仮定)

  // 描画実行用ワークレジスタ
  reg [11:0] work_dpos_x, work_dpos_y;  // 符号付き座標
  reg [10:0] work_dsiz_x, work_dsiz_y;
  reg [11:0] work_spos_x, work_spos_y;

  reg [10:0] loop_y_cnt;  // Y方向ループカウンタ

  //-------------------------------------------------------------------------
  // メインステートマシン
  //-------------------------------------------------------------------------
  always @(posedge CLK or posedge ARST) begin
    if (ARST) begin
      state          <= S_IDLE;
      DRW_BUSY       <= 1'b0;
      DRW_IRQ        <= 1'b0;
      CMD_FIFO_RD    <= 1'b0;
      LINE_START     <= 1'b0;

      // レジスタ初期値 (適当な安全値)
      reg_frame_addr <= 32'h2000_0000;
      reg_frame_w    <= 11'd640;
      reg_frame_w    <= 11'd480;
      reg_fcolor     <= 32'h0;
      reg_blend_en   <= 1'b0;
    end else if (SOFT_RST) begin
      state <= S_IDLE;
      DRW_BUSY <= 1'b0;
      DRW_IRQ <= 1'b0;
      // ...他リセット
    end else begin
      // パルスリセット
      CMD_FIFO_RD <= 1'b0;
      LINE_START  <= 1'b0;
      DRW_IRQ     <= 1'b0;

      case (state)
        //-------------------------------------------------------------------
        S_IDLE: begin
          if (DRW_START) begin
            DRW_BUSY <= 1'b1;
            state    <= S_FETCH;
          end
        end

        //-------------------------------------------------------------------
        S_FETCH: begin
          if (!CMD_FIFO_EMPTY) begin
            CMD_FIFO_RD <= 1'b1;  // Pop Request
            state       <= S_DECODE;
          end else begin
            // コマンドがなければ待機 (BUSYのまま)
            // 実装によってはここで一旦休止する制御も可
          end
        end

        //-------------------------------------------------------------------
        S_DECODE: begin
          // FIFOはRead Latency=1想定。RDATAが有効になっている
          cmd_code = CMD_FIFO_RDATA[31:24];  // 上位8bitがコマンドコード

          case (cmd_code)
            8'h00: state <= S_FETCH;  // NOP
            8'h0F: state <= S_FINISH;  // EODL

            // パラメータ付きコマンドは、必要なパラメータ数をセットしてWaitへ
            8'h20: begin  // SETFRAME (3 params)
              param_count <= 3;
              state       <= S_PARAM_WAIT;
            end
            8'h21: begin  // SETDRAWAREA (3 params)
              param_count <= 3; // ※仕様書ではPOSX/Y, SIZX/Yで2ワードにパックされている
              state <= S_PARAM_WAIT;
            end
            8'h22: begin  // SETTEXTURE (2 params)
              param_count <= 2;
              state       <= S_PARAM_WAIT;
            end
            8'h23: begin  // SETFCOLOR (2 params)
              param_count <= 2;
              state       <= S_PARAM_WAIT;
            end

            // フラグ設定系 (1ワードで完結するもの)
            8'h32: begin  // SETBLENDOFF
              reg_blend_en <= 1'b0;
              state        <= S_FETCH;
            end

            // 描画実行コマンド
            8'h81: begin  // PATBLT (3 params)
              param_count <= 3;
              state       <= S_PARAM_WAIT;
            end
            8'h82: begin  // BITBLT (4 params)
              param_count <= 4;
              state       <= S_PARAM_WAIT;
            end

            default: state <= S_FETCH;  // 未定義
          endcase
        end

        //-------------------------------------------------------------------
        S_PARAM_WAIT: begin
          // 必要な数だけFIFOからパラメータを読み出して配列に格納
          if (!CMD_FIFO_EMPTY) begin
            CMD_FIFO_RD <= 1'b1;
            // 読み出したデータは次のサイクルで有効になるため、
            // ここでは「読み出し要求」をカウントダウンしつつ、
            // 別ロジック(下部)でデータを格納するか、ステートを細分化する。
            // 簡易実装として、1サイクル1パラメータ読み出しのステートを回す。

            // ※注意: ここでは簡略化のため、「RDATA有効化待ち」ステートを省略して記述しています。
            // 実際は RD -> Wait -> Store のサイクルが必要です。
            // 今回は「FIFOから取り出したデータを cmd_params に詰める」処理を
            // 概念的に記述します。

            // (実装詳細: param_idx を用意して store していく)
            // 読み出し完了したら:
            state <= S_EXEC_SETUP;  // またはレジスタ更新してFETCHへ
          end
        end

        //-------------------------------------------------------------------
        S_EXEC_SETUP: begin
          // コマンドに応じて内部レジスタ更新 or 描画準備
          // ここでは PATBLT / BITBLT の準備を記述
          if (cmd_code == 8'h81 || cmd_code == 8'h82) begin
            loop_y_cnt <= 0;
            // パラメータを変数に展開 (cmd_params[] から取り出し)
            // work_dpos_x <= ...
            // work_dsiz_x <= ...
            state <= S_EXEC_LINE;
          end else begin
            // SET系コマンドならレジスタ更新して次へ
            // update_registers();
            state <= S_FETCH;
          end
        end

        //-------------------------------------------------------------------
        S_EXEC_LINE: begin
          // 1ライン分の転送指示
          // アドレス計算: Base + (PosY + LoopY) * Width * 4byte + PosX * 4byte
          // ※本来はここでクリッピング計算を行い、画面外ならスキップ等の処理が必要

          if (!LINE_BUSY) begin
            LINE_START <= 1'b1;

            // 簡易計算 (フレームバッファへのオフセット)
            // addr = reg_frame_addr + ((work_dpos_y + loop_y_cnt) * reg_frame_w + work_dpos_x) * 4
            // ※乗算が含まれるため、実際の回路ではY座標の加算に合わせてアドレスを足していく
            //   インクリメンタルな計算に直すべきです。

            LINE_ADDR_DST <= reg_frame_addr + ((work_dpos_y + loop_y_cnt) * reg_frame_w + work_dpos_x) * 4;

            // テクスチャアドレス計算 (BITBLTのみ)
            if (cmd_code == 8'h82) begin
              LINE_ADDR_SRC <= reg_tex_addr + ((work_spos_y + loop_y_cnt) * 640 /*仮幅*/ + work_spos_x) * 4;
              // ※テクスチャ幅も設定が必要ですが仕様書に見当たらないため一旦固定か、画面幅と同じと仮定
            end

            LINE_LEN <= work_dsiz_x;  // 横幅ピクセル数

            state <= S_EXEC_WAIT;
          end
        end

        //-------------------------------------------------------------------
        S_EXEC_WAIT: begin
          if (!LINE_BUSY) begin
            state <= S_EXEC_NEXT;
          end
        end

        //-------------------------------------------------------------------
        S_EXEC_NEXT: begin
          loop_y_cnt <= loop_y_cnt + 1;
          if (loop_y_cnt < work_dsiz_y - 1) begin
            state <= S_EXEC_LINE;  // 次のラインへ
          end else begin
            state <= S_FETCH;  // コマンド完了
          end
        end

        //-------------------------------------------------------------------
        S_FINISH: begin
          DRW_BUSY <= 1'b0;
          DRW_IRQ  <= 1'b1;
          state    <= S_IDLE;
        end

      endcase
    end
  end

  // パラメータ出力
  always @(posedge CLK) begin
    PARAM_FCOLOR <= reg_fcolor;
    PARAM_BLEND  <= reg_blend_en;
  end

  always @(posedge CLK) begin
    if (state == S_DECODE) begin
      if (cmd_code == 8'h82) CMD_MODE <= 1'b1;  // BITBLT
      else CMD_MODE <= 1'b0;  // PATBLT (or others)
    end
  end

endmodule
