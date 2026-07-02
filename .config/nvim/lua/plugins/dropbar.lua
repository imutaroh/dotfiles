-- ウィンドウ上部に "プロジェクト > ディレクトリ > ファイル > 関数 > ..." の
-- パンくずリストを表示（VSCode の breadcrumb 相当）
--
-- パス + 今カーソルがいる関数/構造体/メソッドまで一目で分かる。
-- "なんもわからん😢" 対策の主役。
--
-- https://github.com/Bekaboo/dropbar.nvim
return {
  "Bekaboo/dropbar.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    bar = {
      -- Neo-tree や terminal 等の特殊バッファでは出さない
      enable = function(buf, win, _)
        if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
          return false
        end
        local ft = vim.bo[buf].filetype
        if ft == "neo-tree" or ft == "alpha" or ft == "snacks_dashboard" then
          return false
        end
        return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
      end,
    },
    icons = {
      kinds = {
        use_devicons = true,
      },
    },
  },
  keys = {
    -- パンくずをクリックする代わりにキーボードで操作
    { "<leader>;", function() require("dropbar.api").pick() end, desc = "Breadcrumb をピック" },
  },
}
