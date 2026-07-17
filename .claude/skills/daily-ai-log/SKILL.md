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

セッションの**開始日ではなく、その日にユーザー発言があったか**で拾う。前日から続いているセッションは `C`（継続）マークが付く。各セッションについて「その日最初のユーザー発言（ask）」と「その日最後のアシスタント返答（result）」のペアを取る。`{DATE}` を対象日に置換して実行:

```bash
ctx sql "SELECT time(MIN(e.occurred_at_ms)/1000,'unixepoch','localtime') AS t, COUNT(*) AS msgs, CASE WHEN date(s.started_at_ms/1000,'unixepoch','localtime') < '{DATE}' THEN 'C' ELSE '' END AS cont, substr(replace(json_extract((SELECT e2.payload_json FROM ctx_events e2 WHERE e2.ctx_session_id=s.ctx_session_id AND e2.role='user' AND e2.event_type='message' AND date(e2.occurred_at_ms/1000,'unixepoch','localtime')='{DATE}' ORDER BY e2.occurred_at_ms LIMIT 1),'\$.body.content_preview.text'),char(10),' '),1,55) AS ask, substr(replace(coalesce((SELECT je.value->>'\$.text' FROM json_each(json_extract((SELECT e3.payload_json FROM ctx_events e3 WHERE e3.ctx_session_id=s.ctx_session_id AND e3.role='assistant' AND e3.event_type='message' AND date(e3.occurred_at_ms/1000,'unixepoch','localtime')='{DATE}' ORDER BY e3.occurred_at_ms DESC LIMIT 1),'\$.body.content_preview.json')) je WHERE je.value->>'\$.text' IS NOT NULL LIMIT 1),''),char(10),' '),1,90) AS result FROM ctx_events e JOIN ctx_sessions s ON s.ctx_session_id=e.ctx_session_id WHERE date(e.occurred_at_ms/1000,'unixepoch','localtime')='{DATE}' AND e.role='user' AND e.event_type='message' AND s.is_primary=1 AND s.provider='claude' GROUP BY s.ctx_session_id ORDER BY t" --max-rows 60 --timeout 60s
```

- ポイント: `'localtime'` 修飾子を外さない（外すと UTC になり朝9時前が前日に化ける）
- `is_primary=1` でサブエージェントは除外（人間の会話だけ）
- **user と assistant はペイロード構造が違う**: user は `$.body.content_preview.text`（文字列）、assistant は `$.body.content_preview.json`（ブロック配列の文字列。先頭が thinking のことがあるので `json_each` で最初の text ブロックを取る）

### 4. 整形ルール

`## AIログ` セクションとして以下の形式で組む:

```markdown
---

## AIログ

Claude Code セッション N本（ctx から自動抽出。依頼→その日の最終返答ベース、↩=前日からの継続）

- **HH:MM** 依頼の要約 → 結果・着地点の要約（N往復）
- **HH:MM** ↩ 前日からの継続。依頼の要約 → 結果の要約
- ほか特殊入力等 M本
```

- **「依頼 → 結果」の1行構成**が基本形。ask（何を頼んだか）と result（どう終わったか）を自分の言葉で要約して `→` でつなぐ
- セッション途中で話題が変わっているとき（ask と result が別の話）は「→ 最後は◯◯の話に発展」のように**そのまま正直に書く**（ドリフトも作業記録の一部）
- 往復数（msgs）が突出したセッションには「（**N往復**・この日最長）」を付けると密度が分かる
- ノイズ処理: `<command-message>xxx>` → `/xxx` と表記。`<local-command-caveat>` や NULL ask は result があれば result 側から要約し、両方空なら「ほか特殊入力等 M本」に集約
- 生ペーストの長い引用はしない（各要素 60〜90字目安に要約）。**秘密情報（キー・トークン・クライアント名等）が preview に混ざっていたら日報に書かずマスクする**
- `C` は `↩`（前日からの継続）として明記
- 追記位置はファイル**末尾**に `---` 区切りで（テンプレの空 `## AIログ` 枠が既にある日はその枠を埋める）
- 対象日が**今日**の場合は見出し行を「N本・HH時時点の途中経過」とする

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
