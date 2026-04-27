-- lua/pdxscript/init.lua
-- Core analysis for Paradox script files
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

-- ─── BRACE HELPERS ───────────────────────────────────────────────────────────

local function find_close(lines, start_l, start_c)
  local depth = 0
  for l = start_l, #lines do
    local line = lines[l]
    local c_from = (l == start_l) and start_c or 1
    local in_string = false
    for c = c_from, #line do
      local ch = line:sub(c, c)
      if ch == '"' then
        in_string = not in_string
      elseif not in_string then
        if ch == "#" then break end
        if ch == "{" then depth = depth + 1
        elseif ch == "}" then
          depth = depth - 1
          if depth == 0 then return l, c end
        end
      end
    end
  end
  return nil, nil
end

local function extract_children(lines, open_l, open_c, close_l, close_c)
  local children = {}
  local depth = 0
  local child_l, child_c = nil, nil

  for l = open_l, close_l do
    local line = lines[l]
    local c_from = (l == open_l) and (open_c + 1) or 1
    local c_to   = (l == close_l) and (close_c - 1) or #line
    local in_string = false

    for c = c_from, c_to do
      local ch = line:sub(c, c)
      if ch == '"' then
        in_string = not in_string
      elseif in_string then
      elseif ch == "#" and depth == 0 then
        break
      else
        if depth == 0 and not ch:match("%s") and child_l == nil then
          child_l, child_c = l, c
        end
        if ch == "{" then depth = depth + 1
        elseif ch == "}" then
          depth = depth - 1
          if depth == 0 and child_l then
            table.insert(children, { l1 = child_l, c1 = child_c, l2 = l, c2 = c })
            child_l, child_c = nil, nil
          end
        end
      end
    end

    if depth == 0 and child_l then
      local seg = line:sub((l == open_l) and (open_c + 1) or 1, #line)
      if seg:match("[^%s]") then
        table.insert(children, { l1 = child_l, c1 = child_c, l2 = l, c2 = c_to })
      end
      child_l, child_c = nil, nil
    end
  end

  return children
end

local function child_text_lines(lines, child)
  local result = {}
  for l = child.l1, child.l2 do
    local line = lines[l]
    if l == child.l1 and l == child.l2 then
      table.insert(result, line:sub(child.c1, child.c2))
    elseif l == child.l1 then
      table.insert(result, line:sub(child.c1))
    elseif l == child.l2 then
      table.insert(result, line:sub(1, child.c2))
    else
      table.insert(result, line)
    end
  end
  return result
end

-- ─── DE MORGAN DETECTION ─────────────────────────────────────────────────────

function M.find_demorgan(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local violations = {}

  for i, line in ipairs(lines) do
    if not line:match("^%s*NOT%s*=%s*{") then goto continue end

    local not_brace_c = line:find("{")
    local not_close_l, not_close_c = find_close(lines, i, not_brace_c)
    if not not_close_l then goto continue end

    local inner_op, inner_l, inner_brace_c = nil, nil, nil

    local after = line:sub(not_brace_c + 1)
    local op = after:match("^%s*(AND)%s*=%s*{") or after:match("^%s*(OR)%s*=%s*{")
    if op then
      inner_op = op
      inner_l = i
      inner_brace_c = line:find("{", not_brace_c + 1)
    end

    if not inner_op then
      for j = i + 1, not_close_l - 1 do
        local jl = lines[j]
        local jop = jl:match("^%s*(AND)%s*=%s*{") or jl:match("^%s*(OR)%s*=%s*{")
        if jop then
          inner_op, inner_l, inner_brace_c = jop, j, jl:find("{")
          break
        elseif jl:match("^%s*[^#%s]") then
          break
        end
      end
    end

    if not inner_op then goto continue end

    local inner_close_l, inner_close_c = find_close(lines, inner_l, inner_brace_c)
    if not inner_close_l then goto continue end

    local has_other = false
    for j = i, not_close_l do
      local jl = lines[j]
      local c_from = (j == i) and (not_brace_c + 1) or 1
      local c_to   = (j == not_close_l) and (not_close_c - 1) or #jl
      if j >= inner_l and j <= inner_close_l then
        if j == inner_l then
          if jl:sub(c_from, inner_brace_c - 1):match("[^%s]") then has_other = true end
        end
        if j == inner_close_l then
          if jl:sub(inner_close_c + 1, c_to):match("[^%s}]") then has_other = true end
        end
      else
        if jl:sub(c_from, c_to):match("[^%s}#]") then has_other = true end
      end
    end

    if not has_other then
      table.insert(violations, {
        not_lnum        = i,
        not_close_lnum  = not_close_l,
        not_brace_col   = not_brace_c,
        inner_op        = inner_op,
        inner_lnum      = inner_l,
        inner_close_lnum = inner_close_l,
        inner_brace_col = inner_brace_c,
        inner_close_col = inner_close_c,
      })
    end

    ::continue::
  end

  return violations
end

-- ─── DE MORGAN TRANSFORM ─────────────────────────────────────────────────────

function M.apply_demorgan(bufnr, violation)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local v = violation
  local new_op = v.inner_op == "OR" and "AND" or "OR"
  local indent = lines[v.not_lnum]:match("^(%s*)")

  local children = extract_children(
    lines, v.inner_lnum, v.inner_brace_col, v.inner_close_lnum, v.inner_close_col
  )

  local new_lines = { indent .. new_op .. " = {" }
  for _, child in ipairs(children) do
    local clines = child_text_lines(lines, child)
    for k, cl in ipairs(clines) do clines[k] = cl:match("^%s*(.-)%s*$") end
    if #clines == 1 then
      table.insert(new_lines, indent .. "    NOT = { " .. clines[1] .. " }")
    else
      table.insert(new_lines, indent .. "    NOT = {")
      for _, cl in ipairs(clines) do
        table.insert(new_lines, indent .. "        " .. cl)
      end
      table.insert(new_lines, indent .. "    }")
    end
  end
  table.insert(new_lines, indent .. "}")

  vim.api.nvim_buf_set_lines(bufnr, v.not_lnum - 1, v.not_close_lnum, false, new_lines)
end

-- ─── TIGER RUNNER ────────────────────────────────────────────────────────────

M.tiger_ns = vim.api.nvim_create_namespace("pdx_tiger")
M._cache   = {}
M._running = {}

local sev_map = {
  fatal   = vim.diagnostic.severity.ERROR,
  error   = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  untidy  = vim.diagnostic.severity.INFO,
  tips    = vim.diagnostic.severity.HINT,
}

function M.find_mod_root(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  while dir ~= "/" and dir ~= "" do
    if vim.fn.filereadable(dir .. "/vic3-tiger.conf") == 1 then return dir end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end
  return nil
end

local function parse_tiger_output(stdout)
  local ok, decoded = pcall(vim.json.decode, stdout)
  if not ok or type(decoded) ~= "table" then return {} end
  local by_file = {}
  for _, report in ipairs(decoded) do
    local sev = sev_map[report.severity] or vim.diagnostic.severity.WARN
    for _, loc in ipairs(report.locations or {}) do
      local path = loc.fullpath
      if path then
        by_file[path] = by_file[path] or {}
        local parts = { ("[%s] %s"):format(report.key or "tiger", report.message or "") }
        if type(report.info) == "string" and report.info ~= "" then
          table.insert(parts, report.info)
        end
        if type(report.wiki) == "string" and report.wiki ~= "" then
          table.insert(parts, report.wiki)
        end
        table.insert(by_file[path], {
          lnum      = math.max(0, (loc.linenr or 1) - 1),
          col       = math.max(0, (loc.column or 1) - 1),
          end_col   = math.max(0, (loc.column or 1) - 1 + (loc.length or 1)),
          severity  = sev,
          message   = table.concat(parts, "\n"),
          source    = "vic3-tiger",
          user_data = { wiki = report.wiki, info = report.info },
        })
      end
    end
  end
  return by_file
end

local function distribute(mod_root, by_file)
  M._cache[mod_root] = by_file

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path ~= "" and path:find(mod_root, 1, true) == 1 then
        vim.diagnostic.set(M.tiger_ns, bufnr, by_file[path] or {})
      end
    end
  end

  for path, diags in pairs(by_file) do
    if #diags > 0 then
      local bufnr = vim.fn.bufadd(path)
      if bufnr > 0 then
        vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
        pcall(vim.diagnostic.set, M.tiger_ns, bufnr, diags)
      end
    end
  end
end

function M.run_tiger(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then return end

  local mod_root = M.find_mod_root(filepath)
  if not mod_root then return end

  if M._cache[mod_root] then
    vim.diagnostic.set(M.tiger_ns, bufnr, M._cache[mod_root][filepath] or {})
  end

  if M._running[mod_root] then return end
  M._running[mod_root] = true

  vim.system(
    { "vic3-tiger", mod_root, "--json", "--no-color" },
    { text = true },
    function(result)
      M._running[mod_root] = false
      local stdout = result.stdout or ""
      if stdout == "" then return end
      vim.schedule(function()
        distribute(mod_root, parse_tiger_output(stdout))
      end)
    end
  )
end

-- ─── DE MORGAN DIAGNOSTICS ───────────────────────────────────────────────────

M.ns         = vim.api.nvim_create_namespace("pdx_demorgan")
M._violations = {}

function M.refresh_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "pdxscript" then return end

  local violations = M.find_demorgan(bufnr)
  M._violations[bufnr] = violations

  local diags = {}
  for _, v in ipairs(violations) do
    local new_op = v.inner_op == "OR" and "AND" or "OR"
    table.insert(diags, {
      lnum     = v.not_lnum - 1,
      col      = 0,
      end_lnum = v.not_close_lnum - 1,
      severity = vim.diagnostic.severity.HINT,
      message  = ("De Morgan: NOT { %s { … } } → %s { NOT { … } … }"):format(v.inner_op, new_op),
      source   = "pdxscript",
      code     = "de-morgan",
    })
  end

  vim.diagnostic.set(M.ns, bufnr, diags)
end

function M.fix_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor_l = vim.api.nvim_win_get_cursor(0)[1]
  local violations = M._violations[bufnr] or {}
  for _, v in ipairs(violations) do
    if cursor_l >= v.not_lnum and cursor_l <= v.not_close_lnum then
      M.apply_demorgan(bufnr, v)
      M.refresh_diagnostics(bufnr)
      return
    end
  end
  vim.notify("No De Morgan violation at cursor", vim.log.levels.INFO)
end

return M
