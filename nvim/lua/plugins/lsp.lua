-- Walk up from `start` looking for `rel` (a path relative to each ancestor dir).
-- Returns the absolute match and the ancestor dir that contained it, or nil.
local function find_up(start, rel)
  if not start or start == "" then
    start = vim.uv.cwd()
  end
  local dir = vim.fs.dirname(start)
  while dir and dir ~= "" do
    local target = dir .. "/" .. rel
    if vim.uv.fs_stat(target) then
      return target, dir
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

-- Read the major version of the project's installed `typescript` package.
local function ts_major(fname)
  local pkg = find_up(fname, "node_modules/typescript/package.json")
  if not pkg then
    return nil
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(pkg), "\n"))
  end)
  local version = ok and data and data.version
  return version and tonumber(version:match("^(%d+)"))
end

-- Resolve the TypeScript 7 native LSP binary for a project, or nil.
-- Preview builds ship `node_modules/.bin/tsgo`; stable 7.x folds the server
-- into `tsc` (started with `--lsp --stdio`).
local function ts7_bin(fname)
  local tsgo = find_up(fname, "node_modules/.bin/tsgo")
  if tsgo then
    return tsgo
  end
  local major = ts_major(fname)
  if major and major >= 7 then
    return find_up(fname, "node_modules/.bin/tsc") or "tsc"
  end
end

local ts_filetypes = {
  "javascript",
  "javascriptreact",
  "javascript.jsx",
  "typescript",
  "typescriptreact",
  "typescript.tsx",
}

return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        biome = {},
        tailwindcss = {
          filetypes = { "javascriptreact", "typescriptreact" },
        },
        dockerls = {},
        yamlls = {},
        lua_ls = {},
        gopls = {},
      },
    },
  },

  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {
      -- Overrides typescript-tools' default root_dir (tbl_deep_extend "keep").
      -- When the project ships TypeScript 7, skip typescript-tools and let the
      -- native `tsgo` LSP handle the buffer instead.
      root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        if ts7_bin(fname) then
          return
        end
        on_dir(require("typescript-tools.utils").get_root_dir(bufnr))
      end,
      settings = {
        capabilities = { offsetEncoding = { "utf-8" } },
        expose_as_code_action = "all",
        tsserver_file_preferences = {
          includeCompletionsForImportStatements = true,
          includeAutomaticOptionalChainCompletions = true,
          importModuleSpecifierPreference = "non-relative",
          includeInlayParameterNameHints = "literals",
          includeInlayEnumMemberValueHints = true,
        },
      },
    },
    config = function(_, opts)
      require("typescript-tools").setup(opts)

      -- Native TypeScript 7 LSP. Attaches only when the project provides the TS7
      -- toolchain; otherwise root_dir stays silent and nothing spawns. Distinct
      -- name so it never merges with nvim-lspconfig's bundled `tsgo` config.
      vim.lsp.config("ts7", {
        filetypes = ts_filetypes,
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local _, root = find_up(fname, "node_modules/typescript/package.json")
          root = root or vim.fs.root(bufnr, { "package.json", ".git" })
          if root and ts7_bin(fname) then
            on_dir(root)
          end
        end,
        cmd = function(dispatchers, config)
          local root = config.root_dir or vim.uv.cwd()
          local bin = ts7_bin(root .. "/x") or "tsc"
          return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers, { cwd = root })
        end,
      })
      vim.lsp.enable("ts7")
    end,
  },
}
