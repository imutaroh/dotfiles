# dotfiles

[imutaroh](https://github.com/imutaroh) の macOS 開発環境の設定一式。Claude Code と Codex を中心に、ターミナル・Neovim・キーボードまでを 1 つのリポジトリで管理している。

> [!NOTE]
> 個人用の設定で、作者の環境を前提にしている。丸ごと動かすより、気になる部分を読んで持っていく使い方を勧める。

## 見どころ

- **Herdr デスクトップアプリの自作 mod**: Claude の返答に赤を入れて送り返す `redpen`、端末タイトルをタブ名に写す `tab-autoname` など 5 本（[一覧](.config/README.md#herdr-デスクトップアプリ)）
- **Claude Code と Codex の同等化**: 指示書・ステータスライン・権限・フック・スキルを両方で揃え、崩れたら 1 コマンドで点検できる（[.codex/README.md](.codex/README.md)）
- **Claude Code の設定**: 寒色で統一したテーマとステータスライン、確認音と完了音、手順ではなく「モデルが知り得ない事実」に絞ったスキル（[.claude/README.md](.claude/README.md)）
- **Neovim**: AstroNvim をベースにした設定と、そこから切り出した自作プラグイン [diffbase.nvim](https://github.com/imutaroh/diffbase.nvim)（いつもの編集画面を GitHub の PR 差分にする）/ [nudge.nvim](https://github.com/imutaroh/nudge.nvim)（コードへのコメントを AI エージェントに送る）（[.config/nvim/README.md](.config/nvim/README.md)）

## 使っているツール

| カテゴリ | ツール | 役割 |
|----------|--------|------|
| エージェント | Claude Code / Codex CLI | コーディングエージェント |
| ターミナル | [Herdr](https://herdr.dev) デスクトップアプリ | エージェント向けのターミナル環境。普段はこれだけを使う |
| エディタ | Neovim（[AstroNvim](https://astronvim.com/) ベース） | エディタ |
| シェル | zsh + [Starship](https://starship.rs/) | シェルとプロンプト |
| 開発ツール | [hunk](https://hunk.dev/) | レビュー用の差分ビューア |
| | [yazi](https://yazi-rs.github.io/) | ターミナルのファイラー |
| | [gh-dash](https://github.com/dlvhdr/gh-dash) | GitHub の PR / Issue を一覧する TUI |
| パッケージ管理 | Homebrew / [mise](https://mise.jdx.dev/) / [uv](https://docs.astral.sh/uv/) | アプリ / ランタイム / Python |
| 入力 | [Raycast](https://www.raycast.com/) / [Karabiner-Elements](https://karabiner-elements.pqrs.org/) | ランチャー / キー入力のカスタマイズ |

アプリの全量は [Brewfile](Brewfile) を参照。以前の環境である [Ghostty](https://ghostty.org/) と Herdr ターミナル版（`herdr`）の設定も残している。

## ディレクトリ構成

```
.
├── README.md
├── CLAUDE.md               # このリポジトリでの作業ルール（エージェント向け）
├── Brewfile                # Homebrew で入れるもの
├── setup.sh                # セットアップ
├── macos.sh                # macOS のシステム設定（手動実行）
├── setup-codex-skills.py   # Codex 用スキル入口の検査とリンク設置
├── sync-settings.sh        # Claude Code の settings.json を実環境から取り込む
├── .zshrc / .zprofile      # シェル
├── .gitconfig              # Git のグローバル設定
├── .config/                # ~/.config/ の中身（説明は .config/README.md）
├── .claude/                # Claude Code の設定（説明は .claude/README.md）
├── .codex/                 # Codex CLI の設定（説明は .codex/README.md）
├── bin/vid2text            # 動画の音声を文字起こしするスクリプト
├── iphone/apps.sh          # 残す iPhone アプリの宣言的な管理（一覧は非公開）
└── launchd/                # 常駐エージェントの plist
```

## セットアップ

前提は macOS、zsh、Git、Xcode Command Line Tools。Homebrew のパスは Apple Silicon と Intel の両方を判定する。

```bash
git clone https://github.com/imutaroh/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh
source ~/.zshrc  # またはターミナルを再起動
```

> [!WARNING]
> 他人の環境で実行するなら、先に [setup.sh](setup.sh) を読むこと。特に次の点に注意する。
>
> - 既存の設定を置き換える。`~/.zshrc` などは上書きし、`~/.config/nvim`、`~/.claude/skills`、`~/.claude/themes`、`~/.config/raycast/script-commands` が実ディレクトリなら削除してリンクを張る
> - `.gitconfig` の名前とメールアドレスは作者のもの。自分の値に書き換える
> - `launchd/` の plist には `/Users/imutaakihiro` が直接書かれており、`ai-usage-dashboard` は公開していないリポジトリを指す。使わないなら実行前に消す
> - Neovim の自作プラグインは `~/repos/imutaroh/` にあるローカルの複製を読む。[.config/nvim/README.md](.config/nvim/README.md) の前提条件を見ること

`setup.sh` がやること：

1. Homebrew と Brewfile のパッケージを入れる
2. mise で Python と Node.js、uv で CLI ツールと Playwright の Chromium を入れる
3. Claude Code、gh-dash、Google Cloud SDK を入れる（未導入の場合）
4. 設定ファイルのシンボリックリンクを張る
5. Herdr の Claude Code 連携を入れ、`~/.codex/config.toml` をキー単位で更新する
6. `launchd/*.plist` を `~/Library/LaunchAgents/` にコピーしてロードする

Codex 用スキルの入口は `setup.sh` とは別に入れる（[手順](.codex/README.md#導入と検査)）。

### 管理の方針

- 設定は基本的にシンボリックリンクで配置する。正本はこのリポジトリにある
- アプリが書き換えるファイルはリンクにしない。Claude Code の `settings.json` は `./sync-settings.sh` で実環境から取り込み、Codex の `config.toml` はキー単位で更新する

## カスタムコマンド

`.zshrc` で定義している。

| コマンド | 説明 |
|----------|------|
| `y [dir]` | yazi を起動し、終了時にその場所へ `cd` する |
| `nh [c\|p\|args]` | hunk を自動リロード付きで起動する。`nh` は main からの分岐点、`nh c` は前回のコミット、`nh p` は前回の push からの差分 |
| `desk [dir]` | ターミナル版 herdr に開発用の Space を作る（タブ 1: Claude Code と hunk、タブ 2: Neovim） |
| `codex-hud` | Codex の隣のペインに、Claude Code 風の複数行ステータスを出す |

## macOS のシステム設定

`macos.sh` が `defaults` コマンドで次の設定を適用する。`setup.sh` とは独立しており、必要なときに手で実行する。フォルダ名の英語表示に sudo が要り、反映には再ログインか再起動を勧める。

- **Dock**: 右側に配置、自動で隠す
- **Finder**: 隠しファイルと拡張子を表示、カラム表示、フォルダを先頭に
- **キーボード・入力**: キーリピートを高速化、自動大文字やスペル修正を無効化
- **トラックパッド**: タップでクリック、3 本指ドラッグ
- **その他**: スクリーンショットの保存先を `~/Pictures/Screenshots` に、ネットワークや USB に `.DS_Store` を作らない

## 手動で入れるアプリ

Homebrew で管理できないもの。

| アプリ | 入手先 | 説明 |
|--------|--------|------|
| RunCat | [App Store](https://apps.apple.com/jp/app/runcat/id1429033973) | メニューバーに CPU 使用率を表示 |
