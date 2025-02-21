require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
--
vim.opt.mouse = ""

vim.opt.spell = true

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*.py", "*.cpp", "*.txt", "" },
  command = [[%s/\s\+$//e]],
})


vim.api.nvim_create_autocmd({ "BufRead",  "BufNewFile" }, {
  pattern = { "*.pf" },
  command = "set filetype=fortran",
})

vim.opt.diffopt =
  'filler,vertical,internal,algorithm:patience,indent-heuristic,context:3'

vim.opt.fillchars = {
  fold = ' ',
  diff = '╱',
  wbr = '─',
  msgsep = '─',
  horiz = ' ',
  horizup = '│',
  horizdown = '│',
  vertright = '│',
  vertleft = '│',
  verthoriz = '│',
}

--
