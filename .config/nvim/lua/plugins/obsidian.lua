-- Obsidian vault 内の [[wikilink]] を gd でジャンプできるようにする
-- https://github.com/obsidian-nvim/obsidian.nvim（コミュニティフォーク。epwalsh 版は開発停滞）
--
-- 導入目的は「リンクジャンプだけ」なので、UI 装飾・デイリーノート等は全部オフの最小構成。
--
-- gd が動く仕組み: このプラグインは vault 内の markdown バッファに in-process LSP
-- （obsidian-ls）を attach し、definitionProvider を宣言する。
-- NOTE: AstroNvim 標準の gd（astrolsp.lua）は astrolsp の on_attach 経路でしか
-- 張られず、プラグインが直接起動する obsidian-ls には効かない（2026-08-12 実測）。
-- そのため下の init で LspAttach を拾い、バッファローカルに自前で張る。
-- ほかに <CR>（smart_action: リンク上なら follow）と :Obsidian follow_link も使える。
--
-- NOTE: markdown バッファは treesitter を全停止している（after/ftplugin/markdown.lua）が、
-- リンク解決の経路（cursor_link → parse_refs.extract → LSP definition）は行文字列の
-- 独自パースで treesitter 非依存（2026-08-12 にソース確認済み）。render-markdown.nvim の
-- ようなクラッシュは構造的に起きない。vim.treesitter を呼ぶのはコードフェンス内での
-- チェックボックス誤爆防止 1 箇所だけで、パーサ不在時は静かにスキップされる。
return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  init = function()
    -- obsidian-ls が attach した vault 内バッファだけにキーマップと conceal を仕込む
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("obsidian_keymaps", { clear = true }),
      callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or client.name ~= "obsidian-ls" then return end
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end,
          { buffer = ev.buf, desc = "wikilink 先のノートへジャンプ" })
        -- gd で飛んだあと gd 元へ戻る（ジャンプリストを1つ戻る = <C-o> 相当）
        vim.keymap.set("n", "go", "<C-o>", { buffer = ev.buf, desc = "ジャンプ元へ戻る" })
        -- NOTE: ui.enable = true にする場合はここに vim.opt_local.conceallevel = 2 を足す
        -- （UI 装飾の conceal 表示に必要。2026-08-12 に一度試して「無くていい」で外した）
      end,
    })
  end,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- 旧 :ObsidianXxx コマンド形式は使わない（4.0.0 で削除予定）
    workspaces = {
      { name = "ObsidianImus", path = "~/repos/imutaakihiro/ObsidianImus" },
    },
    -- vault 外の markdown では何もしない（workspace 判定で自動的に不活性）

    -- ---- ここから機能の取捨選択 ----
    -- UI 装飾（[[パス|別名]] の別名だけ表示・チェックボックスのアイコン化・•バレット等）:
    -- 2026-08-12 に一度 true で試し、「悪くないが必要ない」判断でオフに戻した。
    -- 再度試すなら enable = true ＋ 上の init の conceallevel も戻すこと。
    -- treesitter 非依存（extmark 自前スキャン）なのでクラッシュリスクは無い。
    ui = { enable = false },
    daily_notes = { enabled = false }, -- デイリーノートは Obsidian 本体と /morning の領分
    templates = { enabled = false },
    footer = { enabled = false }, -- ステータス行のノート情報表示
    checkbox = { enabled = false }, -- treesitter 停止中はフェンス内誤爆防止が効かないため切る
    -- 補完（[[ の入力補完）: cmp/blink 側で markdown に LSP ソースを足さない限り
    -- 何も出ないので、無効化設定は不要
  },
}
