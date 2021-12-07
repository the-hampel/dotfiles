set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

set completeopt=menu,menuone,noselect
" ---- Language Server Setup -----

lua << EOF
 
 -- Setup nvim-cmp.
  local cmp = require'cmp'

  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
        -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
        -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
        -- require'snippy'.expand_snippet(args.body) -- For `snippy` users.
      end,
    },
    mapping = {
      ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
      ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
      ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
      ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' }),
      ['<C-y>'] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
      ['<C-e>'] = cmp.mapping({
        i = cmp.mapping.abort(),
        c = cmp.mapping.close(),
      }),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
    },
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'vsnip' }, -- For vsnip users.
      -- { name = 'luasnip' }, -- For luasnip users.
      -- { name = 'ultisnips' }, -- For ultisnips users.
      -- { name = 'snippy' }, -- For snippy users.
    }, {
      { name = 'buffer' },
    })
  })

  -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline('/', {
    sources = {
      { name = 'buffer' }
    }
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    sources = cmp.config.sources({
      { name = 'path' }
    }, {
      { name = 'cmdline' }
    })
  })

local signs = { Error = " ", Warning = " ", Hint = " ", Information = " " }
for type, icon in pairs(signs) do
    local hl = "LspDiagnosticsSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  virtual_text = {
    prefix = '▎', -- Could be '●', '▎', 'x'
    severity_limit = 'Error'
  },
  signs = { severity_limit = 'Warning' },
  underline = { severity_limit = 'Error' },
  update_in_insert = true,
  severity_sort = true
})

-- You will likely want to reduce updatetime which affects CursorHold
-- note: this setting is global and should be set only once
vim.o.updatetime = 200
vim.cmd [[autocmd CursorHold * lua vim.lsp.diagnostic.show_line_diagnostics({focusable=false})]]


  -- Setup lspconfig.
  local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
  -- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
  require('lspconfig')['pylsp'].setup {capabilities = capabilities}
  -- require('lspconfig')['pyright'].setup {capabilities = capabilities}
  require'lspconfig'.clangd.setup({
  cmd       = { 'clangd', '--all-scopes-completion', '--background-index', '--completion-style=bundled', '--header-insertion=iwyu', '--clang-tidy' };
    filetypes = { 'c', 'h', 'cpp', 'cxx', 'hxx', 'objc', 'objcpp' },
    capabilities = capabilities
    })
  require'lspconfig'.bashls.setup{capabilities = capabilities}
  require'lspconfig'.jsonls.setup{capabilities = capabilities}
  require'lspconfig'.julials.setup{capabilities = capabilities}

EOF

autocmd Syntax c,cpp,python,julia,bash nnoremap <buffer> gD <cmd>lua vim.lsp.buf.declaration()<CR>
autocmd Syntax c,cpp,python,julia,bash nnoremap <buffer> gd <cmd>lua vim.lsp.buf.definition()<CR>
autocmd Syntax c,cpp,python,julia,bash xnoremap <buffer> gd <cmd>lua vim.lsp.buf.definition()<CR>
autocmd Syntax c,cpp,python,julia,bash nnoremap <buffer> <C-h> <cmd>lua vim.lsp.buf.rename()<CR>
autocmd Syntax c,cpp,python,julia,bash xnoremap <buffer> <C-h> <cmd>lua vim.lsp.buf.rename()<CR>
autocmd Syntax c,cpp,python,julia,bash nnoremap <buffer> == <cmd>lua vim.lsp.buf.formatting()<CR>
autocmd Syntax c,cpp,python,julia,bash xnoremap <buffer> == <cmd>lua vim.lsp.buf.range_formatting()<CR>

autocmd Syntax c,cpp nnoremap <Leader>of :ClangdSwitchSourceHeader<cr>

" Other useful lsp commands
" "vim.lsp.diagnostic.goto_prev()
" "vim.lsp.diagnostic.goto_next()
" "vim.lsp.buf.references()
" "vim.lsp.buf.range_formatting()
" "vim.lsp.buf.range_code_action()
" "vim.lsp.buf.hover()
