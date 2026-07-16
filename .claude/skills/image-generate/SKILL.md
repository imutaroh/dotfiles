---
name: image-generate
description: article-visual-planner等が出した画像生成プロンプトを、mcp-hub-image MCP経由でOpenAI gpt-image-2に直接投げて生成し、signed URLからcurlで~/Downloadsに保存するスキル。ブラウザ操作・Chrome接続・ログインは一切不要。「画像を生成して」「画像作って」「プロンプトから画像生成して」「図を作って」で使用。旧chatgpt-image（ChatGPT UIをブラウザ操作で叩く方式）の後継。生成のみ担当、プロンプト作成はarticle-visual-planner、リネーム・配置・gitはスコープ外。
---

# 画像生成（image-generate）

`mcp-hub-image` MCP（`generate_image`）でOpenAI gpt-image-2にプロンプトを直接投げ、**生成→signed URLをcurlでDL→実ファイル確認**まで一気通貫。旧`chatgpt-image`（ChatGPT UIをブラウザ操作で叩く方式）を置き換えた版。ブラウザ・ログイン・Chrome接続は不要で、生成自体も同期的（ポーリング不要）。

```
article-visual-planner（プロンプト）→ 【このSkill：generate_image→DL→実ファイル確認】 → （リネーム/配置/git は範囲外）
```

## 入口前提（満たさないと動かない）

- `mcp__mcp-hub-image__generate_image` が使えること。ツールリストに無い/呼んでエラーなら`mcp__mcp-hub-image__authenticate`を呼び、返ってきたOAuth URLをユーザーに提示して承認してもらう（この一手だけは人間の操作が必要。代行できない）。
- 複数枚が必要なら1プロンプト＝1回の呼び出しを順に行う（同時並列で投げない）。

## 絶対の鉄則（捏造防止・最優先）

- **実際にツールが返したsigned URL・保存先パスだけを根拠に「生成できた」と言う。** ツール結果が返る前に完了したと書かない。
- curlでDL後、`ls -la`で実ファイルのサイズを確認してから完了報告する。0バイトや存在しないファイルを「取得済み」と書かない。
- 失敗（生成拒否・DL失敗）はそのまま正直に報告し、次のプロンプトに進まない。

## 手順

### 1. quality決定
ユーザーが明示しない限り `low` を使う。`medium`/`high`はユーザーが高画質を要求したときだけ使う（階級によっては拒否されることがある）。

### 2. 生成
`mcp__mcp-hub-image__generate_image` にプロンプト・quality（・size・reference_images）を渡す。
- 戻り値：base64画像（インラインで確認できる）＋GCS保存先（`gs://...`）＋ダウンロード用signed URL（有効期限あり、約12時間）。
- 参照画像を使う場合は先に `mcp__mcp-hub-image__upload_reference` でPUT用signed URLを取得 → `curl -X PUT -H "Content-Type: <type>" --data-binary @<file> '<upload_url>'` でアップロード → 返ってきた `gs://` を `reference_images` に渡す。

### 3. signed URLをcurlでDL
```bash
curl -fSL -o ~/Downloads/<わかりやすいファイル名>.png '<signed URL>'
```
ファイル名は呼び出しごとに意味のある名前にする（例: `sp-fig1.png`）。signed URLはクエリパラメータが長いので、シングルクォートで丸ごと囲む。

### 4. 実ファイル確認
```bash
ls -la ~/Downloads/<ファイル名>.png
```
サイズが0でないことを確認し、`Read`で中身を見てからユーザーに完了報告する。ここで初めて「取得完了」と言える。

### 5. 複数枚のループ
プロンプトが複数あるなら2〜4を1件ずつ繰り返す。1件失敗したらそこで止め、どこまで成功したか報告する。

## 破綻条件（事前に伝える）

- **OAuthトークン失効**：`generate_image`がエラーを返す/ツールリストから消える場合、`authenticate`から再承認が必要＝人間の操作待ちで自動化が止まる。cron/loop実行など人が見ていないタイミングで起きると、その回だけ画像工程が止まる。
- **quality=medium/highは階級によって拒否されうる**（ツール説明に明記）。まず`low`で確認してから上げる。
- **signed URLは約12時間で失効**（GCSオブジェクト自体は30日で自動削除）。生成後は早めにDLする。
- **日本語描画は概ね正確だが、複雑な長文・小さいフォントは崩れることがある。** 生成後は必ず目視確認し、崩れていれば再生成する。

## スコープ外
- プロンプト作成 → `article-visual-planner`
- リネーム・リポジトリ配置・git への取り込み → 範囲外

## 関連
- `article-visual-planner`（前段：プロンプト）/ `article-studio`（全体オーケストレータ）
