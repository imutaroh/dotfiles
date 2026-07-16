return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    source_selector = {
      winbar = true, -- ツリー上部に Files / Bufs / Git のタブを表示
      content_layout = "center",
      sources = {
        { source = "filesystem", display_name = " 󰉓 Files" },
        { source = "buffers",    display_name = " 󰈚 Bufs" },
        { source = "git_status", display_name = " 󰊢 Git" },
      },
    },
    window = {
      width = 45,
      mappings = {
        -- AstroNvim 系の上書きを潰して、明示的にソース切替に固定する
        ["<"] = "prev_source",
        [">"] = "next_source",
        ["H"] = "prev_source", -- 予備（vim 感覚で h/l 方向）
        ["L"] = "next_source",
      },
    },
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        never_show = {
          ".DS_Store",
        },
      },
      use_libuv_file_watcher = true,
      -- 現在開いているファイルを自動でツリー内で追尾＆ハイライト
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true, -- 移動時に途中のディレクトリを閉じない
      },
    },
  },
  init = function()
    -- Neo-tree の幅をインタラクティブに増減するキーマップ
    -- <C-.> で広げる / <C-,> で狭める（物理キー的に `>` `<` と同じ位置）
    -- どのウィンドウにフォーカスがあっても Neo-tree のウィンドウを探して幅を変える
    local function resize_neotree(delta)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "neo-tree" then
          local w = vim.api.nvim_win_get_width(win)
          local new_w = math.max(20, w + delta)
          vim.api.nvim_win_set_width(win, new_w)
          vim.notify("Neo-tree width: " .. new_w, vim.log.levels.INFO)
          return
        end
      end
    end
    vim.keymap.set({ "n", "i", "v" }, "<C-.>", function() resize_neotree(5) end, { desc = "Neo-tree 幅を広げる" })
    vim.keymap.set({ "n", "i", "v" }, "<C-,>", function() resize_neotree(-5) end, { desc = "Neo-tree 幅を狭める" })

    -- 起動時の自動表示は廃止（git commit などで nvim が開くたびにツリーが
    -- 割り込んでくるのを防ぐため）。ツリーは手動（<leader>e など）で開く。

    -- Neovim にフォーカスが戻った時に Neo-tree をリフレッシュ
    -- （ツリーが開いているときだけ動くので、勝手には開かない）
    vim.api.nvim_create_autocmd("FocusGained", {
      callback = function()
        pcall(vim.cmd, "Neotree refresh")
      end,
    })

    -- バッファ切り替え時に現在ファイルを Neo-tree 上で reveal する
    -- ただし「ツリーが既に開いている時だけ」発火。閉じている時は勝手に開かない。
    -- （分割やフォーカス移動のたびにツリーが復活するのを防ぐ）
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
      callback = function()
        -- Neo-tree のウィンドウが今開いているか確認
        local tree_open = false
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local b = vim.api.nvim_win_get_buf(win)
          if vim.bo[b].filetype == "neo-tree" then
            tree_open = true
            break
          end
        end
        if not tree_open then return end -- 閉じてるなら何もしない

        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].buftype ~= "" then return end
        if vim.bo[buf].filetype == "neo-tree" then return end
        local file = vim.api.nvim_buf_get_name(buf)
        if file == "" or vim.fn.filereadable(file) ~= 1 then return end
        vim.schedule(function()
          -- reveal_force_cwd=true: ファイルがツリーの cwd 外にある場合でも
          -- 「File not in cwd. Change cwd to ...?」を聞かずに黙って追従する
          pcall(vim.cmd, "Neotree action=show reveal_file=" .. vim.fn.fnameescape(file) .. " reveal_force_cwd=true")
        end)
      end,
    })
  end,
}
