---
name: daily-ai-log
description: ctx（エージェント履歴検索）からその日の Claude Code セッション一覧を抽出し、Obsidian 日報（Vault/03_Journals/YYYY-MM-DD.md）の「## AIログ」セクションに追記するスキル。「/daily-ai-log」「昨日のAIログを日報に」「AIログ埋めて」「昨日Claudeと何話したか日報にまとめて」で使用。日またぎセッション対応（イベント発生日基準）。
---

# 日報AIログ生成（daily-ai-log）

## 前提

- **対象日のデフォルトは昨日**（朝に前日分を埋める運用）。「今日の分」「7/15の分」等の指定があればその日付
- **書き込み先**: `/Users/imutaakihiro/repos/imutaakihiro/ObsidianImus/Vault/03_Journals/YYYY-MM-DD.md` の `## AIログ` セクション
- これは **Vault 書き込み禁止の例外**（日報朝テンプレ特例と同枠。CLAUDE.md 日報フォーマットに明文化済み 2026-07-17）。**この Skill が書いてよいのは対象日ノートの `## AIログ` セクションだけ**。他のセクション・他のノートには触れない
- `ctx` CLI（`~/.local/bin/ctx`）が必要。無ければ「ctx が無いので生成できない」と正直に報告して終了（結果を捏造しない）

## ワークフロー

### 1. 対象日の確定

```bash
date -v-1d +%F   # 昨日（デフォルト）
date +%F         # 「今日の分」と言われたとき
```

### 2. 事前チェック（3つ、順に）

1. **日報ファイルの存在**: `Vault/03_Journals/YYYY-MM-DD.md` が無ければ**作らない**。「日報ファイルが無いのでスキップした」と報告して終了
2. **重複**: ファイル内に既に `## AIログ` があり中身が埋まっていれば、**上書きせず**その旨を報告（ユーザーが「作り直して」と言ったときだけ既存セクションを置換）
3. **ctx の健全性**: `ctx status` が失敗したら報告して終了

### 3. セッション抽出（イベント発生日基準・日またぎ対応）

セッションの**開始日ではなく、その日にユーザー発言があったか**で拾う。前日から続いているセッションは `(継続)` マークが付く。`{DATE}` を対象日に置換して実行:

```bash
ctx sql "SELECT time(MIN(e.occurred_at_ms)/1000,'unixepoch','localtime') AS first_msg, COUNT(*) AS msgs, CASE WHEN date(s.started_at_ms/1000,'unixepoch','localtime') < '{DATE}' THEN '(継続)' ELSE '' END AS cont, substr(replace(json_extract((SELECT e2.payload_json FROM ctx_events e2 WHERE e2.ctx_session_id=s.ctx_session_id AND e2.role='user' AND e2.event_type='message' AND date(e2.occurred_at_ms/1000,'unixepoch','localtime')='{DATE}' ORDER BY e2.occurred_at_ms LIMIT 1),'\$.body.content_preview.text'),char(10),' '),1,80) AS topic, s.ctx_session_id FROM ctx_events e JOIN ctx_sessions s ON s.ctx_session_id=e.ctx_session_id WHERE date(e.occurred_at_ms/1000,'unixepoch','localtime')='{DATE}' AND e.role='user' AND e.event_type='message' AND s.is_primary=1 AND s.provider='claude' GROUP BY s.ctx_session_id ORDER BY first_msg" --max-rows 60 --timeout 60s
```

- ポイント: `'localtime'` 修飾子を外さない（外すと UTC になり朝9時前が前日に化ける）
- `is_primary=1` でサブエージェントは除外（人間の会話だけ）

### 4. 整形ルール

`## AIログ` セクションとして以下の形式で組む:

```markdown
---

## AIログ

Claude Code セッション N本（ctx から自動抽出・その日の最初の発言ベース）

- HH:MM 話題の一行要約
- HH:MM ↩前日から継続。話題の一行要約
- （まとまる場合）HH:MM〜HH:MM 同一テーマの複数セッションは1行に束ねる
- ほか特殊入力等 M本
```

- topic のノイズ処理: `<command-message>xxx</command-message>` → `/xxx` と表記。`<local-command-caveat>` や NULL → 件数だけ「ほか特殊入力等 M本」に集約。`/compact` `/clear` 起点の継続セッションは topic が薄いので msgs 数を頼りに前後セッションと同テーマなら束ねる
- 話題はユーザー発言の**要約**にする（生ペーストで長々と引用しない。60字以内目安）
- `(継続)` は `↩前日から継続` として明記
- 追記位置はファイル**末尾**に `---` 区切りで（テンプレの空 `## AIログ` 枠が既にある日はその枠を埋める）

### 5. フェイルセーフ

- SQL がエラー・0件のとき: 日報には**何も書かず**、ユーザーに「取得失敗/0件」と理由を報告する（空セクションや推測で埋めない）
- topic 抽出が全行 NULL になったら ctx のペイロード構造が変わったサイン（下記「破綻条件」）。書き込まずに報告する

### 6. 完了報告

- 書き込んだ日付・セッション数・継続セッション数
- スキップ・失敗があればその理由

## 破綻条件（知っておく）

- **`$.body.content_preview.text` は ctx の内部実装詳細**（公式の安定ビュー保証は列まで、payload_json の中身は対象外）。ctx のバージョンアップで抽出が全 NULL になったら、`ctx sql "SELECT payload_json FROM ctx_events WHERE role='user' LIMIT 1"` で実物を見てパスを直す
- ctx はローカル専用。**クラウド実行（/schedule 等）ではこの Skill は動かない**。自動化するならローカル cron（CronCreate）
- 日報ファイル名・場所の規約が変わったら書き込み先を見直す

## 関連

- 決定の経緯: メモリ `project_ctx_daily_ai_log.md`（2026-07-17）
- ctx の運用リサーチ: `ObsidianImus/Company/Drafts/2026-07-17-ctx-research.md`
- 隣接 Skill: `daily-report-formatter`（日報本文の整形。AIログ枠を壊さないこと）
