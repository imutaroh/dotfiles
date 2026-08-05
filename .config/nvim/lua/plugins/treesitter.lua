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
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)

    -- === Neovim 0.12 互換シム ===
    -- 0.12 で add_predicate/add_directive の `all = false` 互換処理が削除され、
    -- ハンドラには常に「キャプチャID → ノードの配列」が渡るようになった。
    -- master ブランチ（archived）のハンドラは単一ノード前提のため、
    -- markdown injection のパース時などに range() nil でクラッシュする。
    -- ここで新形式対応版を force 再登録して上書きする。
    local query = vim.treesitter.query
    local force = { force = true }

    -- 旧形式（単一ノード）は最後のキャプチャノードを返していたので、それに合わせる
    local function pick_node(match, id)
      local nodes = match[id]
      if type(nodes) == "userdata" then return nodes end -- 旧形式で呼ばれた場合の保険
      return nodes and nodes[#nodes] or nil
    end

    query.add_predicate("nth?", function(match, _, _, pred)
      local node = pick_node(match, pred[2])
      local n = tonumber(pred[3])
      if node and node:parent() and node:parent():named_child_count() > n then
        return node:parent():named_child(n) == node
      end
      return false
    end, force)

    query.add_predicate("is?", function(match, _, bufnr, pred)
      local locals = require "nvim-treesitter.locals"
      local node = pick_node(match, pred[2])
      if not node then return true end
      local _, _, kind = locals.find_definition(node, bufnr)
      return vim.tbl_contains({ unpack(pred, 3) }, kind)
    end, force)

    query.add_predicate("kind-eq?", function(match, _, _, pred)
      local node = pick_node(match, pred[2])
      if not node then return true end
      return vim.tbl_contains({ unpack(pred, 3) }, node:type())
    end, force)

    local html_script_type_languages = {
      ["importmap"] = "json",
      ["module"] = "javascript",
      ["application/ecmascript"] = "javascript",
      ["text/ecmascript"] = "javascript",
    }
    query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
      local node = pick_node(match, pred[2])
      if not node then return end
      local type_attr_value = vim.treesitter.get_node_text(node, bufnr)
      local configured = html_script_type_languages[type_attr_value]
      if configured then
        metadata["injection.language"] = configured
      else
        local parts = vim.split(type_attr_value, "/", {})
        metadata["injection.language"] = parts[#parts]
      end
    end, force)

    local injection_aliases = { ex = "elixir", pl = "perl", sh = "bash", uxn = "uxntal", ts = "typescript" }
    query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
      local node = pick_node(match, pred[2])
      if not node then return end
      local alias = vim.treesitter.get_node_text(node, bufnr):lower()
      metadata["injection.language"] = vim.filetype.match { filename = "a." .. alias }
        or injection_aliases[alias]
        or alias
    end, force)

    query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
      local id = pred[2]
      local node = pick_node(match, id)
      if not node then return end
      local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
      if not metadata[id] then metadata[id] = {} end
      metadata[id].text = string.lower(text)
    end, force)

    -- === 安全網 ===
    -- snacks picker（<Leader>fl の lines 等）は treesitter で自前パースするため、
    -- 今後未知のクラッシュが起きてもエラーではなく「ハイライトなし」に格下げする
    local ok_hl, hl = pcall(require, "snacks.picker.util.highlight")
    if ok_hl and not hl._safe_wrapped then
      hl._safe_wrapped = true
      local orig = hl.get_highlights
      hl.get_highlights = function(...)
        local ok, ret = pcall(orig, ...)
        return ok and ret or {}
      end
    end
  end,
}
