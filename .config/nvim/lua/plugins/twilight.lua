-- カーソル周辺以外のコードをフェードアウトさせて集中モードを実現
-- https://github.com/folke/twilight.nvim
return {
  "folke/twilight.nvim",
  cmd = { "Twilight", "TwilightEnable", "TwilightDisable" },
  keys = {
    { "<leader>uT", "<cmd>Twilight<cr>", desc = "Twilight トグル（周辺コードをフェード）" },
  },
  opts = {
    dimming = {
      alpha = 0.25,         -- 暗くする度合い（0=完全に暗い / 1=変化なし）
      inactive = false,     -- 非アクティブウィンドウは対象外（一緒に暗くしない）
    },
    context = 10,           -- カーソル前後何行を「明るく」保つか
    treesitter = true,      -- treesitter のスコープ単位で明るくする（関数全体など）
    expand = {              -- このノード種別はスコープ全体を明るく保つ
      "function",
      "method",
      "table",
      "if_statement",
    },
  },
}
