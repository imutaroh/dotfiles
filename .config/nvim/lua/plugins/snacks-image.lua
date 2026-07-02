-- snacks.image（インライン画像プレビュー）を無効化
--
-- Neovim 0.12.1 × nvim-treesitter master (archived 2025-05-18) の組み合わせで、
-- snacks/image/doc.lua:241 → snacks/util/init.lua:464 → treesitter.lua:196 の経路で
-- "attempt to call method 'range' (a nil value)" が発生してクラッシュするため、
-- 機能ごとオフにする。
--
-- Ghostty は画像プロトコル対応のため snacks が自動で有効化してしまうのを抑止する。
-- 恒久対応は nvim-treesitter main ブランチ移行 or Neovim 0.11 ダウングレード。
return {
  "folke/snacks.nvim",
  opts = {
    image = { enabled = false },
  },
}
