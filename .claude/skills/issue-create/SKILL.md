---
name: issue-create
description: GitHub リポジトリ `imutaroh/ObsidianImus` に Issue を起票し、Project "Life" #2 への追加・Quadrant/Area/Status/Milestone 設定までを1コマンドで完結させるスキル。「/issue-create」「Issue 起票」「Issue にして」「タスク追加」「アイデア登録」「これ Issue にして」で使用。type ラベル（task/idea/decision/review/antipattern）・Project フィールドを対話的に決定し、必要に応じて作業ディレクトリ `Company/issues/{N}-{slug}/` の雛形も作成する。
---

# issue-create

ご主人様の Vault リポジトリ `imutaroh/ObsidianImus` への Issue 起票を一気通貫で実行する。

## 前提（変えない部分）

- リポジトリ: `imutaroh/ObsidianImus`
- Project: "Life" #2（オーナー `imutaroh`）
- Milestone 既定値: 当該四半期（例：2026-05 なら `2026-Q2`）。`date +%m` から自動判定
- Status 既定値: `Todo`
- 1日に Issue 化するのは **5件まで**。超過時は警告して続行確認
- Issue #45 が Open の間は Auto-add ワークフローが未完了なので `gh project item-add` を**必ず明示実行**する

ID 一覧（Project ID / Field ID / Option ID）は [references/project_life_ids.md](references/project_life_ids.md) を参照。

## 入力収集（不足していたら必ず聞く）

ユーザー発話から拾えなかった項目は AskUserQuestion で確認。

| 項目 | 必須 | 既定値 |
|------|------|--------|
| タイトル | ✅ | — |
| 本文（背景・調べたいこと・成果物） | ⚠️ 推奨 | 空でも可だが補助質問で引き出す |
| `type:` ラベル | ✅ | `task`（迷ったら確認） |
| Area | ✅ | 提案→確認 |
| Quadrant | ✅ | 影響度×緊急度ロジックで自動推定→確認 |
| Milestone | — | 当該四半期 |
| Status | — | Todo |
| 作業ディレクトリ作成 | — | type が `task/decision/review` なら作成提案 |

### Quadrant の推定基準

`feedback_quadrant_assignment_logic.md` に従う：

- **影響度**: 本業（and roots / Scarlet）直結＝高 / 個人発信・成長系＝中 / 好奇心＝低
- **緊急度**: 鮮度・他者待ち・運用詰まり＝高 / 同価値で先延ばし可＝低
- 高×高 → **Q1** / 高×低 or 中×高 → **Q2** / 低×高 → **Q3** / 低～中×低 → **Q4**

推定根拠を1行添えて確認する。例：「Area=Scarlet で業務直結＆Review 待ちあり → Q2 想定」

## ワークフロー

### 1. 1日5件チェック

```bash
TODAY=$(date +%Y-%m-%d)
TODAY_COUNT=$(gh issue list --repo imutaroh/ObsidianImus --state all --limit 50 \
  --search "created:$TODAY" --json number | jq 'length')
```

5件以上なら「今日すでに N 件あります。続けますか？」と確認。

### 2. Issue 作成

```bash
url=$(gh issue create \
  --repo imutaroh/ObsidianImus \
  --title "<TITLE>" \
  --label "type:<TYPE>" \
  --milestone "<MILESTONE>" \
  --body "<BODY>")
issue_num=$(echo "$url" | awk -F/ '{print $NF}')
```

### 3. Project Life に追加

```bash
gh project item-add 2 --owner imutaroh --url "$url"
```

### 4. Item ID を取得して Project フィールドを設定

```bash
item_id=$(gh project item-list 2 --owner imutaroh --format json --limit 200 \
  | jq -r --arg n "$issue_num" '.items[] | select(.content.number == ($n|tonumber)) | .id')

bash "$SKILL_DIR/scripts/set_project_fields.sh" "$item_id" \
  --status "Todo" \
  --quadrant "Q2" \
  --area "dev"
```

スクリプトの引数仕様は [scripts/set_project_fields.sh](scripts/set_project_fields.sh) 冒頭参照。

### 5. 作業ディレクトリの雛形作成（オプション）

slug は英小文字-kebab。タイトルから機械的に作る（例：「HTTP ステータスコードはなぜ3桁」→ `http-status-code-history`）。

```bash
mkdir -p "Company/issues/${issue_num}-${slug}"
```

ファイルは置かない。Issue ごとに必要なものが違うので空ディレクトリで OK（CLAUDE.md の運用方針）。

### 6. 報告

```
✅ Issue #N: <TITLE>
   URL: <URL>
   type:<TYPE> / Quadrant: <Q> / Area: <AREA> / Milestone: <M>
   作業ディレクトリ: Company/issues/N-slug/ （作成した場合）
```

## type ラベルの判定ガイド

| ラベル | 用途 |
|---|---|
| `task` | 実行すべき具体的な作業（コード書く / 資料作る / 設定する） |
| `idea` | 「これ気になる」「やってみたい」の好奇心ベース |
| `decision` | 何かを決める必要があるもの（ADR 的） |
| `review` | レビュー・確認だけが必要なもの |
| `antipattern` | やってしまった失敗・避けたいパターンの記録 |

迷ったら `task` か `idea` の二択を提示して選んでもらう。

## エラー時の対処

- `gh issue create` が milestone エラー → Milestone 名のタイポか未作成。`gh api repos/imutaroh/ObsidianImus/milestones` で確認
- `gh project item-add` が権限エラー → `gh auth refresh -s project` でスコープ追加
- フィールド ID が見つからない → Project の構造が変わった可能性。`references/project_life_ids.md` を再生成（同ファイル末尾の取得コマンドを実行）

## 関連メモリ

- Quadrant 振り分けロジック: `~/.claude/projects/-Users-imutaakihiro-repos-imutaakihiro-ObsidianImus/memory/feedback_quadrant_assignment_logic.md`
- Issue 紐づきディレクトリ運用: 同 `project_issue_tied_directory.md`
- GitHub Issue タスク管理の基本: 同 `feedback_tasks_via_github_issue.md`
