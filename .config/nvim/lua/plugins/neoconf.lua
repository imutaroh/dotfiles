-- neoconf.nvim の VSCode 設定取り込みを無効化
--
-- 動機: 開いたファイルの cwd から上のディレクトリを辿って .vscode/settings.json
-- を見つけると、その内容を LSP の initializationOptions にマージし、
-- 設定が違うとして 2 つ目の LSP クライアントを spawn してしまう。
--
-- 実例: /opt/homebrew/.vscode/settings.json（Ruby/Sorbet/shellcheck 設定）が
-- 過去のセッションで読み込まれ、gopls (id: 2) が hover を二重に返していた。
--
-- 対処: プラグインごと無効にする。VSCode 互換の取り込みだけでなく、リポジトリの .neoconf.json も
-- 確認なしで LSP の設定に混ざるので、他人のリポジトリを開いたときに設定を差し込まれないようにする。
return {
  "folke/neoconf.nvim",
  enabled = false,
}
