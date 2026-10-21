-- 普段の編集画面のまま「何と比べた差分を見るか」を切り替える。<leader>gn で比べる相手を選ぶ。
-- 本体は自作プラグイン diffbase.nvim（~/repos/imutaroh/diffbase.nvim）。公開後は "imutaroh/diffbase.nvim" に置き換える
return {
  {
    dir = "~/repos/imutaroh/diffbase.nvim",
    name = "diffbase.nvim",
    cmd = "DiffBase",
    keys = {
      { "<leader>gn", function() require("diffbase").pick() end, desc = "差分の基準を選ぶ（diffbase）" },
    },
    opts = {
      -- 「コミットを選ぶ」はそのコミットに detach する。公開版では既定 OFF なので、ここで有効にする
      commit_view = true,
      -- メニューの表示名だけ日本語にする（中身は公開版の既定と同じ）
      bases = {
        { name = "main", label = "main との差分（このブランチの全変更）", ref = "@default", merge_base = true },
        { name = "previous", label = "直前のコミットから", ref = "HEAD~1" },
        { name = "unpushed", label = "まだ push していない変更", ref = "@{upstream}", merge_base = true },
      },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = { "diffbase.nvim" },
    -- ファイル名の横に +追加 -削除 の行数（ディレクトリは配下の合計）を出す
    opts = function(_, opts) return require("diffbase.integrations.neotree").setup_opts(opts) end,
  },
}
