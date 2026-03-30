require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
--
vim.opt.mouse = ""

vim.opt.spell = true

vim.g.fortran_free_source = 1
vim.g.fortran_have_tabs = 1
vim.g.fortran_more_precise = 1
vim.g.fortran_do_enddo = 1
vim.g.fortran_CUDA = 1

vim.filetype.add {
  extension = {
    pf = "fortran",
  },
}

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*.py", "*.cpp", "*.txt", "" },
  command = [[%s/\s\+$//e]],
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

vim.opt.list = true
vim.opt.listchars:append { trail = "·", tab = "▸ " }
--
