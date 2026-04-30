-- lua/pdxscript/init.lua
-- Editor concerns for Paradox script files: formatting and modeline insertion.
-- Validation and code actions are handled by pdxscript-lsp.
local M = {}

-- ─── FORMATTER ───────────────────────────────────────────────────────────────

function M.format_lines(lines)
  local result = {}
  local depth = 0

  for _, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")

    if trimmed == "" then
      table.insert(result, "")
    else
      local open_count, close_count, leading_closes = 0, 0, 0
      local in_string, found_non_brace = false, false

      for i = 1, #trimmed do
        local ch = trimmed:sub(i, i)
        if ch == '"' then
          in_string = not in_string
          found_non_brace = true
        elseif in_string then
        elseif ch == "#" then
          break
        elseif ch == "{" then
          open_count = open_count + 1
          found_non_brace = true
        elseif ch == "}" then
          close_count = close_count + 1
          if not found_non_brace then leading_closes = leading_closes + 1 end
        elseif not ch:match("%s") then
          found_non_brace = true
        end
      end

      local indent = math.max(0, depth - leading_closes)
      table.insert(result, string.rep("  ", indent) .. trimmed)
      depth = depth + open_count - close_count
      if depth < 0 then depth = 0 end
    end
  end

  return result
end

function M.format_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local formatted = M.format_lines(lines)
  if table.concat(lines, "\n") ~= table.concat(formatted, "\n") then
    local view = vim.fn.winsaveview()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
    vim.fn.winrestview(view)
  end
end

-- ─── SCOPE BREADCRUMB ────────────────────────────────────────────────────────

-- Icons for known pdxscript block keywords (Nerd Font required).
local SCOPE_ICONS = {
  -- Trigger/condition blocks
  trigger          = "󱐋",
  trigger_if       = "󱐋",
  trigger_else     = "󱐋",
  trigger_else_if  = "󱐋",
  -- Effect blocks
  effect           = "󱐌",
  immediate        = "󱐌",
  after            = "󱐌",
  on_accept        = "󱐌",
  on_decline       = "󱐌",
  on_pass          = "󱐌",
  on_fail          = "󱐌",
  -- Flow control
  option           = "󰒓",
  limit            = "󰈲",
  switch           = "󰔡",
  -- Conditionals
  ["if"]           = "󱉴",
  else_if          = "󱉴",
  ["else"]         = "󱉴",
  -- Logic
  AND              = "∧",
  OR               = "∨",
  NOT              = "¬",
  NOR              = "¬∨",
  NAND             = "¬∧",
  -- Named blocks
  modifier         = "󰆦",
  on_action        = "󰗀",
  -- Generic containers
  scripted_effect  = "󰊕",
  scripted_trigger = "󱐋",
}

-- Return the icon for a scope key, or a default block icon if unknown.
local function scope_icon(key)
  if SCOPE_ICONS[key] then return SCOPE_ICONS[key] end
  -- Event ids contain a dot (namespace.event_id)
  if key:find("%.") then return "󰉁" end
  -- Iterators: every_*, any_*, random_*, ordered_*
  if key:match("^every_") or key:match("^any_") or key:match("^random_") or key:match("^ordered_") then
    return "󰔱"
  end
  return "󰅩"  -- generic block
end

-- Walk upward from the cursor counting braces to find enclosing `key = {` scopes.
-- Returns a list of {icon, name} pairs from outermost to innermost, or nil if at top level.
-- Called on every statusline refresh so kept O(lines_above_cursor).
local function line_brace_counts(line)
  local opens, closes = 0, 0
  local in_str = false
  for i = 1, #line do
    local ch = line:sub(i, i)
    if ch == '"' then
      in_str = not in_str
    elseif not in_str then
      if ch == "#" then break end
      if ch == "{" then opens = opens + 1
      elseif ch == "}" then closes = closes + 1
      end
    end
  end
  return opens, closes
end

--- Returns a list of {icon, key, hl} triples from outermost to innermost enclosing block,
--- or nil if at top level. .hl is the highlight group name for the icon.
function M.get_scope_parts()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "pdxscript" then return nil end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_line, false)

  local depth = 0
  local parts = {}

  for i = #lines, 1, -1 do
    local line = lines[i]
    local opens, closes = line_brace_counts(line)

    depth = depth + closes
    for _ = 1, opens do
      depth = depth - 1
      if depth < 0 then
        local key = line:match("^%s*([%w_.:]+)%s*[<>!?]*=%s*{")
                 or line:match("^%s*([%w_.:]+)%s*{")
        if key then table.insert(parts, 1, { icon = scope_icon(key), key = key, hl = M.icon_hl(key) }) end
        depth = 0
      end
    end
  end

  return #parts > 0 and parts or nil
end

--- Returns a plain " > "-separated scope string (backward-compatible).
function M.get_scope()
  local parts = M.get_scope_parts()
  if not parts then return nil end
  local segs = {}
  for _, p in ipairs(parts) do
    table.insert(segs, p.key)
  end
  return table.concat(segs, " > ")
end

-- ─── HIGHLIGHT GROUPS ────────────────────────────────────────────────────────

-- Highlight groups for pdxscript icons in the statusline breadcrumb.
-- Link to existing semantic/treesitter groups so the colorscheme drives the palette.
local ICON_HLS = {
  PdxIconTrigger     = { link = "DiagnosticWarn" },       -- 󱐋  orange/yellow
  PdxIconEffect      = { link = "Function" },             -- 󱐌  blue/purple
  PdxIconOption      = { link = "String" },               -- 󰒓  green
  PdxIconLimit       = { link = "@keyword.conditional" }, -- 󰈲  keyword color
  PdxIconConditional = { link = "@keyword.conditional" }, -- 󱉴  if/else
  PdxIconLogic       = { link = "Operator" },             -- ∧∨¬
  PdxIconModifier    = { link = "@type" },                -- 󰆦  type color
  PdxIconIterator    = { link = "@keyword.repeat" },      -- 󰔱  loop color
  PdxIconEvent       = { link = "Special" },              -- 󰉁  special color
  PdxIconBlock       = { link = "Comment" },              -- 󰅩  neutral/dim
}

-- Map scope keys to their highlight group name.
local ICON_HL_MAP = {
  trigger         = "PdxIconTrigger",
  trigger_if      = "PdxIconTrigger",
  trigger_else    = "PdxIconTrigger",
  trigger_else_if = "PdxIconTrigger",
  effect          = "PdxIconEffect",
  immediate       = "PdxIconEffect",
  after           = "PdxIconEffect",
  on_accept       = "PdxIconEffect",
  on_decline      = "PdxIconEffect",
  on_pass         = "PdxIconEffect",
  on_fail         = "PdxIconEffect",
  option          = "PdxIconOption",
  limit           = "PdxIconLimit",
  switch          = "PdxIconConditional",
  ["if"]          = "PdxIconConditional",
  else_if         = "PdxIconConditional",
  ["else"]        = "PdxIconConditional",
  AND             = "PdxIconLogic",
  OR              = "PdxIconLogic",
  NOT             = "PdxIconLogic",
  NOR             = "PdxIconLogic",
  NAND            = "PdxIconLogic",
  modifier        = "PdxIconModifier",
  on_action       = "PdxIconEvent",
}

--- Define all pdxscript highlight groups. Safe to call multiple times (idempotent).
--- Call once on startup and re-call on ColorScheme to survive theme reloads.
function M.setup_highlights()
  for name, def in pairs(ICON_HLS) do
    vim.api.nvim_set_hl(0, name, def)
  end
  -- Semantic token overrides for pdxscript filetype:
  -- Ensure prefix:value coloring works even if catppuccin doesn't set these.
  vim.api.nvim_set_hl(0, "@lsp.type.namespace.pdxscript",   { link = "@namespace" })
  vim.api.nvim_set_hl(0, "@lsp.type.enumMember.pdxscript",  { link = "@constant" })
end

--- Return the highlight group name for a scope key (or a default).
function M.icon_hl(key)
  if ICON_HL_MAP[key] then return ICON_HL_MAP[key] end
  if key:find("%.") then return "PdxIconEvent" end
  if key:match("^every_") or key:match("^any_") or key:match("^random_") or key:match("^ordered_") then
    return "PdxIconIterator"
  end
  return "PdxIconBlock"
end

-- ─── MODELINE ────────────────────────────────────────────────────────────────

local MODELINE = "# vim: set filetype=pdxscript :"

function M.ensure_modeline(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:find("vim: set filetype=pdxscript", 1, true) then return end
  end
  -- Neovim strips BOM internally (vim.bo.bomb), so prepending is safe
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { MODELINE })
end

return M
