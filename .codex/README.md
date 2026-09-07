# Codex 個人スキルブリッジ

Claude 側の個人スキル42件を分類し、38件を Codex の同名スキルとして使うための入口を用意しています。本文は複製せず、実行時に `.claude/skills/<name>/SKILL.md` を読みます。Codex に合わせた差異は `compatibility.md` と各ラッパーに置きます。

## 導入と検査

```bash
python3 ~/dotfiles/setup-codex-skills.py --check
python3 ~/dotfiles/setup-codex-skills.py --apply
python3 ~/dotfiles/setup-codex-skills.py --check
```

既定は検査だけです。`--apply` は全件の事前検査を通した後に `~/.agents/skills/<name>` から dotfiles のラッパーへのシンボリックリンクだけを作ります。既存の別リンク・実ディレクトリ・壊れたリンクは上書きせず停止します。`--target-dir <path>` で検証用の別ディレクトリを指定できます。既存の正しいリンクへの再適用は変更なしになります。

CHECK OK でも「未設置」があればまだ導入前です。SOURCE_DRIFT は元スキル更新を検出した意味です。実行時には更新後の本文が読まれますが、description と固有互換処理を再確認し、監査後に `skill-bridge.json` の SHA256 を更新します。自動で hash を追認しません。

導入済みスキルは新しい Codex セッションで一覧を更新して確認してください。既存セッションに即座に再読込されるとは保証しません。`$morning`、`$tech`、`$close` 等で明示できます。

## 対応範囲と制限

- 31件: 共通規約を介して元スキルを参照（morning は追加補足あり）。
- 7件: close / daily-ai-log / delegate-implementation / image-generate / output-style / worktree-parallel / zukai の実行方法を Codex 向けに補正。
- 3件: skill-creator は Codex 標準、ctx-agent-history-search は既存 ctx、terminal-browser は既存同名スキルを使用。重複配置しません。
- 1件: task-dashboard は未移植。Claude Artifact 依存と Vault Todo.md との正本競合を解消せずに有効化しません。

スキルの入口があることと、MCP 接続・APIキー・実サービス操作が成功することは別です。Calendar 等は未接続なら未確認と報告します。既存スキルの導入状態と各業務フローの実運用はこのスクリプトだけでは検証しません。画像は既存 imagegen、図解は既存 visualize 等を優先します。Codex から codex exec を再帰起動しません。output-style は `~/.codex/config.toml` の `developer_instructions` として永続反映されます（Claude の output style と異なり会話限定ではない。詳細は次節）。元スキルや books の symlink 先が移動すると参照が壊れます。

対象リポジトリにある commit / push / golang-pro 等は、そのリポジトリの `.claude/skills/` を探して実行時に読みます。個人スキルとして勝手にコピーしません。manifest は個人42件の対応表であり、全リポジトリの全スキル一覧ではありません。

## Claude Code との体験の対応（config.toml / rules / herdr）

2026-09-07 に、Claude Code の日常体験（指示書・output style・ステータスライン・herdr 連携・権限）を Codex 側でも同等に再現する設定を追加した。`~/.codex/config.toml` は Codex アプリ自身も書き換えるため symlink できず、以下のスクリプトがキー単位で冪等に追記・置換する。

| Claude 側の機能 | Codex 側の設定・ファイル | 反映方法 |
| --- | --- | --- |
| リポジトリの指示書読み込み（`.claude/CLAUDE.md` フォールバック） | `project_doc_fallback_filenames = ["CLAUDE.md", ".claude/CLAUDE.md"]`（トップレベルキー） | `apply-codex-config.py --apply`（`setup.sh` から自動実行） |
| output style（`~/.claude/output-styles/*.md`） | `developer_instructions`（トップレベルキー。Codex がモデル入力に注入する指示文字列） | `sync-output-style.py <名前>` / `default` / `--show`（永続反映。会話単位ではない点が Claude と異なる） |
| ステータスライン（`.claude/statusline.sh`） | `[tui].status_line`（識別子リスト） | `apply-codex-config.py --apply`。Claude 側にあって Codex 側に無い項目: セッション名（`/rename` した名前）・git dirty マーカー・経過時間・5時間/週次リセットまでの残り時間の詳細表示（Codex は `five-hour-limit` / `weekly-limit` の集計値のみ） |
| herdr サイドバーのスレッド名表示 | `[tui].terminal_title = ["thread-title"]`（OSC タイトルにスレッド名を出す）＋ `.config/herdr/config.toml` の `[ui.sidebar.agents.rows_by_agent].codex` | `apply-codex-config.py --apply` と herdr 側の設定（dotfiles にコミット済み、symlink で反映） |
| 権限（`.claude/settings.json` の permissions allow/deny） | `~/.codex/rules/claude-parity.rules`（execpolicy の prefix_rule） | `setup.sh` が `ln -sf` でリンク。既存 `~/.codex/rules/default.rules`（Codex の承認記憶）とは役割分担しており、そのファイルは触らない。より長い prefix のルールが優先されるため、`git push --force` の forbidden は `git push` の allow より優先される |
| フック（迎合防止・確認音・完了音） | `~/.codex/hooks.json` + `hook-fragments/claude-parity.json` | 「## 共通フックの導入と trust」節を参照 |

### スクリプトの CLI 例

```bash
# config.toml のキー更新（project_doc_fallback_filenames / [tui] の status_line・terminal_title・theme）
python3 ~/dotfiles/.codex/scripts/apply-codex-config.py --check   # 差分があれば表示して exit 1
python3 ~/dotfiles/.codex/scripts/apply-codex-config.py --apply   # 変更を書き込む

# output style（developer_instructions）の切り替え
python3 ~/dotfiles/.codex/scripts/sync-output-style.py --show        # 現状 + 選べるスタイル一覧
python3 ~/dotfiles/.codex/scripts/sync-output-style.py 15sai         # 15sai.md を適用（永続化。反映は新しいセッションから）
python3 ~/dotfiles/.codex/scripts/sync-output-style.py default       # developer_instructions を削除

# 権限ルールの動作確認（--rules は複数指定可）
codex execpolicy check --pretty --rules ~/dotfiles/.codex/rules/claude-parity.rules -- git push --force origin main
```

いずれのスクリプトも一時ファイル→ `os.replace` と `tomllib` による前後の構文検証を行うため、途中で失敗しても `config.toml` を壊れた状態のまま書き込むことはない。

## close の証拠抽出

```bash
python3 ~/dotfiles/.codex/scripts/extract-session.py --session-id <現在のID> --source <Codexログ.jsonl> --output <プロジェクト>/.claude/tmp/close/session-<ID>.md
```

ID と session_meta を照合し、可視会話・ツール入出力を元行番号付きで抽出します。最新ファイルの自動選択、内部推論の抽出、既存出力の上書きはしません。不明形式と省略件数を出力に明示し、最終行の書込み途中は警告、中間行の破損はエラーにします。新規ディレクトリは0700、出力は0600。既存親の権限は変更しません。添付本文を含まないため、画像だけの証拠は原本と画像を別途確認する必要があります。生ログと抽出結果は外部公開しません。

この抽出だけでレビュー完了ではありません。close は別担当によるレビューと引用・話者・文脈の検証を経て報告します。台帳・プロンプト追記は元スキルの正本を共用し、Codex セッションと記録します。書込み権限が必要ならその工程は権限内で扱い、未反映を隠しません。

## 共通フックの導入と trust

`hook-fragments/claude-parity.json` は UserPromptSubmit（迎合防止）、PermissionRequest（確認音）、Stop（完了音）の3定義です。2026-09-07 の導入作業では実環境の `~/.codex/hooks.json` へイベント単位で追加し、既存の herdr 用 SessionStart を保持しました。3件は Codex の `/hooks` でユーザー本人が定義を確認して trust するまで未実行です。信頼情報の `trusted_hash` を自作したり、確認を回避したりしません。

初回導入を別環境で再現するときは、既存 `hooks.json` を読み、既存のイベント・グループを保持したまま fragment の3イベントを手動で統合します。同じイベント内で同じ command が既にある場合は重複追加せず、timeout 等を含む定義を照合してください。fragment を既存 `hooks.json` 全体に上書きしてはいけません。`setup-codex-skills.py` はフックの統合も trust も行いません。

再移行時も `/hooks` で実際の3件の command・timeout 等が意図した定義と一致することを確認します。定義変更後は以前の trust がそのまま有効とは仮定せず、Codex が示す確認を行ってください。

## 巻戻し

解除したい `~/.agents/skills/<name>` に対し、`readlink` でリンク先がこの dotfiles の `.codex/skills/<name>` であると確認してから、そのリンク1件だけを `unlink` します。リンク先の本文やディレクトリを削除する必要はありません。別のリンク・実ディレクトリ・他者のスキルを一括削除しないでください。
