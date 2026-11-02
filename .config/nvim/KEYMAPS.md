# Neovim キーマップ

よく使うものだけの一覧。`<leader>` はスペースキー。すべての割り当ては `<leader>fk` で検索できる。`<leader>` を押して少し待つと候補も出る（which-key）。

## ファイルと検索

| キー | 動作 |
|------|------|
| `<leader>ff` | ファイルを検索 |
| `<leader>fw` | 文字列を検索（live grep） |
| `<leader>fo` | 最近開いたファイル |
| `<leader>fb` | 開いているバッファ |
| `<leader>fh` | ヘルプを検索 |
| `<leader>fk` | キーマップを検索 |
| `<leader>fp` | プロジェクトを切り替え |
| `<leader>ft` | TODO / FIXME などの一覧 |
| `<leader>e` | ファイルツリーを開閉（Neo-tree） |
| `<leader>o` | ファイルツリーにフォーカス |

## バッファとウィンドウ

| キー | 動作 |
|------|------|
| `<Tab>` / `<S-Tab>` | 次 / 前のバッファへ |
| `<leader>c` / `<leader>C` | バッファを閉じる / 強制的に閉じる |
| `\|` / `\` | 縦 / 横に分割 |
| `<C-h/j/k/l>` | ウィンドウを移動 |

## Git / GitHub

| キー | 動作 |
|------|------|
| `<leader>gn` | 差分の基準を選ぶ（diffbase.nvim） |
| `gh` / `gH` | 次 / 前の変更箇所へ |
| `<leader>gB` | 行ごとの blame を切り替え |
| `<leader>gb` | ブランチ一覧 |
| `<leader>gs` / `<leader>gS` | PR を章立てでレビュー / base ブランチを選んでレビュー（storyline.nvim） |
| `<leader>Ob` | 今のブランチの PR を開く（octo.nvim） |
| `<leader>Op` / `<leader>Oi` | PR 一覧 / Issue 一覧 |
| `<leader>Or` | レビューを開始 |

## LSP

| キー | 動作 |
|------|------|
| `gd` / `gD` | 定義 / 宣言へジャンプ |
| `gI` / `gy` | 実装 / 型定義へジャンプ |
| `gr` | 参照を一覧 |
| `K` | ドキュメントを表示 |
| `<leader>la` | コードアクション |
| `<leader>lr` | リネーム |
| `<leader>lf` | フォーマット |
| `<leader>ld` | カーソル下の診断を表示 |
| `]d` / `[d` | 次 / 前の診断へ |

## 診断の一覧（Trouble）

| キー | 動作 |
|------|------|
| `<leader>xx` / `<leader>xX` | バッファ / プロジェクト全体のエラー一覧 |
| `<leader>xq` / `<leader>xl` | Quickfix / Location リスト |
| `]x` / `[x` | 次 / 前の項目へ |

## Claude へのコメント（nudge.nvim）

| キー | 動作 |
|------|------|
| `<leader>aa` | この行 / 選択範囲にコメント |
| `<leader>ae` / `<leader>ad` | カーソル下のコメントを編集 / 削除 |
| `<leader>al` | コメント一覧（quickfix） |
| `<leader>as` | Claude にまとめて送る（同じ herdr タブの Claude の入力欄に貼るだけ。Enter は自分で押す） |
| `<leader>at` | 送り先の Claude を選び直す |
| `<leader>aC` | コメントをすべて消す |

## Markdown

| キー | 動作 | 使える場所 |
|------|------|------------|
| `<leader>mp` | Obsidian アプリで開く | `.md` |
| `<leader>mb` | ブラウザでプレビュー | `.md` |
| `gd` | `[[wikilink]]` 先のノートへジャンプ | Obsidian の vault 内 |
| `go` | `gd` のジャンプ元へ戻る | Obsidian の vault 内 |
| `<CR>` | カーソル下のリンクをたどる | Obsidian の vault 内 |

## 編集

| キー | 動作 | 例 |
|------|------|----|
| `ys{motion}{文字}` | 囲む | `ysiw"` → `"word"` |
| `cs{旧}{新}` | 囲みを変更 | `cs"'` → `'hello'` |
| `ds{文字}` | 囲みを削除 | `ds"` → `hello` |
| `<leader>/` | コメントアウトを切り替え | |
| `]t` / `[t` | 次 / 前の TODO へ | |

## その他

| キー | 動作 |
|------|------|
| `<leader>w` / `<leader>q` | 保存 / ウィンドウを閉じる |
| `<leader>n` | 新規ファイル |
| `<leader>fu` | Undo 履歴 |
| `<leader>tf` / `<leader>th` / `<leader>tv` | ターミナル（フロート / 水平 / 垂直） |
| `<leader>ub` | テーマを切り替え |
| `<leader>uT` | カーソル周辺以外をフェード |
| `<leader>;` | パンくずからピック |
