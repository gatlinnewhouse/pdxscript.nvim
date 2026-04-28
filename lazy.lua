-- LazyVim extras spec for pdxscript.nvim.
--
-- Usage (LazyVim distro):
--   Add to ~/.config/nvim/lua/plugins/pdxscript.lua:
--     return { { import = "lazyvim.plugins.extras.lang.pdxscript" } }
--   (or copy this file to that path and adjust the plugin name below)
--
-- Usage (standalone lazy.nvim):
--   return { { import = "path.to.this.file" } }
--   or just copy the table below into your own plugin spec.
--
-- Configuration (set BEFORE lazy.nvim starts, e.g. in options.lua):
--   vim.g.pdxscriptvim = {
--     server = {
--       bin_dir = "~/.local/bin/",        -- directory containing pdxscript-lsp-* binaries
--       auto_attach = true,               -- true | false | function(bufnr) -> bool
--       on_attach = function(client, bufnr) ... end,
--       settings = {},
--     },
--   }

return {
  recommended = function()
    return LazyVim.extras.wants({
      ft = "pdxscript",
      root = {
        "vic3-tiger.conf",
        "ck3-tiger.conf",
        "imperator-tiger.conf",
        "hoi4-tiger.conf",
        "eu5-tiger.conf",
      },
    })
  end,

  -- Core plugin — owns LSP startup via ftplugin/pdxscript.lua.
  -- No lspconfig dependency. LSP server is selected per-mod by *-tiger.conf detection.
  {
    "paradox-modding/pdxscript.nvim", -- replace with actual GitHub path when published
    lazy = false,
    config = function(_, opts)
      vim.g.pdxscriptvim = vim.tbl_deep_extend("keep", vim.g.pdxscriptvim or {}, opts or {})
    end,
  },

  -- Treesitter syntax: registers the paradox parser for pdxscript buffers.
  -- Run :TSInstall paradox after :Lazy sync.
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      { "Acture/tree-sitter-paradox", build = false },
    },
    opts = function(_, opts)
      local ok, parsers = pcall(require, "nvim-treesitter.parsers")
      if ok then
        local tbl = type(parsers.get_parser_configs) == "function"
          and parsers.get_parser_configs()
          or parsers
        tbl["paradox"] = {
          install_info = {
            url = vim.fn.stdpath("data") .. "/lazy/tree-sitter-paradox",
            files = { "src/parser.c" },
          },
        }
      end
      vim.treesitter.language.register("paradox", "pdxscript")
      return opts
    end,
  },

  -- Filetype icon for lualine / nvim-web-devicons.
  {
    "nvim-mini/mini.icons",
    optional = true,
    opts = function(_, opts)
      opts.filetype = opts.filetype or {}
      opts.filetype["pdxscript"] = { glyph = "󰏗", hl = "MiniIconsYellow" }
    end,
  },

  -- Statusline: append pdx scope breadcrumb to lualine_c.
  -- Does NOT replace LazyVim's existing lualine_c components (root_dir, diagnostics, path).
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      local pdx_scope = {
        function()
          local scope = require("pdxscript").get_scope()
          if not scope then return "" end
          local parts = {}
          for seg in scope:gmatch("[^>]+") do
            local trimmed = vim.trim(seg)
            if #trimmed > 24 then trimmed = trimmed:sub(1, 21) .. "…" end
            table.insert(parts, trimmed)
          end
          -- Show at most 3 levels to keep the statusline from overflowing.
          if #parts > 3 then
            parts = { "…", parts[#parts - 1], parts[#parts] }
          end
          return " 󰊕 " .. table.concat(parts, " > ")
        end,
        cond = function() return vim.bo.filetype == "pdxscript" end,
        padding = { left = 0, right = 1 },
      }

      opts.sections = opts.sections or {}
      opts.sections.lualine_c = opts.sections.lualine_c or {}
      table.insert(opts.sections.lualine_c, pdx_scope)
      return opts
    end,
  },
}
