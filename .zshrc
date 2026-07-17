# ==================================================
# mise（ランタイムバージョン管理）
# ==================================================
eval "$(mise activate zsh)"

# ==================================================
# Google Cloud SDK（補完）
# ==================================================
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

# ==================================================
# プラグイン
# ==================================================
# コマンド入力時に履歴から補完候補を表示
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# ファジーファインダー（Ctrl+R で履歴検索・Ctrl+T でファイル検索）
source $(brew --prefix)/opt/fzf/shell/completion.zsh
source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
# ターミナル起動時に入力メソッドを英数に切り替え
macism com.apple.keylayout.ABC

# ==================================================
# プロンプト（Starship）
# ==================================================
eval "$(starship init zsh)"

# ==================================================
# direnv（ディレクトリごとの環境変数管理）
# NOTE: 他のシェル拡張（starship 等）の後に置くこと
#       https://direnv.net/docs/hook.html
# ==================================================
eval "$(direnv hook zsh)"

# ==================================================
# zoxide（cd の代替・frecency でディレクトリ移動）
# ==================================================
eval "$(zoxide init zsh)"

# ==================================================
# 履歴設定
# ==================================================
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt share_history          # ターミナル間で履歴を共有
setopt hist_ignore_all_dups   # 重複したコマンドを記録しない
setopt hist_reduce_blanks     # 余分な空白を除いて記録
setopt correct                # タイプミスを自動修正

# ==================================================
# エイリアス
# ==================================================
alias vim='nvim'
alias v='nvim'
alias g='git'
alias ll='ls -la'
alias la='ls -a'
# nh: Hunk を自動リロード付きで起動
#   nh        → 全差分（main 分岐点から手元の未コミット編集まで）。分岐点が取れなければ nh c と同じ
#   nh c      → 前回 commit してからの手元の編集だけ
#   nh p      → 前回 push してからの差分（push 先ブランチ @{push} 基準）
#   nh <args> → hunk diff --watch にそのまま渡す（例: nh main...HEAD / nh -- path）
nh() {
  if [[ $1 == c ]]; then
    shift
    hunk diff --watch "$@"
    return
  fi
  if [[ $1 == p ]]; then
    shift
    local pushed base
    pushed=$(git rev-parse '@{push}' 2>/dev/null) \
      || pushed=$(git rev-parse '@{upstream}' 2>/dev/null)
    if [[ -z $pushed ]]; then
      echo "nh: push 先が見つかりません（このブランチはまだ push していない可能性）" >&2
      return 1
    fi
    # ref を直接使うと、リモート側だけにあるコミットが「逆向きの差分」として
    # 混ざるため、共通祖先（= 実際に push した地点）を基準にする
    base=$(git merge-base "$pushed" HEAD)
    hunk diff --watch "$base" "$@"
    return
  fi
  if (( $# )); then
    hunk diff --watch "$@"
    return
  fi
  local base
  base=$(git merge-base origin/HEAD HEAD 2>/dev/null) \
    || base=$(git merge-base origin/main HEAD 2>/dev/null) \
    || base=$(git merge-base origin/master HEAD 2>/dev/null)
  if [[ -n $base ]]; then
    hunk diff --watch "$base"
  else
    hunk diff --watch
  fi
}

# dev: herdr に開発用の新しい Space を一発で組む（実行時のカレントディレクトリ基準）
#   Space 名: ディレクトリ名
#   タブ1「cchunk」: 左 Claude Code（50%）/ 右 hunk diff --watch
#   タブ2「nvim」  : nvim
#   引数でディレクトリ指定（省略時はカレントディレクトリ）
dev() {
  local dir="${1:-$PWD}"
  dir=${dir:A}  # cd を使わず絶対パス化（chpwd フックの発火を避ける）
  [[ -d $dir ]] || { echo "dev: ディレクトリがありません: $1" >&2; return 1; }
  if [[ -z $1 && $dir == "$HOME" ]]; then
    echo "dev: ホームディレクトリで実行しています。リポジトリに cd してから実行するか、dev <dir> で指定してください（本当にホームで開くなら dev ~）" >&2
    return 1
  fi
  local out ws t1 p1 p2 p3
  out=$(herdr workspace create --cwd "$dir" --label "${dir:t}" --focus) || {
    echo "dev: herdr の Space 作成に失敗しました（herdr 内で実行していますか？）" >&2
    return 1
  }
  ws=$(echo "$out" | jq -r '.result.workspace.workspace_id // empty')
  t1=$(echo "$out" | jq -r '.result.root_pane.tab_id // empty')
  p1=$(echo "$out" | jq -r '.result.root_pane.pane_id // empty')
  [[ -z $ws || -z $p1 ]] && { echo "dev: herdr の応答を解析できませんでした" >&2; return 1; }
  herdr tab rename "$t1" cchunk >/dev/null
  p2=$(herdr pane split "$p1" --direction right --ratio 0.5 --cwd "$dir" --no-focus | jq -r '.result.pane.pane_id // empty')
  herdr pane run "$p1" "claude" >/dev/null
  [[ -n $p2 ]] && herdr pane run "$p2" "hunk diff --watch" >/dev/null
  p3=$(herdr tab create --workspace "$ws" --cwd "$dir" --label nvim --no-focus | jq -r '.result.root_pane.pane_id // empty')
  [[ -n $p3 ]] && herdr pane run "$p3" "nvim" >/dev/null
}

# ==================================================
# Ghostty ヘルパー関数
# ==================================================
## gdev: 指定ディレクトリで垂直分割（左: nvim, 右: Claude Code）
## 実装は bin/gdev を参照
source "$HOME/.local/bin/gdev"

## cd ごとにウィンドウタイトルを更新（git リポジトリ名 > cwd ベース名）
## Mission Control 上で Ghostty ウィンドウを見分けやすくする用途
##
## NOTE: 変数名に `path` を使うと zsh の特殊変数（PATH と連動する配列）と衝突して
##       関数全体が極端に遅くなる（数秒〜十数秒）。必ず別名にすること。
autoload -Uz add-zsh-hook
_ghostty_set_title() {
  # stdout が端末でない（コマンド置換 $(cd ...) の中など）場合は何もしない。
  # エスケープ列が置換結果に混入してパス文字列等を壊すのを防ぐ
  [[ -t 1 ]] || return 0
  local repo_dir
  repo_dir=$(git rev-parse --show-toplevel 2>/dev/null) || repo_dir=$PWD
  printf '\e]2;%s\a' "${repo_dir##*/}"
}
add-zsh-hook chpwd _ghostty_set_title
_ghostty_set_title

# ==================================================
# gcloud 切り替え
# ==================================================
## gswitch: gcloud configuration + ADC を一括切り替え
## gswitch-setup: 新規 configuration の作成
source "$HOME/.local/bin/gswitch"
