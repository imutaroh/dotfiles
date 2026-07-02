---
name: chatgpt-image
description: article-visual-planner が出した画像生成プロンプトを、ログイン済みChrome（Chrome in Claude / claude-in-chrome MCP）のChatGPTに投入し、生成を発火→完了をポーリング検知→ブラウザ内fetchでDLして手元(~/Downloads)まで取得する、生成と回収を一気通貫で行うスキル。「画像を生成して」「ChatGPTで図を作って」「プロンプトから画像生成して」「生成を発火して」で生成から、「表示されてる画像を落として」「ブラウザの画像をダウンロードして」「生成画像をもらってきて」で回収のみ（生成済みタブが前提）でも使える。実行には Chrome 接続が必要。捏造禁止＝実際の生成枚数・実ファイルだけを信じる。プロンプト作成は article-visual-planner の担当でスコープ外。リネーム・リポジトリ配置・git push もスコープ外＝「画像を手元に取得するところまで」が役割。
---

# ChatGPT 画像の生成＆回収（chatgpt-image）

article-visual-planner のプロンプトを、ログイン済みChromeのChatGPTに**実際に投入して生成を発火**し、**完了を検知**して、そのまま**ブラウザ内fetchで `~/Downloads` にDL**するところまでを一気通貫で行う。旧 `chatgpt-image-gen`（発火・完了検知）と `browser-image-grab`（DL）を統合したスキル。

```
article-visual-planner（プロンプト）→ 【このSkill：投入→発火→完了検知→DL→実ファイル確認】 → （リネーム/配置/git は範囲外）
```

## 2つのモード

- **生成モード**（デフォルト）：プロンプトを投入して生成を発火し、完了検知 → DL → 確認まで（手順1〜6 全部）。
- **回収のみモード**：画像が**すでにログイン済みタブに表示されている**ときは、手順2〜3（投入・発火）を飛ばし、手順1→4→5→6だけ実行する。「表示されてる画像を落として」系の依頼はこちら。ChatGPT に限らずログイン済みタブの表示画像全般に使える。

## 入口前提（満たさないと動かない）

- **`mcp__claude-in-chrome__` が接続されていること**（＝Chrome in Claude）。
  - **CLI単体のセッションでは繋がっていないことがある**。`tabs_context_mcp` が無い/エラーなら、**ここで停止**し「Chrome接続のあるセッション（デスクトップ/拡張）で実行して」と案内する。先に進めない。
- **Playwright は使わない**。別プロセスのブラウザ＝ChatGPT未ログインで、ログイン済みタブ前提の fetch と噛み合わないため。
- 生成モードなら、投入するプロンプトが手元にあること（article-visual-planner の SCENE 群／パス／貼付）。
- 回収のみモードなら、対象画像がログイン済みタブにすでに表示されていること。

## 絶対の鉄則（捏造防止・最優先）

このスキルが存在する理由は、過去に「生成した・DLした・移動した」と実行せずに偽報告（捏造）してタスクを壊したから。次を厳守する。

- **実値だけを信じる。** 「生成された」「DLした」を自己申告で書かない。`javascript_tool` の戻り値（実際の枚数）と `ls`/`Read` の実ファイルだけで完了判定する。
- **スクショに頼らない。** 長い会話ではブラウザのスクショがコンテキストから省略され、盲目操作になる。判断は JS の戻り値・`get_page_text`・実ファイルで行う。
- **戻り値に画像URL/`id=` を含めない**（Cookie相当としてプライバシーブロックされ `[BLOCKED]` になる）。枚数・サイズ・ok/失敗のみ返す。
- **成功を絶対に捏造しない。** ツール結果が返る前に結果らしき文章を書かない。`ls`/`Read` が「存在しない」と言うものは本当に存在しない。
- **失敗時は次に進まず停止して正直報告。** 生成拒否・タイムアウト・枚数不一致・DL失敗をそのまま伝える。

## 手順

### 1. タブ確保
`mcp__claude-in-chrome__tabs_context_mcp` で `chatgpt.com` のタブIDを取得する。
- 無ければ ChatGPT を開くよう案内（or 接続済みなら新規タブで chatgpt.com へ）。
- 生成モードは**新規チャット**で始めるのが安全（過去文脈の混入を防ぐ）。
- 回収のみモードは、画像が出ている会話タブをそのまま使う。

### 2. プロンプト投入（生成モードのみ・1プロンプト＝1メッセージ）
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

### 3. 生成完了をポーリング検知（生成モードのみ）
`javascript_tool` で **「フル解像度画像（naturalWidth>=1000）が期待枚数になるまで」** 一定間隔（例：5秒ごと、最大90秒）で確認する。**URLは返さない。枚数だけ。**

```js
(()=>{const seen=new Set();let n=0;document.querySelectorAll('img').forEach(i=>{if((i.naturalWidth||0)>=1000&&!seen.has(i.src)){seen.add(i.src);n++;}});return JSON.stringify({count:n});})()
```
- `count` が期待枚数に達したら次へ。
- 90秒（要調整）で達しなければ**タイムアウトとして停止・報告**（生成中・拒否・UI変更のいずれかを疑う）。
- 回収のみモードでは、この同じJSで「いま表示されている枚数」を確認してから手順4へ。`count` が 0 ならスクロール/リロード、閾値(>=1000)の調整を検討する。

### 4. ブラウザ内 fetch でDL発火
`javascript_tool` で、各画像を `fetch(credentials:'include')`→blob→`<a download>` で連番DLする。**戻り値はURLを含めず枚数・サイズ・ok/失敗のみ**。`prefix` は呼び出しごとに分かりやすい固有名にする。

```js
(async()=>{const seen=new Set();const urls=[];document.querySelectorAll('img').forEach(i=>{if((i.naturalWidth||0)>=1000&&!seen.has(i.src)){seen.add(i.src);urls.push(i.src);}});const prefix='grab_';const r=[];for(let k=0;k<urls.length;k++){try{const resp=await fetch(urls[k],{credentials:'include'});const b=await resp.blob();const u=URL.createObjectURL(b);const a=document.createElement('a');a.href=u;a.download=prefix+(k+1)+'.png';document.body.appendChild(a);a.click();a.remove();await new Promise(x=>setTimeout(x,1000));URL.revokeObjectURL(u);r.push({n:k+1,ok:true,size:b.size});}catch(e){r.push({n:k+1,ok:false,err:String(e).slice(0,60)});}}return JSON.stringify({found:urls.length,results:r});})()
```

`naturalWidth>=1000` は ChatGPT のフル解像度生成画像を拾う閾値。アバターやアイコンを除外するための値で、対象サイトに応じて調整する。ChatGPTは `chatgpt.com/backend-api/estuary/content?id=...` の**認証必須URL**で配信するため、`curl` 等ブラウザ外では取得不可＝必ずログイン済みブラウザ内 `fetch` が要る。

### 5. 実ファイルを確認（鉄則）
```bash
ls -lt ~/Downloads/grab_*.png
```
JS戻り値の `size` と `ls` のサイズが一致するか、枚数が揃っているか確認する。落ちていなければ DL設定（下記の破綻条件）を疑う。

### 6. 中身を Read で検証して報告
DLした各 PNG を `Read` で開き、**どの画像か（内容）を実際に見て**ユーザーに報告する。DOM順と意図した順がずれることがあるので、順番は中身で確認する。ここで初めて「取得完了」と言える。

### 7. 複数プロンプトのループ（生成モードのみ）
プロンプトが複数あるなら、2〜6を**1件ずつ繰り返す**。1件失敗したらそこで止め、どこまで成功したか報告する。

> リネーム・配置・git への取り込みはこのスキルの範囲外。取得した `~/Downloads/grab_*.png` をユーザーに引き渡して終了する。

## 破綻条件（事前に伝える）

- **ChatGPTのUI変更で composer/送信ボタン/画像配信のセレクタが壊れる**（手順2・4のJSは要メンテ）。
- **生成拒否・レート制限**：投入しても画像が出ない。タイムアウトで検知し停止・報告。
- **生成時間のばらつき**：単純なsleepでなくポーリング前提。タイムアウト値は題材で調整。
- **ブラウザのDL設定が「保存先を毎回確認する」だと `a.click()` がダイアログで止まる**。自動保存設定が前提。
- **複数DLで Chrome が「複数ファイルのDLを許可？」を出すと止まりうる**。出たらユーザーに許可を依頼するか、1枚ずつ実行する。
- 画像が `<canvas>` 描画など `<img>` でない場合、この収集ロジックでは拾えない。
- **claude-in-chrome 未接続**（CLI単体）では動かない＝停止して案内。

## スコープ外
- プロンプト作成 → `article-visual-planner`
- リネーム・リポジトリ配置・git → 範囲外

## 関連
- `article-visual-planner`（前段：プロンプト）/ `article-studio`（全体オーケストレータ）
