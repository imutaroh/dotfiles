# .config

各種アプリケーションの設定ファイル。`setup.sh` が `~/.config/` へシンボリックリンクを張る。セットアップ方法は[トップの README](../README.md) を参照。

## ディレクトリ構成

```
.config/
├── herdr-app/         # Herdr デスクトップアプリ（普段の環境）
├── herdr/             # Herdr ターミナル版（以前の環境）
├── ghostty/           # ターミナルエミュレータ（以前の環境）
├── nvim/              # エディタ（詳細は nvim/README.md）
├── starship.toml      # シェルプロンプト
├── git/               # グローバル gitignore
├── gh-dash/           # GitHub の PR / Issue ダッシュボード
├── hunk/              # 差分ビューア
├── plannotator-tui/   # Herdr ターミナル版のレビュー画面
├── yazi/              # ターミナルのファイラー
├── karabiner/         # キー入力のカスタマイズ
├── mise/              # ランタイムのバージョン管理
└── uv/                # Python パッケージ管理
```

## [Herdr](https://herdr.dev)

エージェント向けのターミナル環境。普段はデスクトップアプリだけを使う。

### Herdr デスクトップアプリ

`herdr-app/` で管理する。Cmd キーは `keys.json` でコマンドに直接割り当てる。Ghostty の Cmd → プレフィックス変換は通らない。

| ファイル | 説明 |
|----------|------|
| `keys.json` / `settings.json` | キー割り当てと設定 |
| `layouts/mine.json` | 付属レイアウト `main` の複製。自作 mod を組み込む |

**`setup.sh` のあと、Cmd+Shift+L でレイアウトを `mine` に切り替える。** 既定の `main` のままだと、`status-keys`、`changes-gh`、`files-img`、`tab-groups`、`agents-groups`、`pane-progress`、`progress-panel` は動かない。

`tab-autoname` は `mine` なら自動で動く。`main` でも動かすには、`main` を表示した状態で次を 1 回だけ実行する（もう一度実行すると止まる）。記録先の `windows.json` は追跡しないので、Mac ごとに必要になる。

```sh
herdr-app do mod.open '{"name":"tab-autoname"}'
```

自作 mod（`mods/` 以下）：

| mod | 説明 |
|-----|------|
| `redpen` | Cmd+U で Claude の最新の返答にコメントして送り返す |
| `tab-autoname` | Claude Code が端末タイトルに書く要約をタブ名に写す。手で付けた名前は上書きせず、空にすると自動に戻る |
| `tab-groups` | 付属 `tabs` の複製。Chrome のタブグループのようにタブをまとめて畳む。チップのクリックで畳み、右クリックで名前と色を変える。Cmd+O で表示中のタブを移す。畳むと `Cmd+数字` と `tab.next` から外れる。タブは固定幅で、名前の下の線がペインの数だけ区切られ、各ペインの状態の色になる |
| `agents-groups` | 付属 `agents` の複製。サイドバーの Agents 一覧を `tab-groups` のグループで区切る。見出しのクリックはタブバーのチップと同じく畳む。行の右クリックで別のグループへ移す。並びは右上のボタンで付属の Priority などへ戻せる |
| `pane-progress` | 付属 `pane` の複製。ペインの見出しに、エージェントのセッションのタイトルと、Claude Code のタスクの流れ（完了数、今の作業、残りの作業）を 1 行で出す。タスクが無いときは今の動作を出す |
| `progress-panel` | サイドバーに、フォーカス中のペインの Claude Code セッションのタスクを全件並べる。全体像はここで見る |
| `status-keys` | 付属 `workspace-status` の複製。右パネルの Files / Changes を Cmd+Shift+E / Cmd+Shift+G で開閉する。開いている間はターミナルを隠して全幅で見せる |
| `changes-gh` | 付属 `changes` の複製。差分を GitHub の配色にして長い行を折り返す |
| `files-img` | 付属 `files` の複製。画像ファイルを画像として表示する |

`redpen` は会話ログの場所を端末のラベルから読む。ラベルは SessionStart フック（`.claude/scripts/hc-label-claude-session.sh`）が入れる。`setup.sh` は `~/.claude/settings.json` が既にあるとコピーしないので、そのときはこのフックを手で登録する。`jq` と `python3` も要る。

`.zprofile` は、Herdr の端末に漏れた Claude Code と旧 herdr の環境変数を消す。Claude Code の中から Herdr を起動すると変数が全端末に漏れ、その端末で動かす Claude Code が会話ログを保存しなくなるため。

### Herdr ターミナル版

以前の環境。`herdr/` に設定を残している。

| ファイル | 説明 |
|----------|------|
| `config.toml` | キーバインドなどの設定 |
| `agent-taborder-watch.py` | タブ名に位置番号を付ける常駐スクリプト（`setup.sh` は登録しない。使うときは `launchd/optional/` の plist の `__HOME__` を置き換えて登録する） |
| `annotate-refresh.sh` | エージェントの最新の返答をレビュー画面（herdr-annotate）で開く。Cmd+U / Cmd+Shift+U の呼び出し口 |
| `sidechat.sh` | 表示中の Claude の会話を fork してポップアップで開く（Cmd+;） |
| `scripts/slot-machine.sh` | エージェントの作業が終わった瞬間にサイドバーへスロット風の演出を流す。`setup.sh` は配置しないので手で起動する。bash 4 以上が必要で、表示するには `config.toml` のサイドバー定義に `$slot` トークンを足す（標準の設定には入っていない） |

レビュー画面は `herdr integration install claude`（`setup.sh` が実行する）で入るセッション情報を使って、対象の Claude を特定する。

## [Ghostty](https://ghostty.org/)

以前の環境で使っていたターミナルエミュレータ。`config` に設定を残している。

| カテゴリ | 設定内容 |
|----------|----------|
| テーマ | GitHub Dark（文字色だけコントラストを上げている） |
| フォント | Moralerspace Argon（14pt、行間 +2px） |
| 背景 | 不透明度 0.9、ぼかし 30 |
| ウィンドウ | パディング 16px、タイトルバー透明 |
| キーバインド | Cmd 系のキーを Herdr ターミナル版のプレフィックス（Ctrl+Q）+ キーに変換して送る。左 Option は Alt として使う |

## [Neovim](https://neovim.io/)

[AstroNvim](https://astronvim.com/) をベースにカスタマイズしている。詳細は [nvim/README.md](nvim/README.md)、キー割り当ては [nvim/KEYMAPS.md](nvim/KEYMAPS.md) を参照。

## [Starship](https://starship.rs/)

シェルプロンプト。既定の設定をそのまま使っている。

## Git

`git/ignore` はグローバル gitignore で、Git が `~/.config/git/ignore` から自動で読む。機密情報（`.env`、`*.pem`、`*.key`、`credentials.json`、`service-account*.json`）の誤コミットを防ぎ、OS やエディタの生成ファイルを除外する。

## [gh-dash](https://github.com/dlvhdr/gh-dash)

GitHub の PR と Issue を一覧する TUI。`gh` の拡張機能で、Brewfile では管理できないので `setup.sh` が入れる。`gh dash` で起動する。

## [hunk](https://hunk.dev/)

ターミナルの差分ビューア。Claude Code とのペアレビューにも使う（エージェントが `hunk session` で表示位置の移動やコメント追加を行う）。`config.toml` で `wrap_lines = true` にして、長い行を折り返している。`.zshrc` の `nh` で、自動リロード付きで起動する。

## [yazi](https://yazi-rs.github.io/)

ターミナルのファイラー。`y` で起動し、終了時にその場所へ `cd` する（`.zshrc` で定義）。

## [Karabiner-Elements](https://karabiner-elements.pqrs.org/)

キー入力のカスタマイズ。Bluetooth キーボードの接続中は内蔵キーボードを無効にする。`karabiner.json` には Cmd 単体で英数とかなを切り替えるルールも入れている。

## [mise](https://mise.jdx.dev/)

グローバルに入れるランタイムのバージョンを管理する。Python 3.13 と Node.js の LTS。プロジェクト単位の Python は uv で管理する。

## [uv](https://docs.astral.sh/uv/)

Python のパッケージマネージャ。`python-preference = "only-managed"` で、システムの Python を使わず uv が管理する Python だけを使う。グローバルに入れる CLI ツールは `uv/uv-tools.txt` に書く。
