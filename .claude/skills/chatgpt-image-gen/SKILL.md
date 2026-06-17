---
name: chatgpt-image-gen
description: article-visual-planner が出した画像生成プロンプトを、ログイン済みChrome（Chrome in Claude / claude-in-chrome MCP）のChatGPTに投入し、画像生成を発火→完了をポーリング検知して、browser-image-grab に引き渡すスキル。記事図解パイプラインの「プロンプト出力」と「画像回収」の“間”を埋める。「画像を生成して」「ChatGPTで図を作って」「プロンプトから画像生成して」「生成を発火して」で使用。実行には Chrome 接続（デスクトップ/拡張）が必要。捏造禁止＝実際の生成枚数だけを信じる。プロンプト作成は article-visual-planner、ダウンロードは browser-image-grab の担当でスコープ外。
---

# ChatGPT 画像生成の発火（chatgpt-image-gen）

article-visual-planner のプロンプトを、ログイン済みChromeのChatGPTに**実際に投入して生成を発火**し、**完了を検知**して `browser-image-grab` に渡す。これまで手動だった「貼って・押して・待つ」を埋めるスキル。

```
article-visual-planner（プロンプト）→ 【このSkill：投入→発火→完了検知】 → browser-image-grab（DL）
```

## 入口前提（満たさないと動かない）

- **`mcp__claude-in-chrome__` が接続されていること**（＝Chrome in Claude）。
  - **CLI単体のセッションでは繋がっていないことがある**。`tabs_context_mcp` が無い/エラーなら、**ここで停止**し「Chrome接続のあるセッション（デスクトップ/拡張）で実行して」と案内する。先に進めない。
- **Playwright は使わない**。別プロセスのブラウザ＝ChatGPT未ログインで、browser-image-grab（ログイン済みタブ前提）と噛み合わないため。
- 投入するプロンプトが手元にあること（article-visual-planner の SCENE 群／パス／貼付）。

## 絶対の鉄則（browser-image-grab から継承・捏造防止）

- **実値だけを信じる。** 「生成された」を自己申告で書かない。`javascript_tool` の戻り値（実際の枚数）だけで完了判定する。
- **スクショに頼らない。** 長い会話ではスクショが省略され盲目操作になる。判断は JS の戻り値で行う。
- **戻り値に画像URL/`id=` を含めない**（Cookie相当としてプライバシーブロックされ `[BLOCKED]` になる）。枚数・サイズ・ok/失敗のみ返す。
- **失敗時は次に進まず停止して正直報告。** 生成拒否・タイムアウト・枚数不一致をそのまま伝える。

## 手順

### 1. タブ確保
`mcp__claude-in-chrome__tabs_context_mcp` で `chatgpt.com` のタブIDを取得する。
- 無ければ ChatGPT を開くよう案内（or 接続済みなら新規タブで chatgpt.com へ）。
- 画像生成は**新規チャット**で始めるのが安全（過去文脈の混入を防ぐ）。

### 2. プロンプト投入（1プロンプト＝1メッセージ）
`javascript_tool`（`action: 'javascript_exec'`）で、composer に本文を入れて送信する。
**複数プロンプトは1件ずつ順に**。混ぜて一度に送らない（生成が割れる）。

```js
// 例：composer にテキストを入れて送信（セレクタはUI変更で壊れうる＝破綻条件参照）
(()=>{
  const box = document.querySelector('div[contenteditable="true"], textarea#prompt-textarea');
  if(!box){return JSON.stringify({ok:false,reason:'composer_not_found'});}
  box.focus();
  // contenteditable / textarea 両対応で値を入れる
  if(box.tagName==='TEXTAREA'){ box.value = PROMPT; box.dispatchEvent(new Event('input',{bubbles:true})); }
  else { document.execCommand('insertText', false, PROMPT); }
  const send = document.querySelector('button[data-testid="send-button"], button[aria-label*="送信"], button[aria-label*="Send"]');
  if(send){ send.click(); return JSON.stringify({ok:true,sent:'click'}); }
  return JSON.stringify({ok:true,sent:'pending'});
})()
```
`PROMPT` は投入文字列に置換する。`ok:false` なら停止して報告。

### 3. 生成完了をポーリング検知
`javascript_tool` で **「フル解像度画像（naturalWidth>=1000）が期待枚数になるまで」** 一定間隔（例：5秒ごと、最大90秒）で確認する。**URLは返さない。枚数だけ。**

```js
(()=>{const seen=new Set();let n=0;document.querySelectorAll('img').forEach(i=>{if((i.naturalWidth||0)>=1000&&!seen.has(i.src)){seen.add(i.src);n++;}});return JSON.stringify({count:n});})()
```
- `count` が期待枚数に達したら次へ。
- 90秒（要調整）で達しなければ**タイムアウトとして停止・報告**（生成中・拒否・UI変更のいずれかを疑う）。

### 4. 完了 → browser-image-grab に引き渡し
完了を**実際の count で確認できたら**、`browser-image-grab` を呼んで `~/Downloads` にDLさせる。
このSkillは「生成発火と完了検知」まで。**DLはしない**（責務分離）。

### 5. 複数プロンプトのループ
プロンプトが複数あるなら、2〜4を**1件ずつ繰り返す**。1件失敗したらそこで止め、どこまで成功したか報告する。

## 破綻条件（事前に伝える）

- **ChatGPTのUI変更で composer/送信ボタンのセレクタが壊れる**（手順2のJSは要メンテ）。
- **生成拒否・レート制限**：投入しても画像が出ない。タイムアウトで検知し停止・報告。
- **生成時間のばらつき**：単純なsleepでなくポーリング前提。タイムアウト値は題材で調整。
- **画像が `<canvas>` 描画**だと `<img>` 収集で拾えない（browser-image-grab と同じ制約）。
- **claude-in-chrome 未接続**（CLI単体）では動かない＝停止して案内。
- 複数DLで Chrome が確認ダイアログを出すと止まりうる（browser-image-grab の破綻条件参照）。

## スコープ外
- プロンプト作成 → `article-visual-planner`
- 画像のダウンロード・実ファイル確認 → `browser-image-grab`
- リネーム・リポジトリ配置・git → 範囲外

## 関連
- `article-visual-planner`（前段：プロンプト）/ `browser-image-grab`（後段：DL）/ `article-studio`（全体オーケストレータ）
