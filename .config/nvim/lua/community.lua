-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  -- Go: gopls 補助・neotest-go（テストランナー）・dap-go（delve デバッグ）・gotests 等を同梱
  { import = "astrocommunity.pack.go" },
  -- import/override with your plugins folder
}
