local base = require("plugins.configs.lspconfig")
local on_attach = base.on_attach
local capabilities = base.capabilities

local lspconfig = require("lspconfig")

require'lspconfig'.clangd.setup({
  cmd       = { 'clangd', '--all-scopes-completion', '--background-index', '--completion-style=bundled', '--header-insertion=iwyu', '--clang-tidy' };
    filetypes = { 'c', 'h', 'cpp', 'cxx', 'hxx', 'objc', 'objcpp' },
    capabilities = capabilities
    })
require'lspconfig'.jsonls.setup{capabilities = capabilities}
require'lspconfig'.julials.setup{capabilities = capabilities}

lspconfig.pyright.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = {"python"},
})
