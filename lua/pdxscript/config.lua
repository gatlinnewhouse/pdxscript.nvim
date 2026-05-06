-- lua/pdxscript/config.lua
-- Merges vim.g.pdxscriptvim (user/distro) with built-in defaults.
-- User config wins; defaults fill gaps.
local M = {}

local defaults = {
	server = {
		-- Directory containing pdxscript-lsp-* binaries.
		-- Override to your build dir or ~/.local/bin/, etc.
		bin_dir = vim.fn.expand("~/.local/bin/"),
		-- auto_attach: true|false|function(bufnr)->bool
		auto_attach = true,
		-- Called after LSP attaches. Receives (client, bufnr).
		on_attach = nil,
		settings = {},
		-- Extra environment variables passed to the LSP server process.
		-- e.g. { RUST_BACKTRACE = "1" }
		cmd_env = {},
	},
}

function M.get()
	return vim.tbl_deep_extend("keep", vim.g.pdxscriptvim or {}, defaults)
end

return M
