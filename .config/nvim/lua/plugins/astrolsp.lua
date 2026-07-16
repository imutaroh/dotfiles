-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`

-- 同一バッファに同じ名前の LSP が複数アタッチされたら、新しい方を自動停止する保険。
-- 原因（neoconf / project.nvim / cwd 切替など）が何であれ症状を確実に止める。
local function setup_dedup_lsp()
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local attaching = vim.lsp.get_client_by_id(args.data.client_id)
      if not attaching then return end
      for _, client in ipairs(vim.lsp.get_clients { bufnr = args.buf }) do
        if client.id ~= attaching.id and client.name == attaching.name then
          -- 同じバッファに同名 LSP が既にいる → 新しく来た方を止める
          vim.schedule(function()
            vim.notify(
              ("[lsp-dedup] %s (id=%d) を停止: 既に id=%d がアタッチ済み"):format(
                attaching.name, attaching.id, client.id),
              vim.log.levels.INFO
            )
            vim.lsp.stop_client(attaching.id)
          end)
          break
        end
      end
    end,
  })
end
setup_dedup_lsp()

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      codelens = true,
      inlay_hints = false,
      semantic_tokens = true,
    },
    formatting = {
      format_on_save = {
        enabled = true,
        allow_filetypes = {
          "go", -- Go は保存時に自動フォーマット
        },
      },
      disabled = {
        "lua_ls", -- Lua は stylua でフォーマットするため無効化
      },
      timeout_ms = 1000,
    },
    -- Mason で自動インストールするサーバー
    servers = {
      "gopls",      -- Go
      "ts_ls",      -- TypeScript / JavaScript
      "pyright",    -- Python
      "lua_ls",     -- Lua（Neovim 設定ファイル用）
      "cssls",      -- CSS
      "html",       -- HTML
      "sqlls",      -- SQL（補完・定義ジャンプ・診断）
      "dbt_ls",     -- dbt（macro/ref の定義ジャンプ・補完。go install で手動インストール）
    },
    config = {
      -- Go: 静的解析・フォーマットを強化
      gopls = {
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
            gofumpt = true,
          },
        },
      },
      -- dbt: j-clemons/dbt-language-server（Mason 非対応のため cmd を絶対パス指定）
      -- dbt_project.yml があるプロジェクト内でのみ起動する
      -- root_dir は旧 lspconfig 経路用、root_markers は将来の native 経路移行用に両方持つ
      dbt_ls = {
        cmd = { vim.fn.expand "~/go/bin/dbt-language-server" },
        filetypes = { "sql", "yaml" },
        root_dir = function(fname) return vim.fs.root(fname, { "dbt_project.yml" }) end,
        root_markers = { "dbt_project.yml" },
      },
      -- Python: 型チェックを基本レベルで有効化
      pyright = {
        settings = {
          python = {
            analysis = { typeCheckingMode = "basic" },
          },
        },
      },
    },
    mappings = {
      n = {
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "宣言へジャンプ",
          cond = "textDocument/declaration",
        },
        gd = {
          function() vim.lsp.buf.definition() end,
          desc = "定義へジャンプ",
          cond = "textDocument/definition",
        },
        gI = {
          function() vim.lsp.buf.implementation() end,
          desc = "実装へジャンプ",
          cond = "textDocument/implementation",
        },
        gr = {
          function() vim.lsp.buf.references() end,
          desc = "シンボルの参照一覧",
          cond = "textDocument/references",
        },
        gy = {
          function() vim.lsp.buf.type_definition() end,
          desc = "型定義へジャンプ",
          cond = "textDocument/typeDefinition",
        },
        gK = {
          function() vim.lsp.buf.signature_help() end,
          desc = "シグネチャヘルプ",
          cond = "textDocument/signatureHelp",
        },
        gl = {
          function() vim.diagnostic.open_float() end,
          desc = "診断（エラー詳細）を表示",
        },
      },
    },
  },
}
