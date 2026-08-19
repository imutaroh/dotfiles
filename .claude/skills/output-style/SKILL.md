---
name: output-style
description: >
  Claude Code の output style（Default / Proactive / Explanatory / Learning / 自作スタイル）を
  1コマンドで切り替えるスキル。組み込みの /output-style コマンドが v2.1.91 で廃止されたため、
  その代替。「/output-style」「/output-style explanatory」「アウトプットスタイル変えて」
  「Learning モードにして」「output style を確認して」で使用。書き込み先はユーザー全体
  （~/.claude/settings.json）。反映は /clear か新セッションから。
---

# output-style: output style 切り替えコマンド

## 前提知識

- output style はシステムプロンプトの一部で、**セッション開始時に一度だけ読まれる**。
  切り替えてもこのセッションには効かない。必ず「反映は `/clear` か新セッションから」と案内する
- 設定の優先度は project local (`.claude/settings.local.json`) > project (`.claude/settings.json`) > user (`~/.claude/settings.json`)。
  このスキルは **user レベル（`~/.claude/settings.json`）だけ**を書き換える
- `~/.claude/settings.json` は symlink ではなく実ファイル。直接編集してよい
  （dotfiles に取り込むのは `~/dotfiles/sync-settings.sh` の役目）

## 引数なし（`/output-style`）: 現在値と一覧を表示

1. 現在の有効値を優先度順に調べる（見つかった最初のものが有効）:
   ```bash
   for f in .claude/settings.local.json .claude/settings.json ~/.claude/settings.json; do
     [ -f "$f" ] && jq -r --arg f "$f" 'select(.outputStyle != null) | "\($f): \(.outputStyle)"' "$f"
   done
   ```
   どこにも無ければ有効値は Default
2. 選べるスタイルを列挙する:
   - 組み込み: Default / Proactive / Explanatory / Learning
   - 自作: `~/.claude/output-styles/*.md` と `./.claude/output-styles/*.md`（frontmatter の name、無ければファイル名）
3. 現在値・一覧・切り替え方（`/output-style <名前>`）を1つの表で提示する

## 引数あり（`/output-style <名前>`）: 切り替え

1. 名前を正規化する。組み込みは大文字小文字を無視して Default / Proactive / Explanatory / Learning に解決。
   自作スタイルは一覧（上記）と照合。どれにも一致しなければ候補を提示して確認する
2. `~/.claude/settings.json` を jq で書き換える（Edit ツールでもよい。JSON 全体を壊さないこと）:
   - Default にする場合はキーごと削除: `jq 'del(.outputStyle)'`
   - それ以外: `jq --arg s "<名前>" '.outputStyle = $s'`
   - 書き込みは一時ファイル経由（`jq ... settings.json > tmp && mv tmp settings.json`）。
     破損防止のため、書き換え前に `jq empty` で元ファイルが正しい JSON か確認する
3. **上書きチェック**: カレントプロジェクトの `.claude/settings.local.json` / `.claude/settings.json` に
   `outputStyle` があれば、「このリポではそちらが優先されるため効かない」と明確に警告し、
   消すかどうかを確認する（勝手に消さない）
4. 結果を報告する。必ず添えること:
   - 「反映は `/clear` か新セッションから」
   - 「dotfiles に取り込む場合は `~/dotfiles/sync-settings.sh`」

## してはいけないこと

- project local への書き込み（/config メニューの領分。このスキルは user レベル専用）
- settings.json の outputStyle 以外のキーの変更・整形・並べ替え
- 確認なしでの project 側 outputStyle の削除
