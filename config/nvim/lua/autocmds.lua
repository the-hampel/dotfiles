require "nvchad.autocmds"

-- Restore cursor to last position when reopening files.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("RestoreCursor", { clear = true }),
  callback = function()
    local last = vim.fn.line([['"]])
    if last > 1
        and last <= vim.fn.line("$")
        and vim.bo.buftype == ""
        and vim.bo.filetype ~= "gitcommit"
        and vim.bo.filetype ~= "gitrebase" then
      pcall(vim.api.nvim_win_set_cursor, 0, { last, 0 })
    end
  end,
})
