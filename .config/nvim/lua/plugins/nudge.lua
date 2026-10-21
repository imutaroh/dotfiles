-- コードの行や範囲に Claude へのコメントを溜めて、同じ herdr タブの Claude ペインにまとめて送る。
-- 本体は自作プラグイン nudge.nvim（~/repos/imutaroh/nudge.nvim）。公開後は "imutaroh/nudge.nvim" に置き換える
return {
  {
    dir = "~/repos/imutaroh/nudge.nvim",
    name = "nudge.nvim",
    cmd = "Nudge",
    keys = {
      { "<leader>aa", function() require("nudge").add() end, mode = { "n", "x" }, desc = "この行/選択範囲にコメント" },
      { "<leader>ae", function() require("nudge").edit() end, desc = "カーソル下のコメントを編集" },
      { "<leader>ad", function() require("nudge").delete() end, desc = "カーソル下のコメントを削除" },
      { "<leader>al", function() require("nudge").list() end, desc = "コメント一覧（quickfix）" },
      { "<leader>as", function() require("nudge").send() end, desc = "Claude にまとめて送る" },
      { "<leader>at", function() require("nudge").target() end, desc = "送り先の Claude を選び直す" },
      { "<leader>aC", function() require("nudge").clear() end, desc = "コメントを全部消す" },
    },
    opts = {
      header = "以下のコードにコメントしました。それぞれ対応してください。",
    },
  },
}
