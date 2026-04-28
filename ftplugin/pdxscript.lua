vim.bo.tabstop    = 2
vim.bo.shiftwidth = 2
vim.bo.expandtab  = true
vim.opt_local.smartindent = false  -- prevent # jumping to column 0

local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set("n", "<leader>dm", function()
  vim.lsp.buf.code_action({
    filter = function(a) return a.kind == "quickfix" end,
    apply = true,
  })
end, { buffer = bufnr, desc = "PDX: apply De Morgan transform" })

-- Start the appropriate pdxscript-lsp binary for this mod.
require("pdxscript.lsp").maybe_start(bufnr)
