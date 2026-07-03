---
name: article-studio
description: 記事制作を一気通貫で回すオーケストレータ。ネタを受け取り、本文（媒体で分岐）→掴み→図解→画像生成・回収→多媒体展開、を既存Skillを順に呼んで連鎖実行する。各段は再実装せず copywriting-frameworks / note-create / learn / hook-and-headline / article-visual-planner / chatgpt-image / content-repurpose を呼ぶだけ。既定は全自動（途中で承認を求めず最後まで走る。ただしエラー・生成拒否・枚数不一致などの事故時は止めて正直に報告）。「記事を一気通貫で」「パイプラインで記事作って」「最初から最後まで記事を」「フルで記事作って」「記事を連鎖で」「/article-studio」で使用。
---

# 記事制作スタジオ（article-studio・オーケストレータ）

ネタ1つを入れたら、**本文→掴み→図解→画像→多媒体**まで連鎖で走らせる指揮者。
各工程は**専用Skillに委譲**する（このSkillは順番と受け渡しだけを管理し、中身は再実装しない）。

> [!warning] このSkillは「指揮者」であって「演奏者」ではない
> 本文も画像も自分で作らない。必ず下記の専用Skillを呼ぶ。Skill同士の受け渡し（前段の出力を次段の入力に）だけが仕事。

## 既定モード：全自動（ただし事故ったら止まる）

- **承認を求める関所は置かない。** Stage 0 で方針を確定したら、最後まで止まらず走る。
- **各サブSkillには Stage 0 の方針（媒体・読者・トーン・ゴール）を引数として渡し、サブSkill側の AskUserQuestion は省略**して既定値で進めるよう指示する。質問は「これが無いと物理的に進めない」真の欠落時のみ。
- **ただし“事故”では必ず停止して正直報告**（＝関所ではなくエラー停止）：
  - サブSkillが入力（なぐりがき等）を見つけられない
  - 画像生成の拒否・タイムアウト・枚数不一致・DL失敗（chatgpt-image）
  - Chrome 未接続で画像工程に入れない
  - 捏造禁止：実行結果が返る前に「できた」と書かない

## 前提（このVaultでの作法）

- **参照元**：`Vault/01_Notes/` 等（読むだけ）
- **出力先**：`Company/Drafts/YYYY-MM-DD-slug.md`（本文・掴み・多媒体は1案件1ノート、画像は `~/Downloads`）
- **書き込み禁止**：`Vault/` 配下
- **画像工程は Chrome 接続が必須**（chatgpt-image の前提）。CLI単体なら画像工程の手前まで走り、画像工程は停止して案内する。

## パイプライン全体図

```
Stage0 段取り確定
   │（媒体で本文の呼び先が決まる）
Stage1 裏取り(research) ※体験談なら自動スキップ
Stage2 本文 ─ note体験談→note-create / Zenn技術→learn / 告知・LP・セールス→copywriting-frameworks
Stage3 掴み(hook-and-headline)：タイトル＋書き出しを差し替え
Stage4 図解プラン(article-visual-planner)：プロンプト生成
Stage5 画像生成＆回収(chatgpt-image)：ログイン済みChromeで発火→完了検知→~/Downloads へDL   ※要Chrome接続
Stage6 多媒体展開(content-repurpose) ※指定があれば
```

## 各ステージの手順

### Stage 0: 段取り確定（ここだけは入力が要る）
全自動でも**最初のネタと方向は要る**。次の4点を、指示文から読み取れるだけ確定し、欠けていて致命的なものだけ最小限聞く：
1. **ネタ**（何を書くか／元なぐりがきのパス）
2. **媒体**（note / Zenn / 告知・LP・X）→ Stage2 の呼び先が決まる
3. **読者**（誰に・温度）
4. **ゴール**（読後の行動）
→ これを「方針メモ」として保持し、以降のサブSkill呼び出しに毎回渡す。

### Stage 1: 裏取り（research）※自動スキップ判定
- 主張に外部裏付けが要る記事 → `research` を呼ぶ。
- **体験談・気づき（裏取り不要）→ 自動でスキップ**。スキップしたことはログに残す（黙って飛ばさない）。

### Stage 2: 本文（媒体で分岐）
方針メモの媒体で呼び先を決め、**該当Skillを1つだけ呼ぶ**：

| 媒体 | 呼ぶSkill |
|---|---|
| note（体験談・成長記録） | `note-create` |
| Zenn（技術解説） | `learn` |
| 告知 / LP / セールス / X長文 | `copywriting-frameworks` |
| 知識の塊を物語で教えたい（読者主人公の完全映画版） | `story-teach` |

全自動では、方針メモをサブSkillに渡し、トーン等の質問は既定値で進めるよう指示する。
→ 本文ドラフトが `Company/Drafts/` に出る。
呼び出したSkillの品質バー/失敗モードを通過しているか確認してから次のStageへ進む。未通過なら同Skillに差し戻す（最大2回）。

### Stage 3: 掴み（hook-and-headline）
本文ドラフトを入力に `hook-and-headline` を呼び、**タイトル＋書き出しを生成→最高得点案で差し替え**。差し替え後の版を同ノートに反映。

### Stage 4: 図解プラン（article-visual-planner）
差し替え後の本文を入力に `article-visual-planner` を呼び、**配置プラン＋画像生成プロンプト一式**を得る。図不要と診断されたら画像工程（Stage5）を自動スキップ。

### Stage 5: 画像生成＆回収（chatgpt-image）※要Chrome接続
プロンプトを `chatgpt-image` に渡し、ログイン済みChromeで生成発火→完了検知→`~/Downloads` へDL→実ファイル確認まで（捏造禁止）。発火・回収を1スキルで一気通貫。
- **Chrome 未接続なら停止**：「ここまでの成果物（本文＋プロンプト）は出来ている。画像はChrome接続セッションで Stage5 から再開して」と案内。

### Stage 6: 多媒体展開（content-repurpose）※任意
「X/リール/メールにも展開」と指定があれば、完成本文を `content-repurpose` に渡して各媒体版を生成。

## 完了報告（毎回）
走り終えたら、**どのStageを実行/スキップ/停止したか**を一覧で報告する。成果物のパス（ドラフト・画像）を必ず添える。品質ゲートの通過状況（差し戻し回数）も報告する。

## 禁止 / OK
- **禁止**：本文や画像を自分で作る（必ず専用Skillに委譲）／事故を隠して進む／Vault に書き込む／結果が返る前に成功を書く
- **OK**：Stage0 の方針を全段に渡す／不要Stageは理由つきで自動スキップ／事故は即停止＆正直報告／成果物パスを必ず提示

## 関連（呼び出す部品）
- 本文：`note-create` / `learn` / `copywriting-frameworks`
- 掴み：`hook-and-headline` ／ 多媒体：`content-repurpose` / `x-thread`
- 図解：`article-visual-planner` → `chatgpt-image`
- 裏取り：`research` / `deep-research`
