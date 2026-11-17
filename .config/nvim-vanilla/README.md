# nvim-vanilla

純正の Neovim の操作を身につけるための、プラグインなしの設定。`vv` で起動する（`NVIM_APPNAME=nvim-vanilla nvim`）。

## 学ぶ順番

1. `:Tutor` — 公式チュートリアル（30 分）。最初に 1 周する
2. `:help user-manual` — 公式マニュアル。目次から 1 章ずつ
3. `:help index` — 全キーの一覧。`:help <キー>` でそのキーの説明が引ける

## 純正で足りるもの（拡張の代わり）

| やりたいこと | 純正の方法 |
|---|---|
| ファイルを開く・探す | `:e <path>`（Tab 補完）、`:find`、`:Explore`（netrw） |
| 文字列検索 | `/` `?` `n` `N`、`*`（カーソルの単語） |
| プロジェクト内検索 | `:grep` `:vimgrep` → `:copen` `:cnext` |
| 移動 | `w b e` `f t` `%` `{ }` `Ctrl-o / Ctrl-i`（ジャンプ履歴） |
| 囲み・テキストオブジェクト | `ciw` `ci"` `ca(` `dit` |
| バッファ | `:ls` `:b <名前>` `Ctrl-^` |
| 補完 | `Ctrl-n / Ctrl-p`（挿入モード） |
| 定義ジャンプ | `gd` `Ctrl-]` `Ctrl-t`（tags / LSP は後で） |
| マクロ | `qa` … `q` → `@a` `@@` |
