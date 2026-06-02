# Project Life #2 — IDs リファレンス

最終取得: 2026-05-20

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
| Todo | `05859249` |
| In Progress | `3c81879e` |
| Review | `fbe41ce3` |
| Pending | `cad6c6a3` |
| Done | `ed91ac74` |

## Quadrant フィールド

- Field ID: `PVTSSF_lAHODDLAY84BXouLzhS0V8Q`

| 名前 | Option ID |
|---|---|
| Q1: 重要×緊急 | `07074fa4` |
| Q2: 重要×非緊急 | `bef87806` |
| Q3: 非重要×緊急 | `223a3f9b` |
| Q4: 非重要×非緊急 | `bbf33342` |

## Area フィールド

- Field ID: `PVTSSF_lAHODDLAY84BXouLzhS0V8U`

| 名前 | Option ID |
|---|---|
| コンテンツ | `2a99415d` |
| AI | `c1076792` |
| アウトプット | `b09f18b5` |
| 健康 | `4913ceb1` |
| Scarlet | `43aa5b54` |
| and roots | `6874f546` |
| 金融 | `a151978a` |
| dev | `3d15ddf8` |
| 人 | `c49be055` |

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
- **Issue #45 が Open の間**は Project への Auto-add が動かない。`gh project item-add` の明示実行が必須
