# Codex 個人スキルブリッジ

Claude 側の個人スキル10件（2026-09-16 の棚卸しで45件から削減）を分類し、6件を Codex の同名スキルとして使うための入口を用意しています。本文は複製せず、実行時に `.claude/skills/<name>/SKILL.md` を読みます。Codex に合わせた差異は `compatibility.md` と各ラッパーに置きます。

## 導入と検査

```bash
python3 ~/dotfiles/setup-codex-skills.py --check
python3 ~/dotfiles/setup-codex-skills.py --apply
python3 ~/dotfiles/setup-codex-skills.py --check
```

既定は検査だけです。`--apply` は全件の事前検査を通した後に `~/.agents/skills/<name>` から dotfiles のラッパーへのシンボリックリンクだけを作ります。既存の別リンク・実ディレクトリ・壊れたリンクは上書きせず停止します。`--target-dir <path>` で検証用の別ディレクトリを指定できます。既存の正しいリンクへの再適用は変更なしになります。

CHECK OK でも「未設置」があればまだ導入前です。SOURCE_DRIFT は元スキル更新を検出した意味です。実行時には更新後の本文が読まれますが、description と固有互換処理を再確認し、監査後に `skill-bridge.json` の SHA256 を更新します。自動で hash を追認しません。

導入済みスキルは新しい Codex セッションで一覧を更新して確認してください。既存セッションに即座に再読込されるとは保証しません。`$zukai`、`$dot-help` 等で明示できます。

## 対応範囲と制限

- 4件: dot-help / find-skills / herdr-control / hunk-review は共通規約を介して元スキルを参照。
- 2件: output-style / zukai は実行方法を Codex 向けに補正。
- 4件: skill-creator は Codex 標準、ctx-agent-history-search は既存 ctx、grill-me / grilling は `npx skills add` が `~/.agents/skills/` に置いた実体をそのまま使用。重複配置しません。

スキルの入口があることと、MCP 接続・APIキー・実サービス操作が成功することは別です。Calendar 等は未接続なら未確認と報告します。既存スキルの導入状態と各業務フローの実運用はこのスクリプトだけでは検証しません。画像は既存 imagegen、図解は既存 visualize 等を優先します。Codex から codex exec を再帰起動しません。output-style は `~/.codex/config.toml` の `developer_instructions` として永続反映されます（Claude の output style と異なり会話限定ではない。詳細は次節）。元スキルや `~/.agents/skills/` の実体が移動すると参照が壊れます。

対象リポジトリにある commit / push / golang-pro 等は、そのリポジトリの `.claude/skills/` を探して実行時に読みます。個人スキルとして勝手にコピーしません。manifest は個人10件の対応表であり、全リポジトリの全スキル一覧ではありません。

## Claude Code との体験の対応（config.toml / rules / herdr）

2026-09-07 に、Claude Code の日常体験（指示書・output style・ステータスライン・herdr 連携・権限）を Codex 側でも同等に再現する設定を追加した。`~/.codex/config.toml` は Codex アプリ自身も書き換えるため symlink できず、以下のスクリプトがキー単位で冪等に追記・置換する。

| Claude 側の機能 | Codex 側の設定・ファイル | 反映方法 |
| --- | --- | --- |
| リポジトリの指示書読み込み（`.claude/CLAUDE.md` フォールバック） | `project_doc_fallback_filenames = ["CLAUDE.md", ".claude/CLAUDE.md"]`（トップレベルキー） | `apply-codex-config.py --apply`（`setup.sh` から自動実行） |
| output style（`~/.claude/output-styles/*.md`） | `developer_instructions`（トップレベルキー。Codex がモデル入力に注入する指示文字列） | `sync-output-style.py <名前>` / `default` / `--show`（永続反映。会話単位ではない点が Claude と異なる） |
| ステータスライン（`.claude/statusline.sh`） | `[tui].status_line`（識別子リスト）+ `status_line_use_colors = true` | `apply-codex-config.py --apply`。Claude の5行を1行に畳むため「上の行ほど重要」の順で左から並べる: モデル·effort → ブランチ → dirty マーカー（`branch-changes`）→ ctx 残量 → 5h → 7d → 推定コスト → ディレクトリ。セッション名は `terminal_title`（herdr サイドバー）に出すので入れない。Claude 側にあって Codex 側に無い項目: 経過時間・リセットまでの残り時間（Codex は `/status` で確認） |
| ステータスラインの複数行・バー表示（Claude の 5 行構成） | `.codex/scripts/codex-hud.sh`（別プロセス。`~/.codex/state_5.sqlite` の threads と rollout jsonl の `token_count` を読み、statusline.sh と同じ配色・バーで描く） | herdr で Codex のペインを上下分割し、下で `codex-hud`（`.zshrc` の alias）。Codex 本体は自作コマンドの出力を status_line に描けない（openai/codex#17827）ための回避策。コスト（$）は出せず累計トークンで代替。5h/7d はアカウント全体の値なので最近の rollout 5 本から `primary` 非 null の最新を拾い、リセット時刻を過ぎていれば「reset済」と出す |
| herdr サイドバーのスレッド名表示 | `[tui].terminal_title = ["thread-title"]`（OSC タイトルにスレッド名を出す）＋ `.config/herdr/config.toml` の `[ui.sidebar.agents.rows_by_agent].codex` | `apply-codex-config.py --apply` と herdr 側の設定（dotfiles にコミット済み、symlink で反映） |
| 権限（`.claude/settings.json` の permissions allow/deny） | `~/.codex/rules/claude-parity.rules`（execpolicy の prefix_rule） | `setup.sh` が `ln -sf` でリンク。既存 `~/.codex/rules/default.rules`（Codex の承認記憶）とは役割分担しており、そのファイルは触らない。より長い prefix のルールが優先されるため、`git push --force` の forbidden は `git push` の allow より優先される |
| フック（迎合防止・確認音・完了音） | `~/.codex/hooks.json` + `hook-fragments/claude-parity.json` | 「## 共通フックの導入と trust」節を参照 |
| ステータスを Codex のタブの中に出す（Codex 専用） | `hook-fragments/codex-hud.json` → UserPromptSubmit で `scripts/codex-hud-hook.sh` が `codex-hud.sh --once` の 5 行を `systemMessage` として返す | 送信のたびに会話欄へ 1 ブロック表示される（Codex は systemMessage を警告スタイルで UI に描く。固定表示ではなく上へ流れる。色は付かない）。`additionalContext` は返さないのでモデルのトークンは消費しない。同じく `/hooks` で trust が必要 |

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

# 複数行 HUD（Codex の隣のペインで動かす。--once は動作確認用）
bash ~/dotfiles/.codex/scripts/codex-hud.sh --once
bash ~/dotfiles/.codex/scripts/codex-hud.sh --cwd ~/repos/imutaakihiro/ObsidianImus   # 別ディレクトリのセッションを見る

# 同等体験がまるごと効いているかの一括点検（読み取り専用。NG があれば exit 1）
bash ~/dotfiles/.codex/scripts/check-parity.sh          # 7項目すべて（末尾の注入確認に数十秒かかる）
bash ~/dotfiles/.codex/scripts/check-parity.sh --quick  # 注入確認を省略
```

### 運用ベストプラクティス（2026-09-08 整理）

原則は「**正本は dotfiles、実環境はスクリプトで再生成、崩れたら検査で気づく**」。手で `~/.codex/config.toml` を直したら、その差分を dotfiles 側（`apply-codex-config.py` の定数か README）に必ず戻す。

1. **codex は1系統だけ持つ。** `brew cask` と `npm -g` の両方に入っていると PATH の先頭だけが更新され、古い版が `status_line` の識別子を知らずに「Ignored invalid status line」で黙って既定に戻る。2026-09-08 時点は npm（mise の node 配下）が PATH 先頭で、brew cask は版を合わせて残してある。片方に寄せるなら Brewfile の `cask "codex"` の扱いも一緒に決める。
2. **Codex を更新したら `check-parity.sh` を回す。** 識別子・キー名は版ごとに増減する（0.146 → 0.153 で `thread-credits` / `estimated-thread-cost` が増えた）。点検 [4] がバイナリの文字列で実在を確認する。
3. **status_line は「左が最重要」で8個まで。** footer は1行で、herdr の分割ペインでは右側から欠ける。項目を足すときは Claude の `statusline.sh` で何行目に出していたかを基準に順序を決め、`/statusline` で見た目を確認してから `apply-codex-config.py` の定数に反映する（TUI で変えただけだと次の `setup.sh` で戻される）。
4. **フックは trust を自作しない。** `hooks.json` に定義を足しても、Codex TUI の `/hooks` で本人が確認・trust するまで走らない。点検 [5] が「定義 N 件 / trust 済み M 件」を出すので、M < N なら `/hooks` を開く。`trusted_hash` を手で書いてはいけない（改ざん検知の仕組みを自分で無効化することになる）。
5. **output style は永続設定だと理解して切り替える。** Claude の `/output-style` は会話ごとだが、Codex の `developer_instructions` は全セッション共通。実験的なスタイルを試すなら `sync-output-style.py <名前> --dry-run` で確認し、終わったら `default` で戻す。注入されているかは点検 [7]（`codex debug prompt-input`）で見える。
6. **権限は execpolicy に寄せ、`default.rules` は触らない。** Claude の allow/deny を `claude-parity.rules` に写し、Codex が承認記憶として自動生成する `default.rules` と混ぜない。新しい禁止コマンドを足したら `codex execpolicy check` で forbidden になることを確認する。
7. **スキル正本が変わったら SHA を追認する。** `setup-codex-skills.py --check` の SOURCE_DRIFT は「本文は新しいものが読まれるが、description と互換補足は再監査していない」の意味。監査してから `skill-bridge.json` の SHA256 を更新する。

8. **複数行 HUD は「Codex が書いた直後の値」しか知らない。** `codex-hud.sh` は Codex が rollout に書く `token_count` を読むだけなので、ターンの途中は更新されず、5h 枠のリセット時刻を過ぎると次のターンまで「reset済」表示になる。Codex 内部の sqlite カラム名や jsonl のイベント名が変わると「データなし」になる。壊れたら `--once` で素の出力を見てから直す。

再現できないもの（諦めているもの）: Codex 本体の footer での複数行表示（HUD は別ペイン）、セッションの USD コスト、会話単位の output style 切り替え。

いずれのスクリプトも一時ファイル→ `os.replace` と `tomllib` による前後の構文検証を行うため、途中で失敗しても `config.toml` を壊れた状態のまま書き込むことはない。

## Codex セッションログの抽出

```bash
python3 ~/dotfiles/.codex/scripts/extract-session.py --session-id <現在のID> --source <Codexログ.jsonl> --output <プロジェクト>/.claude/tmp/session-<ID>.md
```

ID と session_meta を照合し、可視会話・ツール入出力を元行番号付きで抽出します。最新ファイルの自動選択、内部推論の抽出、既存出力の上書きはしません。不明形式と省略件数を出力に明示し、最終行の書込み途中は警告、中間行の破損はエラーにします。新規ディレクトリは0700、出力は0600。既存親の権限は変更しません。添付本文を含まないため、画像だけの証拠は原本と画像を別途確認する必要があります。生ログと抽出結果は外部公開しません。

元は `/close`（セッション振り返りスキル、2026-09-16 に削除）の証拠抽出用だったが、`setup-codex-skills.py` が共通依存として検査するため単体ツールとして残している。

## 共通フックの導入と trust

`hook-fragments/claude-parity.json` は UserPromptSubmit（迎合防止）、PermissionRequest（確認音）、Stop（完了音）の3定義、`hook-fragments/codex-hud.json` は UserPromptSubmit（ステータス表示）の1定義です。2026-09-07〜09 の導入作業では実環境の `~/.codex/hooks.json` へイベント単位で追加し、既存の herdr 用 SessionStart を保持しました。4件は Codex の `/hooks` でユーザー本人が定義を確認して trust するまで未実行です。信頼情報の `trusted_hash` を自作したり、確認を回避したりしません。

初回導入を別環境で再現するときは、既存 `hooks.json` を読み、既存のイベント・グループを保持したまま fragment の3イベントを手動で統合します。同じイベント内で同じ command が既にある場合は重複追加せず、timeout 等を含む定義を照合してください。fragment を既存 `hooks.json` 全体に上書きしてはいけません。`setup-codex-skills.py` はフックの統合も trust も行いません。

再移行時も `/hooks` で実際の3件の command・timeout 等が意図した定義と一致することを確認します。定義変更後は以前の trust がそのまま有効とは仮定せず、Codex が示す確認を行ってください。

## 巻戻し

解除したい `~/.agents/skills/<name>` に対し、`readlink` でリンク先がこの dotfiles の `.codex/skills/<name>` であると確認してから、そのリンク1件だけを `unlink` します。リンク先の本文やディレクトリを削除する必要はありません。別のリンク・実ディレクトリ・他者のスキルを一括削除しないでください。
