require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "==", "<cmd>lua vim.lsp.buf.format(range)<CR>", {desc = "Format selection"})

map("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", {desc = "Format selection"})
map("n", "<leader>cr", "<cmd>lua vim.lsp.buf.rename()<CR>", {desc = "rename variable"})
map("n", "<leader>cd", "<cmd>lua vim.lsp.buf.definition()<CR>", {desc = "go to definition"})

map("n", "<leader>cs", "<cmd> nohl <CR>", {desc = "Remove highlights"})

map('n', '<leader>gp', "<cmd> Gitsigns preview_hunk_inline <CR>", { desc = "Preview hunk inline" })
map('n', '<leader>gr', "<cmd> Gitsigns reset_hunk <CR>", { desc = "Preview hunk inline" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
