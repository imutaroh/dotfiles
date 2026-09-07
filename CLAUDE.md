# dotfiles

macOS 用の個人設定ファイル管理リポジトリ。
技術スタックとディレクトリ構成の詳細は README.md を参照。

## 管理方式

- `setup.sh` でシンボリックリンクを作成して各設定ファイルを適用する
- `.config/` 以下はミラーリング方式（実際の配置場所と同じ構造）で管理
- `~/.claude/` 自体は実ディレクトリで、`CLAUDE.md` / `skills` / `scripts` / `statusline.sh` / `themes` / `task-dashboard` のみが dotfiles へのシンボリックリンク
- `settings.json` は symlink 不可（`claude doctor` 等が実ファイルに置き換えるため）。`./sync-settings.sh` で実環境 → dotfiles へ明示的に取り込む
- `~/.codex/config.toml` は Codex アプリも更新するため symlink 不可。`setup.sh` で不足している設定だけ追記する
- Codex のカスタムテーマは `.codex/themes/` で管理し、`~/.codex/themes/` へファイル単位でリンクする
- Codex 個人スキルの入口は `.codex/skills/`、共通互換規約は `.codex/compatibility.md`、対応分類と正本ハッシュは `.codex/skill-bridge.json` で管理する。`python3 ~/dotfiles/setup-codex-skills.py --check` で検査し、`--apply` に替えて単独実行すると `~/.agents/skills/` へリンクする（`setup.sh` の再実行は不要）
- Codex 生ログ抽出は `.codex/scripts/`、共通フック3件の追加定義は `.codex/hook-fragments/claude-parity.json`。フックは既存 `~/.codex/hooks.json` の他イベントを保持して統合し、ユーザーが `/hooks` で trust する。`trusted_hash` を自作せず、fragment で設定全体を置換しない
- `.claude/settings.local.json` はこのリポジトリ固有の設定として使える（gitignore 対象外・設定の優先順位は user < project < local）
- `launchd/*.plist` は常駐エージェント定義。`setup.sh` が `~/Library/LaunchAgents/` へコピーし `launchctl bootstrap` でロードする（symlink ではなくコピー）

## 作業ルール

- シンボリックリンクで管理されるファイルは直接編集しない
- ディレクトリ構造を変更した場合は CLAUDE.md と README.md の整合性を確認・更新する
- コミット前に機密情報（APIキー、トークン等）が含まれていないか確認する

## スキル管理ルール

- スキルは必ずディレクトリ形式で作成する。Claude 本文正本は `.claude/skills/skill-name/SKILL.md`、Codex 互換入口は `.codex/skills/skill-name/SKILL.md` に置き、本文を複製せず正本を実行時参照する
- `.skill` 単一ファイル形式は使わない
- 既存の `.skill` ファイルをディレクトリ形式に移行した場合は、古い `.skill` ファイルを即削除する

## リポジトリ配置

- ローカルリポジトリは `~/repos/<owner>/` で管理（オーナー別に整理）
  - 個人リポジトリ: `~/repos/imutaakihiro/`
  - 会社・組織のリポジトリ: `~/repos/<組織名>/`
- dotfiles のみ例外として `~/dotfiles/` に配置
- Obsidian Vault: `~/repos/imutaakihiro/ObsidianImus/`
