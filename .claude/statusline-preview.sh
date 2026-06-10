#!/bin/bash
# statusline.sh の「実出力」を色つき HTML に変換してブラウザで開くプレビュー。
# ステータスラインをいつでも色つきで確認できる状態にしておくためのヘルパー。
# 手書きモックではなく実出力をそのまま変換するので、色や構成を変えても
# 再実行すれば常に最新の見た目が反映される（ズレない）。
#
# 使い方:  bash ~/.claude/statusline-preview.sh
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/statusline.sh"
OUT="$DIR/tmp/statusline-preview.html"
mkdir -p "$DIR/tmp"

# サンプル入力 ($1=ctx% $2=5h% $3=7d% を引数で変える)
NOW=$(date +%s); FIVE=$((NOW + 9900)); SEVEN=$((NOW + 225000))
render() {
    cat <<JSON | bash "$SCRIPT"
{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"$HOME/dotfiles"},"cost":{"total_cost_usd":0.08,"total_duration_ms":423000},"context_window":{"context_window_size":1000000,"used_percentage":$1,"current_usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"rate_limits":{"five_hour":{"used_percentage":$2,"resets_at":$FIVE},"seven_day":{"used_percentage":$3,"resets_at":$SEVEN}}}
JSON
}

# ANSI truecolor (\033[38;2;R;G;Bm ... \033[0m) を HTML span に変換。
# python プログラムは一時ファイルに置く (stdin はパイプの実データ用に空けておく)。
PYTMP="$(mktemp -t statusline-ansi2html.XXXXXX.py)"
trap 'rm -f "$PYTMP"' EXIT
cat > "$PYTMP" <<'PY'
import re, html, sys
ANSI = re.compile(r'\x1b\[([0-9;]*)m')
def conv(t):
    res = ''; pos = 0; color = None
    for m in ANSI.finditer(t):
        seg = t[pos:m.start()]
        if seg:
            e = html.escape(seg)
            res += f'<span style="color:{color}">{e}</span>' if color else e
        c = m.group(1)
        if c in ('0', ''):
            color = None
        else:
            mm = re.match(r'38;2;(\d+);(\d+);(\d+)', c)
            if mm:
                color = f'rgb({mm.group(1)},{mm.group(2)},{mm.group(3)})'
        pos = m.end()
    seg = t[pos:]
    if seg:
        e = html.escape(seg)
        res += f'<span style="color:{color}">{e}</span>' if color else e
    return res
data = sys.stdin.read().rstrip('\n')
print('<br>'.join(conv(l) for l in data.split('\n')))
PY
ansi2html() { python3 "$PYTMP"; }

N=$(render 6  20 3  | ansi2html)   # 通常
W=$(render 75 72 10 | ansi2html)   # 警告
D=$(render 95 93 80 | ansi2html)   # 危険

cat > "$OUT" <<HTML
<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><title>statusline preview</title>
<style>
 body{background:#0a0a0a;color:#c9d1d9;font-family:"SF Mono",Menlo,Monaco,monospace;font-size:16px;line-height:1.8;padding:28px 32px}
 h2{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:#6e7681;margin:28px 0 10px}
 h2:first-child{margin-top:0}
 .panel{background:#0d1117;border:1px solid #1c2128;border-radius:8px;padding:16px 20px;white-space:pre-wrap;word-break:break-word}
 .muted{color:#6e7681;font-size:13px;margin-top:24px}
</style></head><body>
<h2>通常 (ctx 6%)</h2><div class="panel">$N</div>
<h2>警告 (ctx 75%)</h2><div class="panel">$W</div>
<h2>危険 (ctx 95%)</h2><div class="panel">$D</div>
<p class="muted">statusline.sh の実出力をそのまま色変換したプレビュー。5h/7d の値とリセット残り時間は実キャッシュ由来。色や構成を変えたら再実行で更新。</p>
</body></html>
HTML

echo "$OUT"
open "$OUT" 2>/dev/null || true
