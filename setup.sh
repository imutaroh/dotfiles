#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

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
mise trust "$DOTFILES_DIR/.config/mise/config.toml"
eval "$(mise activate bash)"
mise install

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
# Google Cloud SDK
# ==================================================
if ! command -v gcloud &> /dev/null && [ ! -d "$HOME/google-cloud-sdk" ]; then
    echo "Installing Google Cloud SDK..."
    export CLOUDSDK_CORE_DISABLE_PROMPTS=1
    curl https://sdk.cloud.google.com | bash
fi

# ==================================================
# 設定ファイル（シンボリックリンク）
# ==================================================
ln -sf "$DOTFILES_DIR/.gitconfig" ~/.gitconfig
ln -sf "$DOTFILES_DIR/.zprofile" ~/.zprofile
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc

mkdir -p ~/.config/mise
ln -sf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml

mkdir -p ~/.config/uv
ln -sf "$DOTFILES_DIR/.config/uv/uv.toml" ~/.config/uv/uv.toml

mkdir -p ~/.config/ghostty
ln -sf "$DOTFILES_DIR/.config/ghostty/config" ~/.config/ghostty/config

# herdr は config.toml のみ管理（同ディレクトリのソケット・ログ・セッション状態は対象外）
mkdir -p ~/.config/herdr
ln -sf "$DOTFILES_DIR/.config/herdr/config.toml" ~/.config/herdr/config.toml

# hunk は config.toml のみ管理（同ディレクトリの state.json は対象外）
mkdir -p ~/.config/hunk
ln -sf "$DOTFILES_DIR/.config/hunk/config.toml" ~/.config/hunk/config.toml

ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml

mkdir -p ~/.config/git
ln -sf "$DOTFILES_DIR/.config/git/ignore" ~/.config/git/ignore

# lazygit
mkdir -p "$HOME/Library/Application Support/lazygit"
ln -sf "$DOTFILES_DIR/.config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# raycast script-commandsはディレクトリ全体をシンボリックリンク
if [ -d ~/.config/raycast/script-commands ] && [ ! -L ~/.config/raycast/script-commands ]; then
    rm -rf ~/.config/raycast/script-commands
fi
mkdir -p ~/.config/raycast
ln -sfn "$DOTFILES_DIR/.config/raycast/script-commands" ~/.config/raycast/script-commands

# nvimはディレクトリ全体をシンボリックリンク
if [ -d ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
    rm -rf ~/.config/nvim
fi
ln -sfn "$DOTFILES_DIR/.config/nvim" ~/.config/nvim

# Claude Code設定（ファイル単位でリンク、他のファイルは残す）
mkdir -p ~/.claude/sounds
ln -sf "$DOTFILES_DIR/.claude/CLAUDE.md" ~/.claude/CLAUDE.md
ln -sf "$DOTFILES_DIR/.claude/statusline.sh" ~/.claude/statusline.sh
ln -sf "$DOTFILES_DIR/.claude/statusline-preview.sh" ~/.claude/statusline-preview.sh
ln -sfn "$DOTFILES_DIR/.claude/scripts" ~/.claude/scripts

# hooksはファイル単位でリンク（dotfiles 管理外のフックを消さないため、
# skills のようなディレクトリまるごとリンクにはしない）
mkdir -p ~/.claude/hooks
ln -sf "$DOTFILES_DIR/.claude/hooks/anti-sycophancy.sh" ~/.claude/hooks/anti-sycophancy.sh
ln -sf "$DOTFILES_DIR/.claude/hooks/play-sound.sh" ~/.claude/hooks/play-sound.sh

# settings.json は symlink にしない（claude doctor が rename で書き戻して壊すため）。
# 初回だけ配布し、以降は ./sync-settings.sh で実環境から dotfiles に取り込む。
if [ ! -e ~/.claude/settings.json ]; then
    cp "$DOTFILES_DIR/.claude/settings.json" ~/.claude/settings.json
fi

# skillsはディレクトリ全体をシンボリックリンク
if [ -d ~/.claude/skills ] && [ ! -L ~/.claude/skills ]; then
    rm -rf ~/.claude/skills
fi
ln -sfn "$DOTFILES_DIR/.claude/skills" ~/.claude/skills

# Codex は Claude Code と同じカスタム指示を読む。
# Codex 固有のモデル・権限・Hooks は ~/.codex/config.toml で別管理する。
mkdir -p ~/.codex
ln -sf "$DOTFILES_DIR/.claude/CLAUDE.md" ~/.codex/AGENTS.md

# Codex のカスタムテーマはファイル単位でリンクし、他のテーマを残す。
mkdir -p ~/.codex/themes
ln -sf "$DOTFILES_DIR/.codex/themes/imutaro-cool.tmTheme" ~/.codex/themes/imutaro-cool.tmTheme

# リポジトリ内では AGENTS.md がなければ CLAUDE.md を指示として読む。
# 既存の config.toml は Codex アプリが管理するため、ファイル全体を symlink しない。
if [ ! -e ~/.codex/config.toml ]; then
    touch ~/.codex/config.toml
fi
if ! grep -q '^project_doc_fallback_filenames[[:space:]]*=' ~/.codex/config.toml; then
    printf '\nproject_doc_fallback_filenames = ["CLAUDE.md"]\n' >> ~/.codex/config.toml
fi

# Claude Code の寒色デザインに合わせた Codex TUI を初回だけ設定する。
# [tui] がすでにある場合は、Codex アプリが管理する既存値を壊さない。
if ! grep -q '^\[tui\]$' ~/.codex/config.toml; then
    printf '\n[tui]\ntheme = "imutaro-cool"\nstatus_line = ["model-with-reasoning", "context-remaining", "five-hour-limit", "weekly-limit", "current-dir", "git-branch"]\n' >> ~/.codex/config.toml
elif ! grep -q '^theme[[:space:]]*=[[:space:]]*"imutaro-cool"$' ~/.codex/config.toml \
    || ! grep -q '^status_line[[:space:]]*=' ~/.codex/config.toml; then
    echo "⚠️  Codex TUI は既存設定あり。/theme と /statusline で Imutaro Cool 設定を確認してください"
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

# 書籍ノート知識貯蔵庫（private リポジトリ・dotfilesの.gitignore対象）を skills 配下に clone
if [ ! -d "$DOTFILES_DIR/.claude/skills/books" ]; then
    git clone https://github.com/imutaroh/book-skills.git "$DOTFILES_DIR/.claude/skills/books" \
        || echo "⚠️  book-skills のcloneに失敗（private リポジトリのため要認証。後で手動で clone してください）"
fi

# themesはディレクトリ全体をシンボリックリンク
if [ -d ~/.claude/themes ] && [ ! -L ~/.claude/themes ]; then
    rm -rf ~/.claude/themes
fi
ln -sfn "$DOTFILES_DIR/.claude/themes" ~/.claude/themes

ln -sf "$DOTFILES_DIR/.claude/sounds/complete.wav" ~/.claude/sounds/complete.wav
ln -sf "$DOTFILES_DIR/.claude/sounds/confirm.wav" ~/.claude/sounds/confirm.wav

echo "Setup complete! Run 'source ~/.zshrc' to apply changes."
