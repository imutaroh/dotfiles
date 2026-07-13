---
artifact_url: https://claude.ai/code/artifact/d4e97077-824e-4c64-b043-03ca5b8e92f2
updated: 2026-07-10
---

# タスクボード

## PR #2747 レビュー対応（task-dispatcher mccpos）

- [x] P1: main.go:51 マージで消えた AmazonFBAShipmentItemJobName の復元確認 | 完了:2026-07-09 | メモ:PR全体で削除は1行のみと点検済・ビルドOK
- [x] P3: mccpos.go:94 自明コメント削除 | 完了:2026-07-09 | メモ:作業ツリーで削除済みを確認
- [x] P4: mccpos.go:58 var宣言の位置 | 完了:2026-07-09 | メモ:関数内ループ外の var successCount, failureCount int に確定。スコープ3段階(パッケージ/関数/ループ)を学習
- [x] P2: G-err mccpos.go:134/60/65/155 executeMccPosJob を (result, error) 返しに変更しハンドリング | 完了:2026-07-09 | メモ:err!=nilイディオムで分岐・ループは止めない・build/test緑
- [x] P2: G-tenant mccpos.go:126/128 Tenants/tenantIDs 命名と単一/複数の矛盾解消 | 完了:2026-07-09 | メモ:JobArgs []MccPosTenantJobArgs 構造に変更(ecforce型)・build/test緑
- [ ] P4: mccpos.tf:36 スケジュール時刻が要件(日次05:07 JST)通りか確認して返信 | 優先度:中 | 追加:2026-07-09
- [ ] P5: 議論・メモ系4件(15/124/test:9/response.go:670)の整理と返信 | 優先度:低 | 追加:2026-07-09
- [x] 対応完了後 /commit → /push で PR 更新 | 完了:2026-07-09 | メモ:2コミットをpush・PR本文のGETレスポンス例も現行形式に更新
- [~] P4: mccpos.tf:36 時刻確認の返信・P5 議論系の返信 | 追加:2026-07-09 | メモ:検証済み(05:07 JST要件通り)。返信はご主人様が対応中

## MCC POS モデリング #2604（PRまで）

- [x] staging: Hrd の整理（過剰コメント・前例なし .0 除去・空行の削除、yml 同期） | 完了:2026-07-10
- [x] staging: Hrd yml に warn テスト3本（registered_date/store_code/jan_code の not_null） | 完了:2026-07-10 | メモ:error(素のnot_null)3本で実装。家風準拠でwarnから格上げ
- [x] int: sales_extracted yml に自然キー3列の not_null テスト追加（規約§4違反の解消） | 完了:2026-07-10
- [x] int: sales_extracted yml の列記載を5列→全13列に | 完了:2026-07-10
- [x] int: 戦略Aの出典パス（ingestion/docs/mccpos/README.md）をSQLコメントに追記 | 完了:2026-07-10
- [x] int: 99_transform 商品名寄せ106行の精読（有効断面・min(item_code)・形態判定） | 完了:2026-07-10 | メモ:min→any_valueへ変更(実データ裏取り済)
- [x] mart: Report yml フル装備（_HASHKEY・PK制約・partition/cluster・contract・ownerメタ） | 完了:2026-07-10 | メモ:N/A表示設計も追加
- [x] 検証: dev_aimuta で uv run dbt build -s +Report_Hugkumi_MccPosSales（source解決先の確認含む） | 完了:2026-07-10 | メモ:38/38 PASS・Report 16,714行
- [x] 仕上げ: main取り込み→ビルド再確認→/commit→/push でPR作成 | 完了:2026-07-10 | メモ:draft PR #2843・レビュアー apokurinkansen・マージは#2603 apply後
- [ ] PR #2843 のレビュー対応と Draft 解除（#2603 apply 後にマージ） | 優先度:中 | 追加:2026-07-10
- [ ] 監視クエリの Issue 起票（JAN多重item_code・(group,series)割れ・マスタ未登録JANの検知） | 優先度:低 | 追加:2026-07-10
