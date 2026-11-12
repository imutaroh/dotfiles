#!/bin/bash
# obsidian-daily-note: Obsidian の daily ノートを、無ければテンプレから作る
# launchd（com.imutaro.obsidian-daily-note）が毎日 0:05 とログイン時に呼ぶ。手で実行してもよい。
#
# 使い方:
#   obsidian-daily-note.sh                          今日のノートを作る
#   DAILY_DATE=2026-11-13 obsidian-daily-note.sh    その日のノートを作る（確認用）
#   OBSIDIAN_VAULT=<パス> obsidian-daily-note.sh    Vault を切り替える（確認用）
#
# 保存先とテンプレは、Vault の .obsidian/daily-notes.json（Obsidian の設定）に合わせる。
# 空のときの既定は folder=Private/Journals、template=_Meta/Templates/日報。
# 既にあるノートは上書きしない。
#
# テンプレは中身をそのままコピーする。{{date}} などの変数は展開しない（含まれていれば警告を出す）。
# ファイル名の書式も YYYY-MM-DD だけに対応する。
set -euo pipefail

vault="${OBSIDIAN_VAULT:-$HOME/repos/imutaroh/ObsidianImus}"
config="$vault/.obsidian/daily-notes.json"
date_str="${DAILY_DATE:-$(date +%Y-%m-%d)}"

log() { echo "$(date '+%F %T') obsidian-daily-note: $*"; }
die() { log "$*" >&2; exit 1; }

[ -d "$vault" ] || die "Vault が無い: $vault"
[[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "日付は YYYY-MM-DD で指定する: $date_str"

# キーが無い・設定ファイルが無いときは空文字を返す
read_config() { plutil -extract "$1" raw -o - "$config" 2>/dev/null || true; }

folder="$(read_config folder)"
folder="${folder:-Private/Journals}"
template="$(read_config template)"
template="${template:-_Meta/Templates/日報}"
format="$(read_config format)"
if [ -n "$format" ] && [ "$format" != "YYYY-MM-DD" ]; then
    die "ファイル名の書式 ($format) には未対応。YYYY-MM-DD だけ対応する"
fi

note="$vault/$folder/$date_str.md"
if [ -e "$note" ]; then
    log "既にある: $note"
    exit 0
fi

template_file="$vault/${template%.md}.md"
[ -f "$template_file" ] || die "テンプレが無い: $template_file"
if grep -q '{{' "$template_file"; then
    log "警告: テンプレに {{...}} がある。変数は展開せずそのまま入る: $template_file" >&2
fi

mkdir -p "$vault/$folder"
# noclobber で「無ければ作る」を書き込みの時点でも守る（確認のあとで Obsidian が先に作った場合に上書きしない）
if ( set -o noclobber; cat "$template_file" > "$note" ) 2>/dev/null; then
    log "作った: $note"
elif [ -e "$note" ]; then
    log "既にある: $note"
else
    die "作れなかった: $note"
fi
