return {
  "echasnovski/mini.diff",
  version = false,
  event = "BufReadPre",
  opts = {
    view = { style = "sign" },
  },
  keys = {
    {
      "<leader>gM",
      function()
        local rel = vim.fn.system("git ls-files --full-name " .. vim.fn.expand("%")):gsub("\n", "")
        if rel == "" then
          vim.notify("git 管理外のファイルです", vim.log.levels.WARN)
          return
        end
        local content = vim.fn.system("git show origin/main:" .. rel)
        if vim.v.shell_error == 0 then
          require("mini.diff").set_ref_text(0, content)
        else
          vim.notify("origin/main に存在しません: " .. rel, vim.log.levels.WARN)
        end
      end,
      desc = "Diff: origin/main と inline 比較",
    },
    {
      "<leader>gi",
      function() require("mini.diff").toggle_overlay(0) end,
      desc = "Diff: inline diff を toggle",
    },
  },
}
