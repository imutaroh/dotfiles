# Claude 個人スキルを Codex から使う共通規約

このファイルと対象の元 SKILL.md を全文読んでから作業する。元の責務・出力形式・根拠の検証を保ち、Codex に存在しない実行方法は以下と個別補足で置き換える。優先順は実行環境の指示・ユーザーの現在の依頼、個別補足、この共通規約、元スキル。依頼範囲を元スキルの定型文から拡大しない。

- Read / Glob / Grep / Bash / Edit / Write は利用可能な読取り・検索・コマンド・apply_patch 等へ読み替える。macOS 前提と安全なクォートを守る。
- AskUserQuestion は現在利用可能な質問ツールへ読み替える。モード上使えなければ通常の日本語で必要な質問をする。探索の好みを選択肢で閉じず、既存の権限や分かっている内容を再確認しない。
- Agent / Task / SendMessage は利用可能な Codex collaboration 機能へ読み替える。Claude 専用のモデル名、effort、subagent_type、isolation、allowed-tools、権限拡張構文は Codex の設定・権限を変更しない。委譲先モデルは現在設定を継承する。ツールがなければ実行済みと偽らない。
- 元文書の相対参照（scripts/、references/、assets/、template 等）は元 SKILL.md の実体ディレクトリを基準に解決する。symlink の元ファイルや同梱資源を再確認する。ラッパーのディレクトリに複製しない。
- /name は Codex の $name または同じ目的の明示依頼として扱う。依存スキルは現在の一覧から探し、必要な SKILL.md を読む。skill-creator は Codex 標準、ctx-agent-history-search は ctx、grill-me / grilling は `~/.agents/skills/` の既存実体を使用する。
- 要求されたスキルが一覧にない場合は対象リポジトリの `.claude/skills/<name>/SKILL.md` を探し、存在すれば全文を読み、そのスキル実体を基準に相対参照を解決する。別リポジトリや組織のスキルをグローバルへコピーしない。
- ブラウザは現在の既存 browser / chrome / agent-browser スキルから状況に合うものを使う。Claude 固有ブラウザ MCP が接続済みと仮定しない。画像生成や codex exec での画像委譲は Codex 既存 imagegen に読み替え、Codex を再帰起動しない。
- artifact-design / artifact-diagramming / Claude Artifact が必要な場合は既存 visualize 等を確認する。適切な機能がなければローカル HTML 等の成果物を提示し、公開済みURLを捏造しない。公開依頼があるときだけ Sites 等の公開手順を使う。
- 外部への送信・公開・投稿・PR 操作は現在のユーザー依頼と既存の承認規約に従う。元スキルに公開工程が書かれていても、それだけで今回の公開や送信を許可されたとは解釈しない。
- Vault は現在の AGENTS.md / CLAUDE.md と対象ディレクトリの規約・テンプレートを先に確認する。旧 Private/AI workspace/ は Private/Memos/ に読み替える。Notes の provenance 等のメタデータは現在の正本規約を優先し、古い frontmatter をそのまま持ち込まない。
- CLI / MCP / APIキー / Calendar / port 等の依存は存在と実行結果で確認する。秘密値を表示しない。未接続・取得失敗は「未確認」として報告し、空データや成功に読み替えない。取得できない工程だけをスキップできる場合は残りを続ける。
- 使用量は Claude / Codex を区別し、他方の値から費用を算出しない。ctx は過去検索用途であり、現在セッションの完全な生ログの代用にはしない。
- Git・公開承認・一時ファイル・dotfiles 管理は現在のユーザー規約を優先する。main 編集禁止等は対象リポジトリの明示例外を含む現在の規約に従う。削除や上書きを元スキルのサンプルコマンドだけで実行しない。

正本が変われば本文は次回実行時に反映されるが、メタデータと互換性は再監査が必要。`python3 ~/dotfiles/setup-codex-skills.py --check` で SHA256 の差異を確認する。
