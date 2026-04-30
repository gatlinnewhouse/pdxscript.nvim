-- lua/pdxscript/lsp.lua
-- Detects which Paradox game owns the current mod and starts the matching
-- pdxscript-lsp binary via vim.lsp.start(). No lspconfig dependency.
local M = {}

-- *-tiger.conf filename → binary suffix
local GAMES = {
  ["vic3-tiger.conf"]      = "pdxscript-lsp-vic3",
  ["ck3-tiger.conf"]       = "pdxscript-lsp-ck3",
  ["imperator-tiger.conf"] = "pdxscript-lsp-imperator",
  ["hoi4-tiger.conf"]      = "pdxscript-lsp-hoi4",
  ["eu5-tiger.conf"]       = "pdxscript-lsp-eu5",
}

-- Walk up from `path` looking for a *-tiger.conf.
-- Returns (mod_root, bin_name) or (nil, nil).
local function find_mod_root(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  while true do
    for conf, bin in pairs(GAMES) do
      if vim.fn.filereadable(dir .. "/" .. conf) == 1 then
        return dir, bin
      end
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end
  return nil, nil
end

-- Set up highlight groups once at startup and re-apply on colorscheme changes.
local _hl_setup_done = false
local function ensure_highlights()
  if _hl_setup_done then return end
  _hl_setup_done = true
  require("pdxscript").setup_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function() require("pdxscript").setup_highlights() end,
    desc = "Re-apply pdxscript highlight groups after colorscheme change",
  })
end

-- Start (or reuse) the LSP for `bufnr`. Called from ftplugin/pdxscript.lua.
function M.maybe_start(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = require("pdxscript.config").get()
  local server = cfg.server or {}

  -- Honour auto_attach setting
  local auto = server.auto_attach
  if auto == false then return end
  if type(auto) == "function" and not auto(bufnr) then return end

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then return end

  local mod_root, bin_name = find_mod_root(path)
  if not mod_root then return end

  local bin_dir = server.bin_dir or vim.fn.expand("~/.local/bin/")
  -- Normalise trailing slash
  if bin_dir:sub(-1) ~= "/" then bin_dir = bin_dir .. "/" end
  local cmd = bin_dir .. bin_name

  if vim.fn.executable(cmd) == 0 then
    vim.notify(
      "pdxscript-lsp: binary not found: " .. cmd,
      vim.log.levels.WARN,
      { title = "pdxscript.nvim" }
    )
    return
  end

  vim.lsp.start({
    name = "pdxscript-lsp",
    cmd  = { cmd },
    root_dir = mod_root,
    filetypes = { "pdxscript" },
    single_file_support = false,
    settings = server.settings or {},
    on_attach = function(client, buf)
      ensure_highlights()
      -- Explicitly start semantic token highlighting (required for vim.lsp.start clients).
      if client.server_capabilities.semanticTokensProvider then
        vim.lsp.semantic_tokens.start(buf, client.id)
      end
      if server.on_attach then
        server.on_attach(client, buf)
      end
    end,
  }, {
    bufnr = bufnr,
    -- Reuse the existing client if it's already serving this mod root.
    reuse_client = function(client, conf)
      return client.name == "pdxscript-lsp"
        and client.config.root_dir == conf.root_dir
    end,
  })
end

return M
