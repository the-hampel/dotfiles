-- filepath: config/nvim/lua/configs/lspconfig.lua
-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

-- Keep NvChad configs for compatibility
local nvlsp = require "nvchad.configs.lspconfig"

local on_attach = nvlsp.on_attach
local capabilities = nvlsp.capabilities
local on_init = nvlsp.on_init

-- Configure clangd using new vim.lsp.config API
vim.lsp.config.clangd = {
  cmd = { 'clangd', '--all-scopes-completion', '--background-index', '--completion-style=bundled', '--header-insertion=iwyu', '--clang-tidy' },
  filetypes = { 'c', 'h', 'cpp', 'cxx', 'hxx', 'objc', 'objcpp' },
  capabilities = capabilities,
  on_attach = on_attach,
}

-- Configure other LSP servers
vim.lsp.config.jsonls = {
  capabilities = capabilities
}

vim.lsp.config.julials = {
  capabilities = capabilities
}

vim.lsp.config.ruff = {}

-- Example server loop (if needed)
local servers = { "html", "cssls" }
for _, lsp in ipairs(servers) do
  vim.lsp.config[lsp] = {
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
  }
end
