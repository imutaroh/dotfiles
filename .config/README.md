# .config

各種アプリケーションの設定ファイル。`~/.config/` にシンボリックリンクされる。

セットアップ方法は [親ディレクトリの README](../README.md) を参照。

## ディレクトリ構成

```
.config/
├── ghostty/           # ターミナルエミュレータ
├── git/               # Git グローバル設定
├── lazygit/           # Git TUI クライアント
├── mise/              # ランタイムバージョン管理
├── nvim/              # エディタ（詳細は nvim/README.md）
├── raycast/           # ランチャー
├── starship.toml      # シェルプロンプト
└── uv/                # Python パッケージ管理
```

> [!NOTE]
> ターミナル多重化は [herdr](https://herdr.dev) を使用している。herdr の設定（`~/.config/herdr/config.toml`）は dotfiles に未ミラーの例外。

## [Ghostty](https://ghostty.org/)

GPU ベースの高速ターミナルエミュレータ。macOS / Linux 対応。

### ファイル構成

| ファイル | 説明 |
|----------|------|
| `config` | 設定ファイル |

### 主な設定

| カテゴリ | 設定内容 |
|----------|----------|
| テーマ | GitHub Dark |
| フォント | Moralerspace Argon（14pt、行間 +2px） |
| 背景 | 不透明度 0.9、ぼかし効果（半径 20px） |
| ウィンドウ | パディング 16px、タイトルバー透明化 |
| カーソル | ブロック型、点滅なし |
| キーバインド | Cmd 系キーを herdr のプレフィックス（Ctrl+Q）＋キーに変換して送信（ペイン分割・移動、タブ、Space 操作など）。左 Option キーは Alt として使用 |

## Git

グローバル gitignore の設定。全リポジトリ共通で機密情報の誤コミット防止、OS/エディタの不要ファイル除外をガードレールとして提供する。

### ファイル構成

| ファイル | 説明 |
|----------|------|
| `ignore` | グローバル gitignore（`~/.config/git/ignore` に配置すると Git が自動認識） |

### 除外対象

| カテゴリ | パターン例 |
|----------|------------|
| 機密情報 | `.env`, `*.pem`, `*.key`, `credentials.json`, `service-account*.json` |
| OS 生成ファイル | `.DS_Store`, `Thumbs.db` |
| エディタ | `*.swp`, `*.swo`, `*~` |
| 一時ファイル | `tmp/` |

## [mise](https://mise.jdx.dev/)

プログラミング言語のバージョン管理ツール。asdf の Rust 製代替で高速。グローバルにインストールする言語を管理する（プロジェクト単位の Python 管理は uv を使用）。

### 設定内容

| 項目 | 値 |
|------|-----|
| Python | 3.13 |

## [Neovim](https://neovim.io/)

Vim ベースの高機能テキストエディタ。[AstroNvim](https://astronvim.com/) をベースにカスタマイズ。

詳細は [nvim/README.md](nvim/README.md) を参照。

## [Raycast](https://www.raycast.com/)

macOS 用ランチャーアプリ。Spotlight の高機能版で、カスタムスクリプトやワークフローを実行できる。

> [!NOTE]
> このディレクトリには個人用のスクリプトコマンドのみ格納しており、他の人には不要な場合が多い。

### スクリプトコマンド

| ファイル | 説明 |
|----------|------|
| `delete-screenshot.sh` | スクリーンショットを削除 |
| `open-marimo.sh` | marimo（Python ノートブック）を起動 |
| `zettel-id.sh` | Zettelkasten 用の ID を生成 |

## [Starship](https://starship.rs/)

シェルプロンプトのカスタマイズツール。Rust 製で高速。Git ブランチ、言語バージョンなどをプロンプトに表示できる。

### 設定内容

デフォルト設定を使用。カスタマイズする場合は [公式ドキュメント](https://starship.rs/config/) を参照。

## [uv](https://docs.astral.sh/uv/)

高速な Python パッケージマネージャ。pip / venv の代替として使用。Rust 製で pip より 10〜100 倍速い。

### 設定内容

| 項目 | 値 | 説明 |
|------|-----|------|
| `python-preference` | `only-managed` | mise で管理された Python のみ使用 |

## [lazygit](https://github.com/jesseduffield/lazygit)

Git の TUI クライアント。Neovim からも呼び出して使用する。

### ファイル構成

| ファイル | 説明 |
|----------|------|
| `config.yml` | 設定ファイル（カスタムコミットコマンド等） |
