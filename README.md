# dotfiles

macOS 用の個人設定ファイル管理リポジトリ。

![開発環境](assets/dev-environment.png)
*Ghostty + herdr 上で Claude Code と hunk（差分ビューア）を使った開発環境*

シェル、エディタ、ターミナル等の設定をシンボリックリンクで管理する。`~/dotfiles/` に clone して使用。

## 技術スタック

| カテゴリ | ツール | 説明 |
|----------|--------|------|
| OS | macOS | Intel / Apple Silicon 両対応 |
| パッケージ管理 | Homebrew | macOS 用パッケージマネージャ |
| | mise | ランタイムバージョン管理（Python 等） |
| | uv | 高速な Python パッケージマネージャ |
| シェル | zsh | デフォルトシェル |
| | Starship | カスタマイズ可能なプロンプト |
| ターミナル | Ghostty | ターミナルエミュレータ |
| | herdr | エージェントマルチプレクサ（tmux / 旧 Zellij の後継。設定は `.config/herdr/` で管理） |
| 開発ツール | Neovim（AstroNvim ベース） | エディタ |
| | Claude Code / Codex CLI | コーディングエージェント |
| | hunk | レビュー特化の差分ビューア（`nh` コマンド・hunk-review スキルから使用） |
| ユーティリティ | Raycast | ランチャーアプリ |
| | Karabiner-Elements | キー入力カスタマイズ（BT キーボード接続時に内蔵キーボードを無効化） |

## ディレクトリ構成

```
.
├── .zprofile              # ログインシェル設定
├── .zshrc                 # インタラクティブシェル設定
├── Brewfile               # Homebrew パッケージ
├── setup.sh               # セットアップスクリプト
├── setup-codex-skills.py  # Codex 個人スキルの単独検査・リンク設置
├── macos.sh               # macOS 設定用スクリプト
├── launchd/               # 常駐エージェント用 plist（~/Library/LaunchAgents/ にコピー）
│
├── .config/               # ~/.config/ にリンク
│   ├── ghostty/           # ターミナル設定
│   ├── git/               # Git グローバル gitignore
│   ├── herdr/             # エージェントマルチプレクサ設定
│   │                       # （agent-taborder-watch.py: Agents サイドバーをタブ順に追従、
│   │                       #  ログは ~/.config/herdr/agent-taborder.log）
│   ├── karabiner/         # Karabiner-Elements 設定（karabiner.json のみ）
│   ├── lazygit/           # Git TUI 設定
│   ├── mise/              # ランタイム管理設定
│   ├── nvim/              # Neovim 設定
│   ├── raycast/           # Raycast スクリプト
│   ├── starship.toml      # プロンプト設定
│   └── uv/                # Python パッケージ管理設定
│
├── .claude/               # ~/.claude/ にリンク（ユーザーレベル設定）
│   ├── CLAUDE.md          # カスタム指示
│   ├── settings.json      # 設定
│   └── skills/            # カスタムスキル
│
└── .codex/                # Codex CLI のdotfiles管理対象
    ├── themes/            # ~/.codex/themes/ にファイル単位でリンク
    ├── skills/            # Claude 個人スキルを実行時参照する Codex 互換入口
    ├── compatibility.md   # 共通の読み替え規約
    ├── skill-bridge.json  # 個人42件の対応分類・正本ハッシュ
    ├── scripts/           # Codex 生ログ抽出・config.toml 更新・output style 同期
    ├── rules/             # execpolicy ルール（Claude Code の permissions 相当）
    └── hook-fragments/    # claude-parity.json: 既存設定へ追加する3フック定義
```

詳細は各ディレクトリの README を参照。

## セットアップ

### 前提条件

- macOS（Intel / Apple Silicon 両対応）
- zsh（macOS デフォルト）
- Git
- Xcode Command Line Tools

### インストール

```bash
git clone https://github.com/imutaroh/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh
source ~/.zshrc  # またはターミナル再起動
```

> [!WARNING]
> - 既存の設定ファイル（.zshrc, .zprofile, .config/nvim 等）は上書きされる。必要に応じて事前にバックアップを取ること
> - Homebrew のインストール時に sudo パスワードを求められる場合がある

### setup.sh の内容

1. Homebrew をインストール（未インストールの場合）
2. Brewfile のパッケージをインストール
3. mise で Python をインストール
4. uv をインストール
5. uv-tools.txt に記載されたツールをインストール
6. Claude Code をインストール（未インストールの場合）
7. Google Cloud SDK をインストール（未インストールの場合）
8. シンボリックリンクを作成
9. `launchd/*.plist` を `~/Library/LaunchAgents/` にコピーし、常駐エージェントとしてロード

## Codex CLI カスタマイズ

`setup.sh` は `~/.codex/config.toml` 全体を置き換えず、`.codex/scripts/apply-codex-config.py --apply` がキー単位で冪等に追記・置換する（Codexアプリが管理するモデル・権限・Hooksなどの既存設定や `[tui]` の他キーは保持される）。

- テーマ: `Imutaro Cool`（Claude Codeと共通のシアン・ブルー・ティール・バイオレット・スレートを使用。既存値があれば変更しない）
- ステータスライン（色付き・1行）: 左から モデルと推論レベル、Gitブランチ、変更ありマーカー、コンテキスト残量、5時間枠、週間枠、推定コスト、ディレクトリ（狭いペインでは右から欠けるので重要順）
- herdr サイドバーのスレッド名表示用に `terminal_title` も設定する
- 手動変更: Codex CLIの `/theme` と `/statusline`（TUI で変えた値は次の `setup.sh` で dotfiles 側の定数に戻るため、残したい変更は `apply-codex-config.py` に反映する）
- 利用枠のリセット日時: `/status` で確認（ステータスラインは残量のみ）
- 複数行 HUD: Claude Code と同じ5行構成（セッション名 / モデル·effort / ctx バー / 5h / 7d）を herdr の隣ペインに出す `codex-hud`（`.codex/scripts/codex-hud.sh`。Codex 本体の footer には自作出力を描けないため別プロセス）
- 一括点検: `bash ~/dotfiles/.codex/scripts/check-parity.sh`（リンク・config キー・識別子の実在・フック trust・スキル・注入確認。運用の指針は [.codex/README.md](.codex/README.md) の「運用ベストプラクティス」）

権限は `.codex/rules/claude-parity.rules`（execpolicy の prefix_rule。Claude Code の `.claude/settings.json` permissions 相当）を `setup.sh` がリンクする。output style は `.codex/scripts/sync-output-style.py` が `developer_instructions` として永続反映する。詳細な対応表とCLI例は [.codex/README.md](.codex/README.md) の「Claude Code との体験の対応」を参照。

個人スキルの Codex 対応は `setup.sh` とは独立して導入する。全セットアップの再実行は不要。

```bash
python3 ~/dotfiles/setup-codex-skills.py --check
python3 ~/dotfiles/setup-codex-skills.py --apply
```

`~/.agents/skills/` に38件のリンクを設置し、Claude 側の本文正本を実行時に参照する。既存スキル利用3件・未移植1件を含む対応範囲、更新検査、巻戻しは [.codex/README.md](.codex/README.md) を参照。フックは `.codex/hook-fragments/claude-parity.json` を既存 `~/.codex/hooks.json` にイベント単位で統合し、Codex の `/hooks` で本人が3件の定義を確認・trust して初めて実行される。既存ファイル全体を fragment で上書きしない。

## カスタムコマンド

`.zshrc` で定義しているシェル関数。

| コマンド | 説明 |
|----------|------|
| `desk [dir]` | herdr に開発用 Space を一発構築（タブ1「cchunk」: Claude Code + hunk diff --watch の50%分割、タブ2「nvim」） |
| `nh [c\|p\|args]` | Hunk（差分ビューア）を自動リロード付きで起動。`nh` で main 分岐点から、`nh c` でコミット後の編集、`nh p` で push 後の差分 |

## macOS システム設定

`defaults` コマンドで macOS の設定を適用する。setup.sh とは独立しており、必要に応じて手動実行する。

### 使い方

```bash
~/dotfiles/macos.sh
```

> [!WARNING]
> - システムフォルダの英語表示に sudo パスワードが必要
> - 設定反映のため、実行後に再ログインまたは再起動を推奨

### macos.sh の内容

- **Dock**: 右側配置、自動非表示、アイコンサイズ、アニメーション速度
- **Finder**: 隠しファイル表示、拡張子表示、パスバー、ステータスバー、カラム表示、フォルダ優先
- **キーボード**: キーリピート速度（超速）、長押しでキーリピート
- **テキスト入力**: 自動大文字・スペル修正・スマート引用符などを無効化
- **トラックパッド**: タップでクリック、3本指ドラッグ、ナチュラルスクロール
- **マウス**: スクロール速度
- **Hot Corners**: 左下でスクリーンセーバー
- **メニューバー**: バッテリー%表示、Bluetooth表示
- **スクリーンショット**: ~/Pictures/Screenshots に保存
- **TextEdit**: デフォルトをプレーンテキストに
- **その他**: .DS_Store をネットワーク/USB に作成しない、フォルダ名を英語表示

## Vim 学習メモ

### モード

Vim には「モード」という概念がある。普通のエディタと違い、キー入力の意味がモードによって変わる。

| モード | 役割 | 入り方 |
|--------|------|--------|
| **Normal** | 移動・操作 | `Esc` |
| **Insert** | 文字を入力する | `i` |
| **Visual** | 範囲選択 | `v` |

Vim を開いた瞬間は **Normal モード**。文字を打つには `i` → Insert モードに入ってから入力。打ち終わったら `Esc` で Normal モードに戻る。

### 基本移動

Normal モードでの移動。ホームポジションから手を動かさなくていいのが強み。

| キー | 動作 |
|------|------|
| `h` | 左 |
| `j` | 下 |
| `k` | 上 |
| `l` | 右 |
| `w` | 次の単語の先頭へ |
| `b` | 前の単語の先頭へ |
| `0` | 行の先頭へ |
| `$` | 行の末尾へ |
| `gg` | ファイルの先頭へ |
| `G` | ファイルの末尾へ |

### 編集操作

編集コマンドは **動詞 + 名詞** の組み合わせ。

| キー | 動作 |
|------|------|
| `x` | カーソルの文字を削除 |
| `dd` | 行を丸ごと削除（切り取り） |
| `yy` | 行を丸ごとコピー |
| `p` | 貼り付け（カーソルの後） |
| `u` | アンドゥ |
| `Ctrl r` | リドゥ |

動詞（`d` 削除 / `y` コピー / `c` 変更）と移動を組み合わせる：

| キー | 動作 |
|------|------|
| `dw` | 次の単語を削除 |
| `d$` | 行末まで削除 |
| `cw` | 次の単語を変更（Insert モードへ） |

---

## 手動インストールアプリ

Homebrew で管理できないアプリ。

| アプリ | 入手先 | 説明 |
|--------|--------|------|
| RunCat | [App Store](https://apps.apple.com/jp/app/runcat/id1429033973) | メニューバーでCPU使用率を表示 |
