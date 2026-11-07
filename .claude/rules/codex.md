---
paths:
  - ".codex/**"
  - "setup-codex-skills.py"
---

# Codex の管理方式

- `~/.codex/config.toml` は Codex アプリも更新するため symlink 不可。`.codex/scripts/apply-codex-config.py` がキー単位で冪等に追記・置換する（`setup.sh` から自動実行）
- Codex のカスタムテーマは `.codex/themes/` で管理し、`~/.codex/themes/` へファイル単位でリンクする
- Codex 個人スキルの入口は `.codex/skills/`、共通互換規約は `.codex/compatibility.md`、対応分類と正本ハッシュは `.codex/skill-bridge.json` で管理する。`python3 ~/dotfiles/setup-codex-skills.py --check` で検査し、`--apply` に替えて単独実行すると `~/.agents/skills/` へリンクする（`setup.sh` の再実行は不要）
- Codex 生ログ抽出・config.toml 更新・output style 同期・同等体験の一括点検・複数行 HUD は `.codex/scripts/`（`extract-session.py` / `apply-codex-config.py` / `sync-output-style.py` / `check-parity.sh` / `codex-hud.sh`）、共通フック2件（確認音・完了音）の追加定義は `.codex/hook-fragments/claude-parity.json`、Codex 専用のタブ内ステータス表示は `.codex/hook-fragments/codex-hud.json`。フックは既存 `~/.codex/hooks.json` の他イベントを保持して統合し、ユーザーが `/hooks` で trust する。`trusted_hash` を自作せず、fragment で設定全体を置換しない
- Codex の権限（Claude Code の `.claude/settings.json` permissions 相当）は `.codex/rules/claude-parity.rules`（execpolicy の prefix_rule）で管理し、`setup.sh` がシンボリックリンクする。Codex 自身が承認記憶として自動生成する `~/.codex/rules/default.rules` とは別ファイルで、そちらは編集しない
