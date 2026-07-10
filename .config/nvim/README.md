# [Neovim](https://neovim.io/)

[AstroNvim](https://astronvim.com/) v5 をベースにした Neovim 設定。

## 概要

Vim 初心者がゼロから設定を構築するのは大変なため、オールインワンのディストリビューション（プラグインや設定があらかじめ組み込まれた配布パッケージ）である AstroNvim をベースに、必要な部分だけカスタマイズする方針を採用。IDE 風の機能（ファイルツリー、LSP、Git 連携など）が最初から揃っており、追加設定の学習コストを抑えられる。

### 前提条件

| 項目 | 要件 |
|------|------|
| Neovim | v0.9.0 以上 |
| フォント | Nerd Font 対応フォント（ファイルアイコン等の表示に必要。[Nerd Fonts](https://www.nerdfonts.com/) 参照） |
| Git | プラグイン管理に必要 |
| macism | IME 自動切替に必要（`brew install macism`） |

### プラグイン管理

[lazy.nvim](https://github.com/folke/lazy.nvim) で管理。AstroNvim が内部で採用しており、起動時に自動でブートストラップされる。

### 参考リンク

- [AstroNvim ドキュメント](https://docs.astronvim.com/) - 設定方法の詳細
- [AstroNvim GitHub](https://github.com/AstroNvim/AstroNvim) - ソースコード

## ファイル構成

```
nvim/
├── init.lua              # エントリーポイント
├── lazy-lock.json        # プラグインバージョンのロックファイル
├── lua/
│   ├── lazy_setup.lua    # lazy.nvim 設定
│   ├── community.lua     # AstroCommunity プラグインパック（Lua / Go 有効化済み）
│   ├── polish.lua        # 最終処理（テンプレート・無効化中）
│   └── plugins/          # カスタムプラグイン設定（下のカタログ参照）
├── .luarc.json           # Lua LSP 設定
├── .neoconf.json         # neoconf 設定
├── .stylua.toml          # StyLua フォーマッタ設定
├── selene.toml           # Selene リンター設定
└── neovim.yml            # Selene 用 vim グローバル定義
```

## プラグインカタログ（lua/plugins/）

各ファイルの詳しい設定意図はファイル先頭のコメントに書いてある。ここは索引。

### Git / GitHub

役割分担: **書きながら見る = gitsigns、ひとりで読む = diffview、GitHub に書く = octo、ローカル git 操作 = lazygit**。
（Claude とペアレビューするときは nvim 外の [Hunk](https://hunk.dev/) を使う）

| ファイル | 役割 | 主なキー |
|----------|------|----------|
| `gitsigns.lua` | バッファ内 hunk 表示・blame（blame は既定 OFF） | `gh`/`gH` hunk 移動、`<leader>gB` blame |
| `diffview.lua` | 差分閲覧・ブランチ比較（読み専用） | `<leader>gd` diff、`<leader>gm` vs main、`<leader>gu` 未push、`<leader>gh` ファイル履歴 |
| `octo.lua` | GitHub PR / Issue の閲覧・コメント・レビュー提出 | `<leader>Ob` 現ブランチPR、`<leader>Op`/`Oi` 一覧、`<leader>Or` レビュー |
| `lazygit.lua` | Git TUI（snacks 経由） | `<leader>gg` 起動、`<leader>gf` ファイル履歴 |

### テーマ / 見た目

| ファイル | 役割 | 主なキー |
|----------|------|----------|
| `colorschemes.lua` | ループ切替用の4テーマ（tokyonight / catppuccin / kanagawa / rose-pine、全て透過背景） | — |
| `theme-cycle.lua` | テーマのループ切替＋透過の強制再適用 | `<leader>ub`、`:CycleTheme` |
| `astroui.lua` | 既定テーマ（tokyonight-storm）等の UI 設定 | — |
| `bufferline.lua` | バッファをタブ風に表示 | — |
| `lualine.lua` | モード表示付きステータスライン | — |
| `dropbar.lua` | パンくずリスト（VSCode breadcrumb 相当） | `<leader>;` ピック |
| `smear-cursor.lua` | カーソル移動アニメーション | — |
| `twilight.lua` | カーソル周辺以外をフェードする集中モード | `<leader>uT` |
| `snacks-image.lua` | snacks.image を無効化（treesitter 互換クラッシュ回避） | — |

### 編集 / 移動

| ファイル | 役割 | 主なキー |
|----------|------|----------|
| `flash.lua` | 画面内ジャンプ（f/F/t/T 拡張） | 検索ラベルジャンプ |
| `surround.lua` | 囲み文字の追加・変更・削除 | `ys`/`cs`/`ds` |
| `neo-tree.lua` | ファイルツリー（隠しファイル表示、起動時フォーカス） | — |
| `trouble.lua` | 診断・エラーの一覧表示 | `<leader>xx`/`xX`/`xq`/`xl` |
| `todo-comments.lua` | TODO/FIXME 等のハイライト | `<leader>ft` 一覧 |
| `aerial.lua` | aerial のバージョン固定解除（Neovim 0.12 互換対応） | — |

### LSP / 言語

| ファイル | 役割 |
|----------|------|
| `astrolsp.lua` | LSP 設定（gopls / ts_ls / pyright 等） |
| `mason.lua` | LSP サーバー・ツールの自動インストール |
| `conform.lua` | 保存時の自動フォーマット |
| `treesitter.lua` | シンタックスハイライト（言語パーサー設定） |
| `neoconf.lua` | VSCode 設定の取り込みを無効化（LSP 二重起動対策） |
| `markdown.lua` | Markdown プレビュー（`<leader>mp` でブラウザ表示） |

### その他

| ファイル | 役割 |
|----------|------|
| `astrocore.lua` | コア設定（折り返し、カーソルライン、autocmd） |
| `im-select.lua` | Insert モードを抜けたら IME を英語に自動切替 |
| `keymaps-ja.lua` | which-key の説明文を日本語化 |

## 基本設定

| カテゴリ | 設定内容 | 理由 |
|----------|----------|------|
| Leader キー | Space | AstroNvim デフォルト。押しやすく、多くのキーマップで使用 |
| カラースキーム | tokyonight-storm（既定）＋ `<leader>ub` で4テーマループ | 気分で切替。全テーマ透過設定済み |
| 背景 | 透明化 | Ghostty のぼかし効果を透過させるため |
| 行の折り返し | 有効（単語境界で折り返し） | 長い行を横スクロールせずに読めるようにするため |
| カーソルライン | アクティブウィンドウのみ表示 | 複数ウィンドウ時にどこにいるか視認しやすくするため |

## カスタマイズ方法

### プラグインを追加する

`lua/plugins/` ディレクトリに新しい Lua ファイルを作成する。

```lua
-- lua/plugins/example.lua
return {
  "作者名/プラグイン名",
  event = "VeryLazy",  -- 遅延読み込み（任意）
  opts = {
    -- プラグインの設定
  },
}
```

### 既存プラグインの設定を変更する

同じプラグイン名で新しいファイルを作成すると、設定がマージされる。

```lua
-- lua/plugins/my-neo-tree.lua
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    -- 追加・上書きしたい設定のみ記述
  },
}
```

### キーマップを追加する

`astrocore.lua` の `mappings` セクションに追加する。

```lua
-- lua/plugins/astrocore.lua 内
opts = {
  mappings = {
    n = {  -- Normal モード
      ["<Leader>x"] = { "<cmd>SomeCommand<cr>", desc = "説明" },
    },
  },
}
```

### よく使うコマンド

| コマンド | 説明 |
|----------|------|
| `:Lazy` | プラグイン管理画面を開く |
| `:Lazy sync` | プラグインを同期（インストール・更新） |
| `:Lazy clean` | スペックから消えたプラグインの実体を削除 |
| `:Mason` | LSP/ツール管理画面を開く |
| `:checkhealth` | Neovim の健全性チェック |

### 参考資料

- [AstroNvim 設定ガイド](https://docs.astronvim.com/configuration/manage_user_config/) - 公式ドキュメント
- [lazy.nvim プラグイン仕様](https://lazy.folke.io/spec) - プラグイン設定の書き方
