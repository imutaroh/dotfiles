-- neoconf.nvim の VSCode 設定取り込みを無効化
--
-- 動機: 開いたファイルの cwd から上のディレクトリを辿って .vscode/settings.json
-- を見つけると、その内容を LSP の initializationOptions にマージし、
-- 設定が違うとして 2 つ目の LSP クライアントを spawn してしまう。
--
-- 実例: /opt/homebrew/.vscode/settings.json（Ruby/Sorbet/shellcheck 設定）が
-- 過去のセッションで読み込まれ、gopls (id: 2) が hover を二重に返していた。
--
-- 対処: VSCode 互換取り込みは Neovim では不要なので OFF。
-- 必要になったら個別プロジェクトに .neoconf.json を置く運用に切り替える。
return {
  "folke/neoconf.nvim",
  opts = {
    import = {
      vscode = false, -- .vscode/settings.json を読まない（今回の二重 gopls の根治）
      coc = false,    -- coc-settings.json も無視
      nlsp = false,   -- nlsp-settings.json も無視
    },
  },
}
