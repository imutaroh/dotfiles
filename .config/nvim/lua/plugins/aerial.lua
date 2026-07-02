-- aerial.nvim の version 固定を上書きする
--
-- AstroNvim の lazy_snapshot は aerial を "^2.2" に固定しているが、
-- 2.x は Neovim 0.12 の treesitter API と非互換で、md を開くたびに
-- extensions.lua:115 "attempt to call method 'type' (a nil value)" が出る。
-- 3.x で修正済み（c954d38 "ci: run tests against new nvim-treesitter API"）。
return {
  "stevearc/aerial.nvim",
  version = false,
}
