-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    options = {
      opt = {
        wrap = true,           -- 折り返しを有効化
        linebreak = true,      -- 単語の途中で折り返さない
        breakindent = true,    -- 折り返し行もインデントを維持
        cursorline = true,     -- カーソルラインを有効化
        swapfile = false,      -- スワップファイルを無効化（Git + undofile で十分）
        number = true,         -- 絶対行番号
        relativenumber = false, -- 相対行番号は OFF（3,2,1,(85),1,2,3 という見た目の混乱を避ける）
        scrolloff = 8,         -- カーソル上下に常に8行の余白を確保（読みながら書ける）
        sidescrolloff = 8,     -- カーソル左右に常に8文字の余白を確保
        smoothscroll = true,   -- 折返し行を画面行単位でスクロール（<C-e>/<C-y>）
      },
    },
    mappings = {
      n = {
        -- Tab でバッファを移動（ブラウザのタブ操作と同じ感覚）
        ["<Tab>"] = { "<cmd>bnext<cr>", desc = "次のバッファへ" },
        ["<S-Tab>"] = { "<cmd>bprevious<cr>", desc = "前のバッファへ" },
        -- プロジェクト切替
        ["<leader>fp"] = { "<cmd>Telescope projects<cr>", desc = "プロジェクトを検索" },
      },
      x = {
        -- ビジュアルモードで p を押した際、置き換えたテキストをレジスタに残さない
        ["p"] = { '"_dP', desc = "貼付（レジスタを上書きしない）" },
      },
      t = {
        -- ターミナルモードを <Esc><Esc> で抜ける（シェル内の Esc を奪わないよう2連打）
        ["<Esc><Esc>"] = { [[<C-\><C-n>]], desc = "ターミナルモードを抜ける" },
      },
    },
    autocmds = {
      -- 外部ツール（Claude Code など）がファイルを変更したら自動リロード
      auto_reload = {
        {
          event = { "FocusGained", "BufEnter", "CursorHold" },
          command = "silent! checktime",
        },
        {
          event = "FileChangedShell",
          callback = function() vim.v.fcs_choice = "reload" end,
        },
      },
      -- ファイルを開いた時に空の [No Name] バッファを削除
      cleanup_noname = {
        {
          event = "BufReadPost",
          callback = function()
            vim.schedule(function()
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf)
                  and vim.api.nvim_buf_get_name(buf) == ""
                  and vim.bo[buf].buftype == ""
                  and vim.api.nvim_buf_line_count(buf) <= 1
                  and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
                then
                  pcall(vim.api.nvim_buf_delete, buf, {})
                end
              end
            end)
          end,
        },
      },
      -- アクティブウィンドウのみカーソルラインを表示
      active_window_cursorline = {
        {
          event = "VimEnter",
          callback = function()
            -- 起動時: 現在のウィンドウ以外のカーソルラインをオフ
            local current_win = vim.api.nvim_get_current_win()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              if win ~= current_win then
                vim.api.nvim_set_option_value("cursorline", false, { win = win })
              end
            end
          end,
        },
        {
          event = { "WinEnter", "BufEnter" },
          callback = function() vim.opt_local.cursorline = true end,
        },
        {
          event = { "WinLeave", "BufLeave" },
          callback = function() vim.opt_local.cursorline = false end,
        },
      },
    },
  },
}
