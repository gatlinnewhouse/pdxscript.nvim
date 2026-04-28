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

-- Walk upward from the cursor counting braces to find enclosing `key = {` scopes.
-- Returns a string like "some_event > option > trigger", or nil if at top level.
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

function M.get_scope()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "pdxscript" then return nil end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_line, false)

  local depth = 0
  local scopes = {}

  for i = #lines, 1, -1 do
    local line = lines[i]
    local opens, closes = line_brace_counts(line)

    -- Going upward: closing braces increase the "unmatched sub-block" count;
    -- opening braces decrease it. When depth goes negative an opener encloses us.
    depth = depth + closes
    for _ = 1, opens do
      depth = depth - 1
      if depth < 0 then
        -- This `{` encloses the cursor. Extract the key before `=` or directly before `{`.
        local key = line:match("^%s*([%w_.:]+)%s*[<>!?]*=%s*{")
                 or line:match("^%s*([%w_.:]+)%s*{")
        if key then table.insert(scopes, 1, key) end
        depth = 0
      end
    end
  end

  if #scopes == 0 then return nil end
  return table.concat(scopes, " > ")
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
