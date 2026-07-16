-- Neovim 0.12.1 × nvim-treesitter master (archived 2025-05-18) の markdown パーサが
-- 新 API の nil ノードで落ちるため、treesitter を使う経路を md バッファで全て塞ぐ。
-- 恒久対応は nvim-treesitter main ブランチ移行 or Neovim 0.11 ダウングレード。

-- built-in ftplugin/markdown.lua が呼んだ vim.treesitter.start() を解除
pcall(vim.treesitter.stop)

-- snacks.nvim の treesitter 依存モジュールをこのバッファで無効化
-- （scope.lua:404 で parser:parse() がクラッシュするため）
vim.b.snacks_scope = false
vim.b.snacks_indent = false
