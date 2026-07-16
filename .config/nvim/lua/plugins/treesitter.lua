-- Treesitter: 構文解析エンジン
-- コードの構文ハイライト・インデント・テキストオブジェクトを大幅に強化する
-- render-markdown.nvim など多くのプラグインも依存している

-- NOTE: markdown 系は treesitter ハイライトを切っている。
-- nvim-treesitter master ブランチは 2025-05-18 に archived。
-- Neovim 0.12.1 の treesitter API 変更（node が nil を返すケース）に追従できず
-- md を開くと highlighter.lua:580 で range() nil クラッシュが出る。
-- 本丸の解決策は main ブランチ移行 or Neovim 0.11 へのダウングレード。
--
-- nvim-treesitter の highlight.disable / FileType autocmd では
-- 組み込み ftplugin 経由の vim.treesitter.start() を止められないため、
-- start 関数自体を monkey-patch して markdown を no-op にする。
do
  local orig_start = vim.treesitter.start
  vim.treesitter.start = function(bufnr, lang)
    local buf = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
    if ft == "markdown" or ft == "markdown_inline" or lang == "markdown" or lang == "markdown_inline" then
      return
    end
    return orig_start(bufnr, lang)
  end
end

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      -- === 基本 ===
      "lua",        -- Neovim 設定ファイル
      "vim",        -- Vim script
      "vimdoc",     -- Neovim ヘルプドキュメント
      "bash",       -- シェルスクリプト

      -- === バックエンド ===
      "go",         -- Go
      "gomod",      -- go.mod
      "python",     -- Python
      "sql",        -- SQL（PostgreSQL / MySQL / SQLite 等）

      -- === フロントエンド ===
      "typescript", -- TypeScript
      "javascript", -- JavaScript
      "tsx",        -- React (TypeScript / JavaScript)
      "html",       -- HTML
      "css",        -- CSS
      "json",       -- JSON
      "yaml",       -- YAML

      -- === ドキュメント ===
      -- markdown / markdown_inline はクラッシュ対策で除外
    },
    -- コードに合わせて自動インデント
    indent = { enable = true },
    -- markdown 系はハイライトをアタッチさせない
    highlight = {
      enable = true,
      disable = { "markdown", "markdown_inline" },
    },
  },
  init = function()
    -- nvim-treesitter 以外の経路（built-in ftplugin, 他プラグイン）から
    -- vim.treesitter.start() されたとき用の保険
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "markdown", "markdown.mdx" },
      callback = function(args)
        vim.schedule(function() pcall(vim.treesitter.stop, args.buf) end)
      end,
    })
  end,
}
