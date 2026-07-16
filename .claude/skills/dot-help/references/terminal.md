# Ghostty × herdr の2層キーバインド構造

ターミナルのキーバインドは2層になっている。質問がどちらの層の話かを最初に見極める。

```
Ghostty（ターミナルエミュレータ）
  └─ keybind = super+◯=text:\x11◯ で Cmd キーを「ctrl+q + キー」のバイト列に変換して送信
       └─ herdr（AIエージェント用ワークスペースマネージャ。tmux 相当）
            └─ prefix = ctrl+q(\x11) + キー で各アクションを実行
```

- **Ghostty 層**: `~/dotfiles/.config/ghostty/config` の `keybind =` 行。`text:\x11◯` 形式は herdr への転送、それ以外（`toggle_quick_terminal` 等）は Ghostty 自身の機能
- **herdr 層**: `~/.config/herdr/config.toml` の `[keys]` セクション（**dotfiles 未ミラーの例外**）。`prefix+◯` が実際のアクション定義
- Cmd+◯ の意味を答えるには: Ghostty 側で `\x11` の後の文字を特定 → herdr 側でその `prefix+文字` が何かを引く、の2段照合が必要

## herdr の構造モデル

```
Space（ワークスペース）= プロジェクトの部屋
 └─ タブ └─ ペイン ← エージェントはペインで動く「住人」（階層ではない）
```

サイドバーの Agents は全 Space 横断の名簿ビュー。移動は「場所ベース（Space picker / タブ番号）」と「相手ベース（goto 曖昧検索 / 通知直行）」の2系統で運用する方針。

## 既知のハマりどころ

- Ghostty の Cmd+数字は**物理キー名 `digit_N`** で定義する必要がある（論理キー名 `one` 等ではデフォルトの `super+digit_N=goto_tab:N` に負ける）
- Ghostty の設定変更は **Cmd+Shift+,** でリロードするまで反映されない
- `text:\x11◯` に潰された Cmd キーは herdr の外（素のシェル・SSH先）では実質無効
- Ghostty ネイティブのタブ/ウィンドウ機能は意図的に潰してある（タブ管理は herdr に一本化する方針）
- 検証コマンド: `/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config` と `+list-keybinds`（デフォルト含む最終的な割当一覧が出る）
- herdr 内の全キーバインド一覧は `Ctrl+Q → ?`。設定リロードは `herdr server reload-config`

## キーの覚え方の体系（ユーザーの設計方針）

文字の連想で覚える: S=**S**paces, G=**G**oto, O=**O**pen notification, E=Explorer（nvim の `<leader>e` と同じ連想）, T=**T**ab, D=**D**ivide, W=close の macOS 慣習（Shift で大きい単位を閉じる）, H/J/K/L=vim。
具体の割当は必ず実ファイルを読んで答える（このファイルには書かない。陳腐化するため）。
