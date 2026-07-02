# Project Life #2 — IDs リファレンス

最終取得: 2026-06-02

## Project 本体

| 項目 | 値 |
|---|---|
| Owner | imutaroh |
| Project Number | 2 |
| Project ID | `PVT_kwHODDLAY84BXouL` |

## Status フィールド

- Field ID: `PVTSSF_lAHODDLAY84BXouLzhS0RIU`

| 名前 | Option ID |
|---|---|
| Todo | `20e57f3e` |
| In Progress | `4e84ccd9` |
| Review | `be2accf1` |
| Pending | `97724816` |
| Done | `de4d5180` |

> Icebox は 2026-06-02 に廃止（退避ゾーンを持たない方針）。

## Area フィールド

- Field ID: `PVTSSF_lAHODDLAY84BXouLzhS0V8U`

| 名前 | Option ID |
|---|---|
| Mind | `704b1f98` |
| dev/AI | `d5ca1188` |
| Work | `5defc752` |
| Life | `d697154a` |

> 2026-05-24 に 9個 → 4個へ集約。旧 Area（コンテンツ/健康/Scarlet 等）は廃止。

## 再取得コマンド

Project の構造が変わったらこれを実行して上記の表を更新する：

```bash
gh api graphql -f query='
query {
  user(login: "imutaroh") {
    projectV2(number: 2) {
      id
      fields(first: 30) {
        nodes {
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}'
```

## 既知の注意点

- **GitHub SingleSelect 更新の罠**: `singleSelectOptions` を GraphQL で全置換すると既存割り当てが消える。Option 追加・削除は Web UI 経由が安全（Field ID は同じでも Option ID は再生成される可能性あり）
- Auto-add ワークフローには依存せず、`gh project item-add` を毎回明示実行する
