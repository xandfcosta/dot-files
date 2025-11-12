return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        vtsls = {
          settings = {
            typescript = {
              preferences = {
                importModuleSpecifierPreference = "non-relative",
              },
            },
            javascript = {
              preferences = {
                importModuleSpecifierPreference = "non-relative",
              },
            },
          },
        },
        biome = {
          capabilities = { offsetEncoding = { "utf-8" } },
        },
        tailwindcss = {
          capabilities = { offsetEncoding = { "utf-8" } },
        },
        dockerls = {},
        yamlls = {},
        lua_ls = {},
        gopls = {},
      },
    },
  },

  -- {
  --   "pmizio/typescript-tools.nvim",
  --   dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  --   opts = {
  --     settings = {
  --       expose_as_code_actions = "all",
  --       tsserver_file_preferences = {
  --         importModuleSpecifierPreference = "non-relative",
  --       },
  --     },
  --   },
  -- },
}
