#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# リンクを張る。既存の実ファイルや実ディレクトリは消さず BACKUP_DIR へ退避する。
# すでにシンボリックリンクなら、そのまま張り替える。
link() {
    local src="$1" dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        local saved="$BACKUP_DIR/${dest#"$HOME"/}"
        mkdir -p "$(dirname "$saved")"
        mv "$dest" "$saved"
        echo "退避しました: ${dest} → ${saved}"
    fi
    ln -sfn "$src" "$dest"
}

# ==================================================
# Homebrew
# ==================================================
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # アーキテクチャに応じてパスを設定
    if [[ -f /opt/homebrew/bin/brew ]]; then
        # Apple Silicon
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        # Intel Mac
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

brew bundle --file="$DOTFILES_DIR/Brewfile"

# ==================================================
# mise（グローバル Python）
# ==================================================
# 設定を先にリンクする。ホームで実行したとき、リンクが無いと mise install は何も入れない
mkdir -p ~/.config/mise
link "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml
mise trust "$DOTFILES_DIR/.config/mise/config.toml"
eval "$(mise activate bash)"
mise install

# Codex 用のスクリプトは tomllib を使う（Python 3.11 以上）。macOS 標準の python3 は 3.9 なので使えない
codex_python() {
    mise exec -- python3 "$@"
}

# ==================================================
# uv（グローバル CLI ツール）
# ==================================================
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

if [ -f "$DOTFILES_DIR/.config/uv/uv-tools.txt" ]; then
    while IFS= read -r tool || [ -n "$tool" ]; do
        [[ "$tool" =~ ^#.*$ || -z "$tool" ]] && continue
        echo "Installing $tool..."
        uv tool install "$tool"
    done < "$DOTFILES_DIR/.config/uv/uv-tools.txt"
fi

# Playwright ブラウザのインストール
if command -v playwright &> /dev/null; then
    echo "Installing Playwright browsers..."
    playwright install chromium
fi

# ==================================================
# Claude Code
# ==================================================
if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

# ==================================================
# gh 拡張
# ==================================================
# gh-dash: GitHub の PR / Issue を俯瞰する TUI ダッシュボード（設定は .config/gh-dash/）
# Homebrew の formula は存在しないため Brewfile では管理できない
if command -v gh &> /dev/null && ! gh extension list | grep -q "dlvhdr/gh-dash"; then
    echo "Installing gh-dash..."
    gh extension install dlvhdr/gh-dash
fi

# ==================================================
# Google Cloud SDK
# ==================================================
if ! command -v gcloud &> /dev/null && [ ! -d "$HOME/google-cloud-sdk" ]; then
    echo "Installing Google Cloud SDK..."
    export CLOUDSDK_CORE_DISABLE_PROMPTS=1
    curl -fsSL https://sdk.cloud.google.com | bash
fi

# ==================================================
# 設定ファイル（シンボリックリンク）
# ==================================================
link "$DOTFILES_DIR/.gitconfig" ~/.gitconfig
link "$DOTFILES_DIR/.zprofile" ~/.zprofile
link "$DOTFILES_DIR/.zshrc" ~/.zshrc

mkdir -p ~/.config/uv
link "$DOTFILES_DIR/.config/uv/uv.toml" ~/.config/uv/uv.toml

mkdir -p ~/.config/ghostty
link "$DOTFILES_DIR/.config/ghostty/config" ~/.config/ghostty/config

# herdr は config.toml と自作スクリプトのみ管理
# （同ディレクトリのソケット・ログ・セッション状態は対象外）
mkdir -p ~/.config/herdr
link "$DOTFILES_DIR/.config/herdr/config.toml" ~/.config/herdr/config.toml
link "$DOTFILES_DIR/.config/herdr/agent-taborder-watch.py" ~/.config/herdr/agent-taborder-watch.py
link "$DOTFILES_DIR/.config/herdr/annotate-refresh.sh" ~/.config/herdr/annotate-refresh.sh
link "$DOTFILES_DIR/.config/herdr/sidechat.sh" ~/.config/herdr/sidechat.sh

# Herdr デスクトップアプリ（herdr-app）は keys.json・settings.json・下記の自作レイアウトと mod のみ管理。
# アプリはズーム変更などで settings.json を symlink 越しに書き込む（リンクは置き換えない。2026-10-31 実測）。
# 同ディレクトリの AGENTS.md・*.d.ts・付属の mods / layouts・view.json 等はアプリが起動時に生成するので対象外
mkdir -p ~/.config/herdr-app
link "$DOTFILES_DIR/.config/herdr-app/keys.json" ~/.config/herdr-app/keys.json
link "$DOTFILES_DIR/.config/herdr-app/settings.json" ~/.config/herdr-app/settings.json
# 個人レイアウト mine（main の複製。下のステータスバーを status-keys に差し替え）と、
# 右パネル（Files / Changes）を Cmd+Shift+E / Cmd+Shift+G で開閉する mod status-keys。
# changes-gh は付属 changes の複製（差分を GitHub 配色にし、長い行を折り返す）。mine の Changes ブロックが参照する。
# files-img は付属 files の複製（画像ファイルを画像として表示する）。mine の Files ブロックが参照する。
# redpen は Claude の最新の返答にコメントして送り返す mod（Cmd+U）。会話ログの場所は
# SessionStart フック（.claude/scripts/hc-label-claude-session.sh）が端末のラベルに入れる。
# tab-autoname は Claude Code が端末タイトルに書く要約をタブ名に写す mod。mine の 0px ブロックで動く。
# tab-groups は付属 tabs の複製（タブをグループにまとめて畳む）。mine のタブバーが参照する。
# agents-groups は付属 agents の複製（一覧を tab-groups のグループで区切る）。mine のサイドバーが参照する。
# mod は main.js と mod.json だけをリンクする（同フォルダの *.d.ts・jsconfig.json はアプリが生成）
mkdir -p ~/.config/herdr-app/layouts
link "$DOTFILES_DIR/.config/herdr-app/layouts/mine.json" ~/.config/herdr-app/layouts/mine.json
for mod in status-keys changes-gh files-img redpen tab-autoname tab-groups agents-groups; do
  mkdir -p ~/.config/herdr-app/mods/$mod
  link "$DOTFILES_DIR/.config/herdr-app/mods/$mod/main.js" ~/.config/herdr-app/mods/$mod/main.js
  link "$DOTFILES_DIR/.config/herdr-app/mods/$mod/mod.json" ~/.config/herdr-app/mods/$mod/mod.json
done
link "$DOTFILES_DIR/.config/herdr-app/mods/redpen/extract.py" ~/.config/herdr-app/mods/redpen/extract.py

# hunk は config.toml のみ管理（同ディレクトリの state.json は対象外）
mkdir -p ~/.config/hunk
link "$DOTFILES_DIR/.config/hunk/config.toml" ~/.config/hunk/config.toml

# plannotator-tui（herdr-annotate のレビュー画面）は config.toml のみ管理
mkdir -p ~/.config/plannotator-tui
link "$DOTFILES_DIR/.config/plannotator-tui/config.toml" ~/.config/plannotator-tui/config.toml

# yazi は yazi.toml のみ管理（keymap / theme を足すときはここにも追加）
mkdir -p ~/.config/yazi
link "$DOTFILES_DIR/.config/yazi/yazi.toml" ~/.config/yazi/yazi.toml

# gh-dash（gh 拡張の GitHub ダッシュボード）
mkdir -p ~/.config/gh-dash
link "$DOTFILES_DIR/.config/gh-dash/config.yml" ~/.config/gh-dash/config.yml

# karabiner は karabiner.json のみ管理（assets/ や automatic_backups は対象外）
mkdir -p ~/.config/karabiner
link "$DOTFILES_DIR/.config/karabiner/karabiner.json" ~/.config/karabiner/karabiner.json

link "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml

mkdir -p ~/.config/git
link "$DOTFILES_DIR/.config/git/ignore" ~/.config/git/ignore

# nvimはディレクトリ全体をシンボリックリンク
link "$DOTFILES_DIR/.config/nvim" ~/.config/nvim

# Claude Code設定（ファイル単位でリンク、他のファイルは残す）
mkdir -p ~/.claude/sounds
# .claude/CLAUDE.md は私的な内容を含むので追跡していない。無い環境では切れたリンクを作らない
if [ -f "$DOTFILES_DIR/.claude/CLAUDE.md" ]; then
    link "$DOTFILES_DIR/.claude/CLAUDE.md" ~/.claude/CLAUDE.md
fi
link "$DOTFILES_DIR/.claude/statusline.sh" ~/.claude/statusline.sh
link "$DOTFILES_DIR/.claude/statusline-preview.sh" ~/.claude/statusline-preview.sh
link "$DOTFILES_DIR/.claude/scripts" ~/.claude/scripts

# hooksはファイル単位でリンク（dotfiles 管理外のフックを消さないため、
# skills のようなディレクトリまるごとリンクにはしない）
mkdir -p ~/.claude/hooks
link "$DOTFILES_DIR/.claude/hooks/play-sound.sh" ~/.claude/hooks/play-sound.sh

mkdir -p ~/.claude/output-styles
link "$DOTFILES_DIR/.claude/output-styles/15sai.md" ~/.claude/output-styles/15sai.md

# settings.json は symlink にしない（claude doctor が rename で書き戻して壊すため）。
# 初回だけ配布し、以降は ./sync-settings.sh で実環境から dotfiles に取り込む。
if [ ! -e ~/.claude/settings.json ]; then
    cp "$DOTFILES_DIR/.claude/settings.json" ~/.claude/settings.json
fi

# herdr の Claude integration: Claude Code の SessionStart hook でセッション ID を herdr に報告する。
# herdr-annotate（Cmd+U）が「そのペインの Claude の返答」を特定するのに必要（無いと全体で最新の
# transcript を拾って別セッションの返答が開く）。冪等。settings.json に hook を追記し、
# hook 本体 ~/.claude/hooks/herdr-agent-state.sh は herdr が生成・管理する（dotfiles 管理外）。
# 上の cp より後に置く。先に実行すると settings.json を作ってしまい、dotfiles の設定が配られない
if command -v herdr >/dev/null 2>&1; then
    herdr integration install claude >/dev/null || echo "herdr integration install claude に失敗しました"
fi

# skillsはディレクトリ全体をシンボリックリンク
link "$DOTFILES_DIR/.claude/skills" ~/.claude/skills

# Codex は Claude Code と同じカスタム指示を読む。
# Codex 固有のモデル・権限・Hooks は ~/.codex/config.toml で別管理する。
mkdir -p ~/.codex
if [ -f "$DOTFILES_DIR/.claude/CLAUDE.md" ]; then
    link "$DOTFILES_DIR/.claude/CLAUDE.md" ~/.codex/AGENTS.md
fi

# Codex のカスタムテーマはファイル単位でリンクし、他のテーマを残す。
mkdir -p ~/.codex/themes
link "$DOTFILES_DIR/.codex/themes/imutaro-cool.tmTheme" ~/.codex/themes/imutaro-cool.tmTheme

# リポジトリ内では AGENTS.md がなければ CLAUDE.md を指示として読む。
# 既存の config.toml は Codex アプリが管理するため、ファイル全体を symlink しない。
if [ ! -e ~/.codex/config.toml ]; then
    touch ~/.codex/config.toml
fi
# project_doc_fallback_filenames・[tui] の theme/status_line/terminal_title は
# apply-codex-config.py がキー単位で冪等に追記・置換する（詳細はスクリプト先頭のdocstring）。
codex_python "$DOTFILES_DIR/.codex/scripts/apply-codex-config.py" --apply

# Codex の execpolicy ルール（Claude Code の permissions 相当）をリンクする。
# ~/.codex/rules/default.rules は Codex が承認記憶として自動生成するファイルなので触らない。
mkdir -p ~/.codex/rules
link "$DOTFILES_DIR/.codex/rules/claude-parity.rules" ~/.codex/rules/claude-parity.rules

# output style（developer_instructions）は初回だけ設定する。
# ユーザーが `sync-output-style.py default` で意図的に消した状態を setup.sh が
# 勝手に戻さないよう、既に設定がある場合は触らない。
if ! grep -q '^developer_instructions[[:space:]]*=' ~/.codex/config.toml; then
    codex_python "$DOTFILES_DIR/.codex/scripts/sync-output-style.py" 15sai
fi

# Claude Code の transcript mode に合わせ、Ctrl+O で Codex の transcript を開く。
# config.toml はアプリも更新するため、既存セクションがある場合は上書きせず手動確認を促す。
if ! grep -q '^open_transcript[[:space:]]*=[[:space:]]*"ctrl-o"$' ~/.codex/config.toml; then
    if grep -q '^\[tui\.keymap\.global\]$' ~/.codex/config.toml \
        || grep -q '^\[tui\.keymap\.pager\]$' ~/.codex/config.toml; then
        echo "⚠️  Codex keymap は既存設定あり。/keymap で Claude Code 互換設定を確認してください"
    else
        printf '\n[tui.keymap.global]\nopen_transcript = "ctrl-o"\ncopy = []\n\n[tui.keymap.pager]\nscroll_up = "k"\nscroll_down = "j"\nhalf_page_up = "ctrl-u"\nhalf_page_down = "ctrl-d"\njump_top = "g"\njump_bottom = "shift-g"\nclose_transcript = "q"\n' >> ~/.codex/config.toml
    fi
fi

# themesはディレクトリ全体をシンボリックリンク
link "$DOTFILES_DIR/.claude/themes" ~/.claude/themes

link "$DOTFILES_DIR/.claude/sounds/complete.wav" ~/.claude/sounds/complete.wav
link "$DOTFILES_DIR/.claude/sounds/confirm.wav" ~/.claude/sounds/confirm.wav

# ==================================================
# launchd（常駐エージェント）
# ==================================================
# plist の __HOME__ をこのマシンのホームに置き換えて ~/Library/LaunchAgents/ へ置き、bootstrap でロードする。
# 既にロード済みの場合は一度 bootout してから bootstrap し直すことで冪等にする。
# 実行するファイルが無いジョブは登録しない。
mkdir -p ~/Library/LaunchAgents
for plist in "$DOTFILES_DIR"/launchd/*.plist; do
    [ -e "$plist" ] || continue
    label="$(basename "$plist" .plist)"
    dest="$HOME/Library/LaunchAgents/$label.plist"
    target="$(plutil -extract ProgramArguments.1 raw -o - "$plist")"
    target="${target//__HOME__/$HOME}"
    if [ ! -e "$target" ]; then
        echo "launchd: $label をスキップしました（${target} がありません）"
        continue
    fi
    sed "s|__HOME__|$HOME|g" "$plist" > "$dest"
    launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
    if launchctl bootstrap "gui/$(id -u)" "$dest" >/dev/null 2>&1; then
        echo "launchd: $label をロードしました"
    else
        echo "⚠️  launchd: $label のロードに失敗しました（手動で launchctl bootstrap を確認してください）"
    fi
done

if [ ! -f ~/.gitconfig.local ]; then
    echo "⚠️  Git の名前とメールが未設定です。~/.gitconfig.local に [user] の name と email を書いてください"
fi
if [ -d "$BACKUP_DIR" ]; then
    echo "既存の設定は ${BACKUP_DIR} に退避しました"
fi

echo "Setup complete! Run 'source ~/.zshrc' to apply changes."
