return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        biome = { require_cwd = true },
      },
      formatters_by_ft = {
        python = { "black" },
        javascript = { "biome" },
        javascriptreact = { "biome" },
        typescript = { "biome" },
        typescriptreact = { "biome" },
        json = { "biome" },
        css = { "biome" },
        html = { "biome" },
      },
      default_format_opts = {
        async = false,
        lsp_format = "fallback",
      },
    },
  },
}
