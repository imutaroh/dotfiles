-- octo.nvim: GitHub の PR / Issue を Neovim 内で操作（コメント閲覧・返信・レビュー）
-- 前提: gh CLI が認証済みであること（`gh auth status` で確認）
-- picker は明示的に snacks を指定する。octo の既定は telescope だが、この構成は
-- telescope を入れておらず AstroNvim v5 の snacks.picker を使うため、未指定だと壊れる。
return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Octo",
  keys = {
    { "<leader>O", desc = "Octo (GitHub)" },
    { "<leader>Op", "<cmd>Octo pr list<cr>", desc = "PR 一覧" },
    {
      "<leader>Ob",
      function()
        local branch = vim.trim(vim.fn.system("git branch --show-current"))
        vim.cmd("Octo pr search head:" .. branch)
      end,
      desc = "現在ブランチの PR",
    },
    { "<leader>Or", "<cmd>Octo review start<cr>", desc = "レビュー開始" },
    { "<leader>OR", "<cmd>Octo review resume<cr>", desc = "レビュー再開" },
    { "<leader>Oi", "<cmd>Octo issue list<cr>", desc = "Issue 一覧" },
    { "<leader>Os", "<cmd>Octo search<cr>", desc = "検索" },
  },
  opts = {
    picker = "snacks",
  },
}
