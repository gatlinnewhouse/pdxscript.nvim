if vim.g.loaded_pdxscript then return end
vim.g.loaded_pdxscript = true

local function pdx() return require("pdxscript") end

-- Ensure filetype detection when buffer first displayed (Trouble, quickfix, picker)
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("pdxscript_winenter", { clear = true }),
  pattern = { "*.txt", "*.gui" },
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "" then
      vim.api.nvim_buf_call(ev.buf, function() vim.cmd("filetype detect") end)
    end
  end,
})

-- Format + strip trailing whitespace + ensure modeline on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("pdxscript_write", { clear = true }),
  pattern = { "*.txt", "*.gui" },
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "pdxscript" then return end
    local M = pdx()
    M.ensure_modeline(ev.buf)
    M.format_buffer(ev.buf)
    local view = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Tiger: run on FileType (guarantees filetype is set; handles first open)
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("pdxscript_tiger_ft", { clear = true }),
  pattern = "pdxscript",
  callback = function(ev)
    local M = pdx()
    local path = vim.api.nvim_buf_get_name(ev.buf)
    local mod_root = M.find_mod_root(path)
    if not mod_root then return end
    if M._cache[mod_root] then
      vim.diagnostic.set(M.tiger_ns, ev.buf, M._cache[mod_root][path] or {})
    else
      M.run_tiger(ev.buf)
    end
  end,
})

-- Tiger: re-run on save
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("pdxscript_tiger_save", { clear = true }),
  pattern = { "*.txt", "*.gui" },
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "pdxscript" then pdx().run_tiger(ev.buf) end
  end,
})

-- Tiger: re-attach cache when switching between open buffers
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("pdxscript_tiger_enter", { clear = true }),
  pattern = { "*.txt", "*.gui" },
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "pdxscript" then return end
    local M = pdx()
    local path = vim.api.nvim_buf_get_name(ev.buf)
    local mod_root = M.find_mod_root(path)
    if mod_root and M._cache[mod_root] then
      vim.diagnostic.set(M.tiger_ns, ev.buf, M._cache[mod_root][path] or {})
    end
  end,
})

-- De Morgan: debounced refresh on text change
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("pdxscript_demorgan", { clear = true }),
  pattern = { "*.txt", "*.gui" },
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "pdxscript" then return end
    local timer = vim.loop.new_timer()
    timer:start(500, 0, vim.schedule_wrap(function()
      pdx().refresh_diagnostics(ev.buf)
      timer:close()
    end))
  end,
})
