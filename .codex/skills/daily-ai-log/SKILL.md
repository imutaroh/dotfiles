---
name: daily-ai-log
description: "ctx のイベント検索から対象日の Claude Code・Codex セッションを集約し、Obsidian 日報の AIログを作る。日報へのAIログ追記や前日の会話まとめを依頼されたときに使用。"
---

# daily-ai-log — Codex ブリッジ

1. このファイルの実体パスから dotfiles ルートを求め、`.codex/compatibility.md` を全文読む（標準配置: `~/dotfiles/.codex/compatibility.md`）。
2. 同じ dotfiles 内の `.claude/skills/daily-ai-log/SKILL.md` を全文読む。元スキルの相対参照はその実体ディレクトリを基準にする。
3. 共通規約と以下の固有補足を優先して元スキルのワークフローを実行する。依存機能の未接続や未実施は明記する。

## Codex 固有補足

元スキルの `ctx sql` と `ctx import --partial` は実行しない。ctx 1.3.1 では提供されないため、抽出工程を以下に置き換える。元スキルの対象日既定（昨日）、日報の存在・重複チェック、書込み範囲、整形、秘密情報保護は維持する。

1. 現在の `ctx` スキルと `ctx docs show event-queries` を全文読み、`ctx status` を確認する。対象日と翌日は `date` で確認し、JST 00:00 の RFC3339（`YYYY-MM-DDT00:00:00+09:00`）を開始・終了にする。実行環境の既定タイムゾーンに頼らない。
2. 汎用の「AIログ」は Claude Code と Codex の両方を対象にし、ユーザーが片方を指定した場合はその provider だけを取得する。開始日と翌日を実値に置換して次を使う。

   ```bash
   ctx list events --provider claude --provider codex --scope primary --event-type message --since '<対象日>T00:00:00+09:00' --until '<翌日>T00:00:00+09:00' --content full --format jsonl
   ```

3. JSONL末尾の `event_range_completion` にある `terminal`・`truncated`・`next_cursor` を確認する。単に EOF になっただけでは取得成功としない。`terminal: false`・`truncated: true` なら、同じ条件に返された `next_cursor` を `--cursor` で渡し、公式仕様に従い全ページを取り切る。完了時は `terminal: true`・`truncated: false`・`next_cursor: null` を確認する。generation 切替等で cursor の再開に失敗した場合は1回だけ先頭から取り直し、イベントID等の実際の安定識別子で重複を除く。再試行も失敗したら未完全集計と説明して日報へ書き込まない。`completion.freshness.status: not_checked` の列挙結果は索引の最新性を検証していないため、全ページ取得と最新状態への更新を区別する。
4. `event.ctx_session_id` ごとに、対象日にユーザー発言がある primary セッションを集約する。その日の最初の user と最後の assistant を取り、`occurred_at_ms` から JST 時刻を計算する。`text` / `structured_content` の実物を確認し、元スキルの `body.content_preview` 固定パスに依存しない。provider 別にセッション件数と結果を表示する。assistant がまだなければ返答未確認とする。継続マークはセッション開始日時を確認して付ける。
5. `ctx show session <ctx_session_id>` の現在の対応オプションを確認して詳細を読む。元スキルの第三者要約を使う場合は共通互換規約に従い、モデルは Codex 設定を継承する。本文欠落・metadata のみ・範囲不足なら「簡易」または「未確認」と表示し、完全な生ログと呼ばない。部分カバレッジ警告を推測で埋めない。refresh/import が必要な場合は現在のヘルプとメンテナンス権限を確認し、古い `--partial` を再利用しない。
6. `ctx status` が search/refresh ready なら恒久故障と扱わない。取り込みスキップ警告がある場合はその場の件数を確認し、対象日の欠落可能性として報告する。2026-09-07 の `ctx import --all` 後は復旧済みで87レコードのスキップ警告が残ったが、この値を将来の取得結果に固定しない。
7. 日報の保護・メンテナンス許可は現在の Vault 規約と元スキルに従う。既存の埋まった AIログは作り直し依頼なしで置換せず、日報がなければ新規作成しない。0件・取得失敗・本文全欠落なら書き込まず理由を報告する。対象が今日なら途中経過と明記する。スキルの修正・検査だけを依頼された場合は実日報へ書き込まない。
