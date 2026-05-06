vim.filetype.add({
	pattern = {
		[".*/common/.*%.txt"] = "pdxscript",
		[".*/events/.*%.txt"] = "pdxscript",
		[".*/gui/.*%.gui"] = "pdxscript",
		[".*/scripted_.*/.*%.txt"] = "pdxscript",
	},
})

vim.opt.modeline = true
vim.opt.modelines = 3
