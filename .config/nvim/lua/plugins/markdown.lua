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

  -- バッファ内で Obsidian 風にマークダウンをレンダリング（見出し・箇条書き・コードブロック等）
  --
  -- 2026-04-17 に一度削除したが復活。当時の削除理由は
  -- Neovim 0.12.1 × nvim-treesitter master(archived) で
  -- query_predicates.lua:141 → treesitter.lua:196 の range() nil クラッシュが
  -- md を開くたびに画面を埋めることだった。
  --
  -- 恒久解は nvim-treesitter main ブランチ移行だが、AstroNvim v5 コアが
  -- 依然 master + 旧 configs API に固定されており（v6 で main 移行済み）、
  -- treesitter 全体の main 移行はメジャーアップグレードを伴うため見送る。
  --
  -- 代わりに master のまま安全に復活できる。クラッシュは treesitter の
  -- ハイライタ経路（master が登録する 0.12 非互換 predicate を md の
  -- highlights.scm が呼ぶ）で起きるもので、その経路は treesitter.lua /
  -- after/ftplugin/markdown.lua の monkey-patch で今も塞いだままにする。
  -- render-markdown.nvim はハイライタに依存せず、markdown パーサ上で
  -- 自前のクエリ（標準 predicate のみ）を実行して extmark を描くだけなので、
  -- 壊れた predicate を踏まず単体で動作する。必要な markdown /
  -- markdown_inline パーサはインストール済み。
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons", -- アイコン表示（インストール済みのものを利用）
    },
    ft = { "markdown" },
    opts = {},
  },
}
