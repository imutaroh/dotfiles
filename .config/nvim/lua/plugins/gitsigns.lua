return {
  "lewis6991/gitsigns.nvim",
  opts = {
    -- inline blame は **既定 OFF**。視覚ノイズ（カーソル移動のたびのチカチカ）を避けるため、
    -- 必要な時だけ <leader>gB で trigger する運用にした。
    current_line_blame = false,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "right_align", -- 画面右端に揃えてコードと重ねない
      delay = 1000,                  -- 1s ディレイでカーソル移動時のチカチカを抑制
      ignore_whitespace = true,
    },
    current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local map = function(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end
      -- 変更ハンクを前後に移動
      map("n", "gh", function() gs.next_hunk() end, "次のgit hunkへ")
      map("n", "gH", function() gs.prev_hunk() end, "前のgit hunkへ")
      -- inline blame のトグル（必要な時だけ表示）
      -- <leader>gb は AstroNvim デフォルトの「ブランチ一覧」と衝突するため <leader>gB に住み分け
      map("n", "<leader>gB", function() gs.toggle_current_line_blame() end, "Toggle inline blame")
    end,
  },
}
