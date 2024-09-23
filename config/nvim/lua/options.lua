require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
--
vim.opt.mouse = ""

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*.py", "*.cpp", "*.txt", "*.md" },
  command = [[%s/\s\+$//e]],
})


vim.api.nvim_create_autocmd({ "BufRead",  "BufNewFile" }, {
  pattern = { "*.pf" },
  command = "set filetype=fortran",
})

--
