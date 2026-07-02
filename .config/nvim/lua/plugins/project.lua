-- project.nvim: プロジェクト切替プラグイン
-- <leader>fp でプロジェクト一覧を表示して切り替える

---@type LazySpec
return {
  {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
    config = function()
      require("project_nvim").setup {
        -- .git や package.json などでプロジェクトルートを自動検出
        detection_methods = { "pattern", "lsp" },
        patterns = { ".git", "package.json", "pyproject.toml", "Makefile" },
        show_hidden = false,
        silent_chdir = true,
        manual_mode = false,
      }
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    config = function(_, opts)
      require("telescope").load_extension "projects"
    end,
  },
}
