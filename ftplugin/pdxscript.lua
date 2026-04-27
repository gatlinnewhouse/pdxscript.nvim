vim.bo.tabstop    = 2
vim.bo.shiftwidth = 2
vim.bo.expandtab  = true
vim.opt_local.smartindent = false  -- prevent # jumping to column 0

local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set("n", "<leader>dm", function()
  require("pdxscript").fix_at_cursor(bufnr)
end, { buffer = bufnr, desc = "PDX: apply De Morgan transform" })
