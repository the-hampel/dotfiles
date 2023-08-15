local M = {}

M.dap = {
  plugin = true,
  n = {
    ["<leader>db"] = {
      "<cmd> DapToggleBreakpoint <CR>",
      "Add breakpoint at line",
    },
    ["<leader>dr"] = {
      "<cmd> DapContinue <CR>",
      "Start or continue the debugger",
    }
  }
}

-- Your custom mappings
M.abc = {
  n = {
    -- ["<leader>c"]
  ["=="] = {
      "<cmd>lua vim.lsp.buf.format(range)<CR>",
      "Format selection"}
  },

  i = {
    -- 
  }
}
return M
