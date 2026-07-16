-- カーソル移動を滑らかにアニメーションするプラグイン
-- https://github.com/sphamba/smear-cursor.nvim
return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  opts = {
    -- 同一バッファ内の通常移動でもアニメーションさせる
    smear_between_buffers = true,
    smear_between_neighbor_lines = true,
    -- ターミナル/挿入モードでは無効化（パフォーマンスとちらつき回避）
    smear_insert_mode = false,
  },
}
