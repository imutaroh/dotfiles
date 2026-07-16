-- 画面のどこへでも2〜3キーでジャンプ
-- https://github.com/folke/flash.nvim
return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {
    -- 検索文字を入力した時点で各候補にラベルを表示
    label = {
      rainbow = { enabled = true }, -- ラベルを虹色に
    },
    -- f/F/t/T も flash 化（行をまたいで飛べるようになる）
    modes = {
      char = {
        enabled = true,
        jump_labels = true, -- ; , を待たずにラベル選択で飛べる
      },
      -- / ? 検索中もラベルを出す
      search = {
        enabled = true,
      },
    },
  },
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash ジャンプ" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter（構文選択）" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash（遠隔操作）" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter 検索" },
    { "<C-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Flash 検索トグル" },
  },
}
