return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      -- Event to trigger linters
      linters_by_ft = {
        javascript = { "biomejs" },
        javascriptreact = { "biomejs" },
        typescript = { "biomejs" },
        typescriptreact = { "biomejs" },
      },
      -- LazyVim extension to easily override linter options
      -- or add custom linters.
      ---@type table<string,table>
      linters = {
        -- -- Example of using selene only when a selene.toml file is present
        -- selene = {
        --   -- `condition` is another LazyVim extension that allows you to
        --   -- dynamically enable/disable linters based on the context.
        --   condition = function(ctx)
        --     return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
        --   end,
        -- },
        biomejsjs = {
          condition = function(ctx)
            return vim.fs.find({ "biomejs.json" }, { path = ctx.filename, upward = true })[1]
          end,
        },
      },
    },
  },
}
