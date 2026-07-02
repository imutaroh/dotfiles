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

  -- NOTE: render-markdown.nvim は 2026-04-17 に削除。
  -- Neovim 0.12.1 × nvim-treesitter master(archived) の組み合わせで
  -- query_predicates.lua:141 → treesitter.lua:196 の range() nil クラッシュが発生し、
  -- md を開くたびに赤字のスタックトレースで画面が埋まるため。
  -- 復活条件: nvim-treesitter が main ブランチ移行済み、または Neovim 0.11 にダウングレード。
}
