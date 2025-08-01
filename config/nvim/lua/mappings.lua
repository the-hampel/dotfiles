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
map('n', '<leader>gr', "<cmd> Gitsigns reset_hunk <CR>", { desc = "reset hunk" })
map('n', '<leader>gb', "<cmd> Gitsigns blame_line <CR>", { desc = "blame line" })

map("n", "<leader>fs", "<cmd> set spell!<CR>", {desc = "Toggle spell checking", noremap = true, silent = true})
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- code companion
map("n", "<leader>ci", "<cmd> CodeCompanionChat Toggle<CR>", {desc = "Toggle CodeCompanion"})
map("v", "<leader>ci", "<cmd> CodeCompanion Chat<CR>", {desc = "chat about selection"})
map("v", "<leader>ca", function()
  local start_pos = vim.fn.getpos("'<")[2]
  local end_pos = vim.fn.getpos("'>")[2]
  vim.ui.input({prompt = "CodeCompanion prompt: "}, function(input)
    if input and input ~= "" then
      -- Build the range command
      vim.cmd(string.format("%d,%dCodeCompanion %s", start_pos, end_pos, input))
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    end
  end)
end, {desc = "CodeCompanion prompt"})
map({ "n", "v" }, "<leader>cA", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true, desc = "CodeCompanion Actions" })
