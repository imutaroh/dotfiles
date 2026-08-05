---
name: book-to-skill
description: Kindleスクショから作ったPDF（画像のみ・テキストレイヤーなし）を視覚読解し、蔵書知識貯蔵庫 ~/.claude/skills/books/ に書籍ノートとして追加するスキル。「本をSkill化して」「この本を本棚に入れて」「PDFをbooksに追加」「蔵書に追加」「/book-to-skill」で使用。分冊ごとにサブエージェントを並列で走らせ、章別ノート→overview/cheatsheet/glossaryを生成し、private リポジトリへのコミットまで行う。
---

# book-to-skill — 書籍PDFを蔵書知識貯蔵庫に追加する

Kindleスクショアプリ（kindle-screenshot-app）が出力した分冊PDFを、Claudeが視覚読解して書籍ノート化し、`~/.claude/skills/books/<book-slug>/` に追加する。OCRは使わない（ReadツールがPDFページを画像として読める）。

## 前提と制約

- **入力**: `~/repos/imutaakihiro/kindle-screenshot-app/output/<書名>/<書名>_partN.pdf`（画像のみのPDF）
- **出力先**: `~/.claude/skills/books/<book-slug>/`（private リポジトリ `imutaroh/book-skills` の clone）
- **著作権**: 生成物は詳細要約＝翻案にあたるため、**public公開・dotfilesコミットは厳禁**。ローカル私的使用のみ
- **Readの制限**: PDFは1回20ページまで。50ページの分冊なら `pages="1-20"`, `"21-40"`, `"41-50"` の3回に分ける

## 手順

### 1. 対象の確認

```bash
cd ~/repos/imutaakihiro/kindle-screenshot-app/output && ls
for f in "<書名>"/*.pdf; do echo "$f: $(mdls -name kMDItemNumberOfPages -raw "$f") pages"; done
```

確認すること:
- 同一書籍の重複（旧版/第二版など）がないか → 新しい方だけ処理する
- ページ数が原著に対して極端に少なくないか → 撮影が途中で止まっている可能性。処理はするがノートに収録範囲を明記する
- 既に `~/.claude/skills/books/` に存在しないか

### 2. ディレクトリ作成

```bash
mkdir -p ~/.claude/skills/books/<book-slug>/chapters
```

`<book-slug>` は英小文字ケバブケース（例: `give-and-take`, `hatarakikata-note`）。

### 3. 分冊ごとにサブエージェントを並列起動

**1分冊 = 1エージェント**。すべて同一メッセージ内で起動して並列化する（`subagent_type: general-purpose`）。

各エージェントへのプロンプトに必ず含める要素:

1. 対象PDFの絶対パスとページ数
2. `Read` を `pages="1-20"`, `"21-40"`, ... と分割して**全ページ読む**指示
3. 章の切れ目で1ファイルに分け、`~/.claude/skills/books/<book-slug>/chapters/partN-ch<番号>-<英語slug>.md` に**Writeで保存**する指示
4. **分冊またぎの扱い**（重要）:
   - 冒頭が前分冊の章の続きなら「partN-1から続く章」としてノートを作る（章タイトル不明なら仮タイトルを付け「仮」と明記）
   - 末尾が章の途中なら「（partN+1に続く）」と**必ず明記**（後工程の欠落検出に使う）
5. 章ノートの構成（1ファイル800〜1200トークン）:
   - `# 章タイトル`（原文どおり）
   - **中心主張**: 2〜3文
   - **実践指針**: 「Xの場面ではYせよ」形式の箇条書き（最重要。実務で使える形に圧縮）
   - **根拠となる研究・事例**: 研究者名・数字・エピソードを簡潔に
   - **キーワード**: 本書特有の用語と定義
6. 禁止事項: 原文の長文丸写し／推測での捏造（読めないページは「判読不能」と記録）
7. 最終メッセージで返すもの: 書名・著者・出版社（part1担当のみ）、章リスト（番号・タイトル・1行要約）、書いたファイル名、重要用語、分冊の冒頭/末尾がどの章のどこで切れたか

part1担当には「冒頭で著者名・正式書名・出版社も確認して記録」を追加、最終分冊担当には「巻末の謝辞・参考文献・奥付は要約不要（存在だけ報告）」を追加する。

### 4. 欠落チェック

全エージェント完了後:

```bash
ls ~/.claude/skills/books/<book-slug>/chapters/
grep -l "に続く" ~/.claude/skills/books/<book-slug>/chapters/*.md
```

「partNに続く」と書かれた章の続きが実在するか照合する。分冊の境界にある章が抜けていることがあるので、抜けていたら該当エージェントに `SendMessage` で補完を依頼する（該当ページ範囲を指定して再読させる）。

### 5. 統合ファイルの生成

全章ノートを読んでから、3ファイルを書く。

- **`overview.md`**: 書誌情報 / コアフレームワーク（その本の中核概念3〜5個）/ 章インデックスの表（章・テーマ・ファイル名）/ 相談トピック→参照先 / 回答時の注意。**frontmatterは付けない**（Skill本体は books/SKILL.md 側だけ）
- **`cheatsheet.md`**: 「場面 → 行動 → 根拠（章）」の表。カテゴリごとに分割
- **`glossary.md`**: 用語 → 定義 → 参照章

### 6. カタログに登録

`~/.claude/skills/books/SKILL.md` の本棚テーブルに1行追加する（書名・著者・得意な相談ジャンル・フォルダ名）。

### 7. private リポジトリへコミット

```bash
cd ~/.claude/skills/books && git add -A && git commit -m "<書名> を蔵書に追加" && git push
```

`imutaroh/book-skills` は private。**publicに切り替えないこと**。

## 複数冊をまとめて処理する場合

分冊数の合計が多いときは、**3〜4冊ずつのバッチ**に分けて実行する（1バッチ10〜15エージェント程度）。全冊を一度に起動すると並列度の上限でキューが詰まり、進捗が見えづらくなる。バッチ完了ごとに統合ファイルを作り、最後にまとめてコミットする。

## 破綻しやすい点

- **分冊の境界で章が丸ごと抜ける**（最頻出）。手順4のチェックを飛ばさない
- **エージェントが一部ページを読み飛ばす**。ページ数と章ノートの分量が釣り合わないときは疑う
- **原著の一部しかスクショされていない**。overview.md に収録範囲を明記して、後で誤解しないようにする
