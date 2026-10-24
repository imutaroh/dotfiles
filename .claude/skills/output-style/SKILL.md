---
name: output-style
description: >
  Claude Code の output style（Default / Proactive / Concise / Explanatory / Learning / 自作スタイル）を
  ユーザー全体（~/.claude/settings.json）で切り替えるスキル。組み込みの /output-style（v2.1.269〜）は
  プロジェクトの .claude/settings.local.json に書くので、全プロジェクトの既定を変えたいときに使う。
  「/output-style」「/output-style explanatory」「アウトプットスタイル変えて」
  「Learning モードにして」「output style を確認して」で使用。反映は次のメッセージから。
---

# output-style: output style 切り替えコマンド

## 前提知識

- output style はシステムプロンプトの一部。v2.1.251 以降は、切り替えると**次のメッセージから**反映される
  （それ以前は `/clear` か新セッションが必要だった）。ただしスタイルのファイル自体を新規作成・編集した場合は、
  起動時に読まれるので Claude Code の再起動が要る
- 組み込みの `/output-style`（v2.1.269〜）と `/config` のメニューは、プロジェクトの `.claude/settings.local.json` に書く。
  このスキルが同名なので、ローカル端末では組み込みコマンドの代わりにこのスキルが動く
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
   - 組み込み: Default / Proactive / Concise / Explanatory / Learning
   - 自作: `~/.claude/output-styles/*.md` と `./.claude/output-styles/*.md`（frontmatter の name、無ければファイル名）
3. 現在値・一覧・切り替え方（`/output-style <名前>`）を1つの表で提示する

## 引数あり（`/output-style <名前>`）: 切り替え

1. 名前を正規化する。組み込みは大文字小文字を無視して Default / Proactive / Concise / Explanatory / Learning に解決（設定値は大文字小文字を区別するので、書き込むのは正規化後の表記）。
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
   - 「反映は次のメッセージから」
   - 「dotfiles に取り込む場合は `~/dotfiles/sync-settings.sh`」

## してはいけないこと

- project local への書き込み（/config メニューの領分。このスキルは user レベル専用）
- settings.json の outputStyle 以外のキーの変更・整形・並べ替え
- 確認なしでの project 側 outputStyle の削除
