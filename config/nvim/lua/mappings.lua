require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "==", "<cmd>lua vim.lsp.buf.format(range)<CR>", {desc = "Format selection"})

map("n", "<leader>cs", "<cmd> nohl <CR>", {desc = "Remove highlights"})

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
