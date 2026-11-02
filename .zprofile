# ==================================================
# Herdr の端末に漏れた環境変数を消す
# ==================================================
# herdr-core の端末は core 自身の環境変数を受け継ぐ。Herdr を Claude Code や旧 herdr の中から
# 起動すると、それらの変数が全端末に漏れる。特に CLAUDE_CODE_CHILD_SESSION があると、
# その端末で起動した Claude Code が会話ログを保存しなくなる（2026-11-02 に発覚）。
# 親が `hc hold`（端末を保持するプロセス）のシェル＝端末の最初のシェルだけを対象にし、
# Claude の Bash ツールなど Claude の子として動くシェルの変数には触らない。
if [[ -n "${HC_TERMINAL_ID:-}" && -n "${CLAUDECODE:-}${CLAUDE_CODE_CHILD_SESSION:-}${HERDR_ENV:-}" ]] \
  && [[ "$(ps -o command= -p $PPID 2>/dev/null)" == *" hold "* ]]; then
  unset -m 'CLAUDE*' 'CODEX_COMPANION_*'
  unset AI_AGENT TRACEPARENT
  # 旧 herdr（TUI）の変数だけを消す。HERDR_APP_HOME など新アプリの変数は残す
  unset HERDR_ENV HERDR_BIN_PATH HERDR_SOCKET_PATH HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID
fi

# ==================================================
# Homebrew（Apple Silicon / Intel Mac 両対応）
# ==================================================
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ==================================================
# PATH 設定
# ==================================================
# uv / mise でインストールしたグローバル CLI ツール
export PATH="$HOME/.local/bin:$PATH"

# ==================================================
# Google Cloud SDK
# ==================================================
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/path.zsh.inc"
fi

# ==================================================
# Claude Code（ローカル版を優先）
# ==================================================
export PATH="$HOME/.claude/local:$PATH"
