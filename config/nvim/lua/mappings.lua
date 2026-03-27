require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

local function tag_matches(word)
  local ok, matches = pcall(vim.fn.taglist, word)
  if not ok or type(matches) ~= "table" then
    return {}
  end

  return matches
end

local function goto_definition()
  local word = vim.fn.expand "<cword>"
  local clients = vim.lsp.get_clients { bufnr = 0 }

  if #clients > 0 then
    vim.lsp.buf.definition()
    return
  end

  local matches = tag_matches(word)
  local cmd = "tjump " .. vim.fn.fnameescape(word)

  if vim.bo.filetype == "fortran" and #matches > 1 then
    cmd = "tselect " .. vim.fn.fnameescape(word)
  end

  local ok = pcall(vim.cmd, cmd)
  if not ok then
    vim.notify("No tag found for '" .. word .. "'", vim.log.levels.WARN)
  end
end

local function select_tag()
  local word = vim.fn.expand "<cword>"
  local matches = tag_matches(word)

  if #matches == 1 then
    vim.cmd("tjump " .. vim.fn.fnameescape(word))
    return
  end

  local ok = pcall(vim.cmd, "tselect " .. vim.fn.fnameescape(word))
  if not ok then
    vim.notify("No tag found for '" .. word .. "'", vim.log.levels.WARN)
  end
end

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "==", "<cmd>lua vim.lsp.buf.format(range)<CR>", {desc = "Format selection"})

map("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", {desc = "Format selection"})
map("n", "<leader>cr", "<cmd>lua vim.lsp.buf.rename()<CR>", {desc = "rename variable"})
map("n", "<leader>cd", goto_definition, { desc = "go to definition" })
map("n", "<leader>ct", select_tag, { desc = "select tag definition" })

map("n", "<leader>cs", "<cmd> nohl <CR>", {desc = "Remove highlights"})

map('n', '<leader>gp', "<cmd> Gitsigns preview_hunk_inline <CR>", { desc = "Preview hunk inline" })
map('n', '<leader>gr', "<cmd> Gitsigns reset_hunk <CR>", { desc = "reset hunk" })
map('n', '<leader>gb', "<cmd> Gitsigns blame_line <CR>", { desc = "blame line" })
map('n', '<leader>gj', "<cmd> Gitsigns next_hunk <CR>", { desc = "next git change" })
map('n', '<leader>gk', "<cmd> Gitsigns prev_hunk <CR>", { desc = "previous git change" })

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
