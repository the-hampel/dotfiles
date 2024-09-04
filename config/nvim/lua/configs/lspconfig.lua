-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

-- EXAMPLE
local servers = { "html", "cssls" }
local nvlsp = require "nvchad.configs.lspconfig"

local on_attach = nvlsp.on_attach
local capabilities = nvlsp.capabilities
local on_init = nvlsp.on_init

require'lspconfig'.clangd.setup({
  cmd       = { 'clangd', '--all-scopes-completion', '--background-index', '--completion-style=bundled', '--header-insertion=iwyu', '--clang-tidy' };
    filetypes = { 'c', 'h', 'cpp', 'cxx', 'hxx', 'objc', 'objcpp' },
    capabilities = capabilities,
    on_attach = on_attach,
    })

require'lspconfig'.jsonls.setup{capabilities = capabilities}
require'lspconfig'.julials.setup{capabilities = capabilities}
-- require'lspconfig'.ruff_lsp.setup{capabilities = capabilities, on_init = on_init, on_attach = on_attach}
require'lspconfig'.ruff_lsp.setup{}
require'lspconfig'.fortls.setup{}
-- lsps with default config
-- for _, lsp in ipairs(servers) do
--   lspconfig[lsp].setup {
--     on_attach = nvlsp.on_attach,
--     on_init = nvlsp.on_init,
--     capabilities = nvlsp.capabilities,
--   }
-- end

-- configuring single server, example: typescript
-- lspconfig.tsserver.setup {
--   on_attach = nvlsp.on_attach,
--   on_init = nvlsp.on_init,
--   capabilities = nvlsp.capabilities,
-- }
