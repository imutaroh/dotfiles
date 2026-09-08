#!/bin/bash
# check-parity.sh: Claude Code と Codex CLI の「同等体験」設定が実環境に効いているかを一括点検する。
#
# 何も書き換えない（読み取り専用）。setup.sh の後や Codex 更新後に実行して、
# 崩れた箇所だけを直す運用のためのスクリプト。
#
# 使い方:
#   bash ~/dotfiles/.codex/scripts/check-parity.sh          # 全項目を点検。NG が1つでもあれば exit 1
#   bash ~/dotfiles/.codex/scripts/check-parity.sh --quick  # codex debug prompt-input（数十秒）を省略
#
# 点検項目:
#   1. codex バイナリが複数 PATH にある場合、版がそろっているか（古い版は status_line 識別子を知らず無視する）
#   2. ~/.codex/AGENTS.md / rules / themes のシンボリックリンクが dotfiles を指しているか
#   3. config.toml のキー（apply-codex-config.py --check）
#   4. status_line の識別子がこの codex バイナリに実在するか（バイナリの文字列を検索）
#   5. hooks.json の共通フック3件が config.toml で trust 済みか（未 trust は /hooks で本人が行う）
#   6. 個人スキルブリッジ（setup-codex-skills.py --check）
#   7. developer_instructions（output style）と CLAUDE.md がモデル入力に実際に注入されているか
set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

ng=0
ok()   { printf '  ✓ %s\n' "$1"; }
bad()  { printf '  ✗ %s\n' "$1"; ng=$((ng + 1)); }
warn() { printf '  ⚠ %s\n' "$1"; }
head_() { printf '\n%s\n' "$1"; }

# ── 1. codex バイナリの版ずれ ─────────────────────────────
head_ "[1] codex バイナリ"
if ! command -v codex >/dev/null 2>&1; then
    bad "codex が PATH にない"
else
    versions=""
    while IFS= read -r bin; do
        v=$("$bin" --version 2>/dev/null | awk '{print $2}')
        printf '  · %s  %s\n' "${v:-?}" "$bin"
        versions="$versions $v"
    done < <(which -a codex | awk '!seen[$0]++')
    uniq_count=$(echo "$versions" | tr ' ' '\n' | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
    if [ "$uniq_count" -le 1 ]; then
        ok "版ずれなし"
    else
        bad "複数の版が PATH にある。先頭以外を消すか brew upgrade --cask codex / npm i -g @openai/codex で揃える"
    fi
fi

# ── 2. シンボリックリンク ─────────────────────────────────
head_ "[2] シンボリックリンク（→ dotfiles）"
check_link() {  # args: link expected_target
    local link=$1 expected=$2 actual
    if [ -L "$link" ]; then
        actual=$(readlink "$link")
        if [ "$actual" = "$expected" ]; then
            ok "$link"
        else
            bad "$link → $actual（期待: $expected）"
        fi
    elif [ -e "$link" ]; then
        bad "$link はリンクではなく実ファイル（setup.sh を再実行する前に中身を確認）"
    else
        bad "$link が無い（setup.sh を実行）"
    fi
}
check_link "$CODEX_HOME/AGENTS.md" "$DOTFILES_DIR/.claude/CLAUDE.md"
check_link "$CODEX_HOME/rules/claude-parity.rules" "$DOTFILES_DIR/.codex/rules/claude-parity.rules"
check_link "$CODEX_HOME/themes/imutaro-cool.tmTheme" "$DOTFILES_DIR/.codex/themes/imutaro-cool.tmTheme"

# ── 3. config.toml のキー ─────────────────────────────────
head_ "[3] config.toml（apply-codex-config.py --check）"
if out=$(python3 "$DOTFILES_DIR/.codex/scripts/apply-codex-config.py" --config "$CODEX_HOME/config.toml" --check 2>&1); then
    ok "管理キーは最新"
else
    bad "差分あり → python3 ~/dotfiles/.codex/scripts/apply-codex-config.py --apply"
    printf '%s\n' "$out" | sed 's/^/      /'
fi
if grep -q '^developer_instructions[[:space:]]*=' "$CODEX_HOME/config.toml"; then
    ok "developer_instructions（output style）が設定済み"
else
    warn "developer_instructions が無い（default 運用なら正常。15sai にするなら sync-output-style.py 15sai）"
fi

# ── 4. status_line 識別子の実在チェック ───────────────────
head_ "[4] status_line 識別子がこの codex に実在するか"
codex_bin=$(command -v codex)
# npm 配布は .js ラッパーなので、実バイナリを doctor と同じ場所から探す
real_bin=$(readlink -f "$codex_bin")
case "$real_bin" in
    *.js) real_bin=$(find "$(dirname "$real_bin")/../node_modules/@openai" -type f -perm +111 -name codex 2>/dev/null | head -1) ;;
esac
if [ -z "$real_bin" ] || [ ! -f "$real_bin" ]; then
    warn "実バイナリを特定できず識別子チェックを省略（$codex_bin）"
else
    ids=$(python3 - "$CODEX_HOME/config.toml" <<'PY'
import sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb"))
for i in (cfg.get("tui", {}).get("status_line") or []):
    print(i)
PY
)
    strings_dump=$(strings "$real_bin" 2>/dev/null)
    for id in $ids; do
        if printf '%s' "$strings_dump" | grep -q -- "$id"; then
            ok "$id"
        else
            bad "$id はバイナリに見当たらない（この版では無効。config.toml か codex の版を確認）"
        fi
    done
fi

# ── 5. hooks の trust ────────────────────────────────────
head_ "[5] 共通フックの trust（config.toml の [hooks.state]）"
if [ -f "$CODEX_HOME/hooks.json" ]; then
    defined=$(python3 - "$CODEX_HOME/hooks.json" <<'PY'
import json, sys
h = json.load(open(sys.argv[1])).get("hooks", {})
print(sum(len(g.get("hooks", [])) for groups in h.values() for g in groups))
PY
)
    trusted=$(grep -c 'trusted_hash' "$CODEX_HOME/config.toml" || true)
    printf '  · 定義 %s 件 / trust 済み %s 件\n' "$defined" "$trusted"
    if [ "$trusted" -ge "$defined" ]; then
        ok "全フックが trust 済み"
    else
        bad "未 trust のフックあり。Codex TUI で /hooks を開き、定義（迎合防止・確認音・完了音・タブ内ステータス）を確認して trust する（スクリプトでは代行しない）"
    fi
else
    bad "$CODEX_HOME/hooks.json が無い（.codex/hook-fragments/*.json を手動統合）"
fi

# ── 6. 個人スキルブリッジ ────────────────────────────────
head_ "[6] 個人スキルブリッジ（setup-codex-skills.py --check）"
if out=$(python3 "$DOTFILES_DIR/setup-codex-skills.py" --check 2>&1); then
    ok "CHECK OK"
else
    bad "検査 NG"
    printf '%s\n' "$out" | grep -E 'ERROR|未設置|SOURCE_DRIFT' | head -10 | sed 's/^/      /'
fi

# ── 7. モデル入力への注入確認 ────────────────────────────
head_ "[7] developer_instructions / CLAUDE.md がモデル入力に注入されているか"
if [ "$QUICK" -eq 1 ]; then
    warn "--quick のため省略"
else
    injected=$(cd "$DOTFILES_DIR" && perl -e 'alarm 120; exec @ARGV' codex debug prompt-input "ping" 2>/dev/null \
        | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    s = json.dumps(d, ensure_ascii=False)
except Exception:
    print("parse-error"); sys.exit()
# style: developer ロールのメッセージが先頭にあるか（developer_instructions の注入）
# claude: CLAUDE.md 固有の文言が含まれるか（AGENTS.md symlink 経由の注入）
print("style=%s claude=%s" % (any(m.get("role") == "developer" for m in d if isinstance(m, dict)), "必ず日本語" in s))
')
    case "$injected" in
        *"style=True claude=True"*) ok "developer_instructions と CLAUDE.md（AGENTS.md 経由）が注入されている" ;;
        *"style=False claude=True"*) warn "CLAUDE.md は注入されているが developer ロールが無い（default 運用なら正常）" ;;
        parse-error|"") bad "codex debug prompt-input の出力を解釈できない（ログイン切れ・ネットワークを確認）" ;;
        *) bad "CLAUDE.md が注入されていない: $injected" ;;
    esac
fi

printf '\n'
if [ "$ng" -eq 0 ]; then
    echo "PARITY OK（NG 0 件）"
    exit 0
else
    echo "PARITY NG（$ng 件）。上の ✗ を直してから再実行"
    exit 1
fi
