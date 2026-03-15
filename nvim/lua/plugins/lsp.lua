return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        biome = {},
        tailwindcss = {
          filetypes = { "javascriptreact", "typescriptreact", "javascript.jsx", "typescript.tsx" },
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
  },
}
