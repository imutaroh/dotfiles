#!/bin/bash
# Stop の観察ログ。会話は止めない。
#
# settings.json では async: true で登録する。async のフックは decision を
# 返しても効かず、終了を待たない（https://code.claude.com/docs/en/hooks）。
# ここでも終了コードは常に 0 で、stdout には何も出さない。
# 応答本文は残さない。秘密が混ざることがある。

[ -n "${HOME:-}" ] || exit 0

log_dir="${HOME}/.claude/state"
log_file="${log_dir}/session-stops.jsonl"
mkdir -p "$log_dir" 2>/dev/null || exit 0

if command -v jq >/dev/null 2>&1; then
    jq -c '{
        t: (now | todate),
        event: .hook_event_name,
        session: .session_id,
        cwd: .cwd,
        stop_hook_active: .stop_hook_active,
        background: ((.background_tasks // []) | length),
        crons: ((.session_crons // []) | length)
    }' >> "$log_file" 2>/dev/null || true
fi

exit 0
