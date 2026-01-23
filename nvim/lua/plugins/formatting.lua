return {
  {
    "stevearc/conform.nvim",
    opts = {
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
        lsp_format = "fallback",
      },
    },
  },
}
