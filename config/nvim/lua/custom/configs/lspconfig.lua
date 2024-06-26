local base = require("plugins.configs.lspconfig")
local on_attach = base.on_attach
local capabilities = base.capabilities
local on_init = base.on_init

local lspconfig = require("lspconfig")

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
