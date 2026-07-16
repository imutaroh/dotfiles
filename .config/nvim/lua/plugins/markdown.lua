-- Markdown 編集・プレビュー強化
-- Obsidian ノートを Neovim で快適に編集するための設定

return {
  -- ブラウザでリアルタイムプレビュー
  -- <leader>mp でブラウザが開き、編集と同時にレンダリングされる
  --
  -- NOTE: build は app/install.sh を直接叩く方式に変更。
  -- 旧: vim.fn["mkdp#util#install"]() は Lazy 初回ビルド時に
  -- バイナリ取得が無音失敗して bin/ が空のままになるケースがあった
  -- （プレビュー起動時に "command not found" 系で死ぬ）。
  -- install.sh は Mac arm64 向けの pre-built バイナリ（17MB）を
  -- リリースから直接 tar 展開するだけなので確実。
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && bash install.sh",
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview (browser)" },
    },
    init = function()
      -- テーマをダークモードに（config だと cmd 経路だけ初期化されないので init で設定）
      vim.g.mkdp_theme = "dark"
      -- ブラウザを自動で開かない（:MarkdownPreview を叩いたときだけ開く）
      vim.g.mkdp_auto_start = 0
      -- Neovim を閉じたらプレビューも閉じる
      vim.g.mkdp_auto_close = 1
      -- ファイルタイプ: markdown で有効化
      vim.g.mkdp_filetypes = { "markdown" }
    end,
  },

  -- NOTE: render-markdown.nvim（バッファ内 markdown 装飾）は 2026-07-10 に恒久削除。
  -- 2026-04-17 に一度削除 → 「ハイライタ経路の monkey-patch があれば単体で動く」との
  -- 読みで復活させたが、その前提が誤りで再クラッシュした。
  -- render-markdown は vim.treesitter.start() を経由せず自前で parser:parse() を呼ぶため、
  -- treesitter.lua の start monkey-patch では構造的に捕まえられない。その parse が
  -- injection 処理（languagetree _get_injections → _apply_directives）で master(archived) の
  -- 0.12 非互換ディレクティブを踏み、treesitter.lua:196 の range() nil で落ちる。
  -- 恒久解は nvim-treesitter main 移行だが AstroNvim v5 コアが master 固定のため見送り。
  -- バッファ内装飾は諦め、プレビューは上の markdown-preview.nvim（<leader>mp）で代替する。
  -- treesitter main へ移行できたら再検討する。
}
