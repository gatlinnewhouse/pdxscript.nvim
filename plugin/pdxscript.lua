if vim.g.loaded_pdxscript then
	return
end
vim.g.loaded_pdxscript = true

local function pdx()
	return require("pdxscript")
end

-- Ensure filetype detection when buffer first displayed (Trouble, quickfix, picker)
vim.api.nvim_create_autocmd("BufWinEnter", {
	group = vim.api.nvim_create_augroup("pdxscript_winenter", { clear = true }),
	pattern = { "*.txt", "*.gui" },
	callback = function(ev)
		if vim.bo[ev.buf].filetype == "" then
			vim.api.nvim_buf_call(ev.buf, function()
				vim.cmd("filetype detect")
			end)
		end
	end,
})

-- Format + strip trailing whitespace + ensure modeline on save
vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("pdxscript_write", { clear = true }),
	pattern = { "*.txt", "*.gui" },
	callback = function(ev)
		if vim.bo[ev.buf].filetype ~= "pdxscript" then
			return
		end
		local M = pdx()
		M.ensure_modeline(ev.buf)
		M.format_buffer(ev.buf)
		local view = vim.fn.winsaveview()
		vim.cmd([[%s/\s\+$//e]])
		vim.fn.winrestview(view)
	end,
})
