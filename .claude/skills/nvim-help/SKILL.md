---
name: nvim-help
description: ユーザーの Neovim（AstroNvim ベース）について「〜するにはどのキー？」「gd って何？」「未pushの差分を見たい」「nvim で何ができる？」といった操作方法・キーマップ・機能の質問に、~/dotfiles/.config/nvim の実際の設定を参照して回答する。nvim / Neovim / vim のキーバインド・操作・プラグインに関する質問全般で使用する。どのディレクトリからでも使用可能。
---

# nvim-help

ユーザーの Neovim 設定を実際に読んで、キーマップと機能の質問に答えるスキル。

## 前提

- 構成: **AstroNvim v5** ベース。**Leader = Space**
- 設定の場所: `~/dotfiles/.config/nvim`（必ず絶対パスで参照する。カレントディレクトリに依存しない）
- キーマップの定義は複数ファイルに分散している（下記マップ参照）

## 回答手順

1. **`lua/` 全体を grep する**（キー名でも、やりたいこと（日本語）でも desc にヒットする）
   ```bash
   grep -rin "検索したい語" ~/dotfiles/.config/nvim/lua/
   ```
   ヒットの解釈:
   - `keymaps-ja.lua` のヒット = **説明カタログ**（which-key 表示用。実体定義ではない）。AstroNvim デフォルトの説明はここにしか無いことが多い
   - それ以外のファイルのヒット = **実体定義（こちらが正）**。カスタムキー（diffview の `<leader>gu` 等）はカタログに載っておらず定義ファイルにしか無いことが多い
   - 両方ヒットして食い違う場合は定義ファイルを正とする。実例: keymaps-ja.lua では `<Leader>ft`=「テーマを検索」だが、実体は todo-comments.lua が `<leader>ft` を TodoTelescope で上書きしている

2. **どこにも無ければ AstroNvim デフォルト**
   リポジトリに無いキーは AstroNvim v5 のデフォルト（https://docs.astronvim.com/mappings/）。知識で回答し、「AstroNvim デフォルト」であることを明記する。不確かなら断定しない。

3. **実機での確認方法を添える**
   - `<Leader>fk` — キーマップを Telescope で検索
   - `<Leader>` を押して待つ — which-key がグループ一覧を表示
   - `:h キー名` — Vim 標準機能のヘルプ

## 設定ファイルマップ

| ファイル（`lua/` 以下） | 内容 |
|---|---|
| `plugins/keymaps-ja.lua` | 全キーマップの日本語カタログ（which-key 表示用・第一参照） |
| `plugins/astrocore.lua` | 一般マッピング（Tab バッファ移動等）・vim オプション・autocmd |
| `plugins/astrolsp.lua` | LSP 系: `gd` 定義 / `gD` 宣言 / `gI` 実装 / `gr` 参照 / `gy` 型定義 / `gK` シグネチャ / `gl` 診断。LSP サーバー一覧と format_on_save 設定もここ |
| `plugins/*.lua` の `keys = {}` | プラグイン固有キー（下の質問トピック別ルーティング参照） |
| `community.lua` | AstroCommunity パック（lua, go — neotest-go / dap-go 等を同梱） |
| `lazy_setup.lua`, `polish.lua` | lazy.nvim セットアップ・最終調整 |

### 質問トピック別ルーティング

| トピック | 見るファイル（`lua/plugins/`） |
|---|---|
| Git 差分・未push・ブランチ比較 | `diffview.lua` |
| lazygit | `lazygit.lua` |
| hunk 単位の git 操作・インライン diff | `gitsigns.lua`, `mini-diff.lua` |
| GitHub の PR / Issue / レビュー | `octo.lua` |
| 診断・quickfix 一覧 | `trouble.lua` |
| 画面内ジャンプ | `flash.lua` |
| ファイルツリー | `neo-tree.lua` |
| シンボルアウトライン | `aerial.lua` |
| Markdown プレビュー・表示 | `markdown.lua` |
| TODO コメント | `todo-comments.lua` |
| テーマ・見た目切替 | `theme-cycle.lua`, `colorschemes.lua`, `twilight.lua`, `astroui.lua` |
| パンくず（breadcrumb） | `dropbar.lua` |
| フォーマッタ・リンタ | `conform.lua`, `none-ls.lua`, `mason.lua` |
| 日本語入力（IME）切替 | `im-select.lua` |
| プロジェクト切替 | `project.lua` |

## 「nvim で何ができる？」系の質問

導入プラグインの一覧と目的を答える。各ファイルの冒頭に日本語コメントで目的が書いてあるので、それを活用する:

```bash
head -3 ~/dotfiles/.config/nvim/lua/plugins/*.lua
```

## 回答スタイル

- 「**キー** → 何が起きるか → 定義元 `ファイル:行`」の形式で簡潔に
- 関連キーが近くに定義されていれば併せて紹介する（例: `<leader>gu` を聞かれたら `<leader>gm` ブランチ全体差分も）
- ユーザーは AstroNvim のデフォルトを keymaps-ja.lua で日本語化するほどキーマップを大事にしている。曖昧な回答や未確認の推測を返さない
