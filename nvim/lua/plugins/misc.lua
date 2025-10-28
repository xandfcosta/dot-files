return {
  {
    "folke/todo-comments.nvim",
    event = "VimEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
  },

  { -- Add indentation guides even on blank lines
    "lukas-reineke/indent-blankline.nvim",
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = "ibl",
    opts = {},
  },

  {
    "nmac427/guess-indent.nvim",
    opts = {
      auto_cmd = true,
      buftype_exclude = {
        "help",
        "nofile",
        "terminal",
        "prompt",
      },
    },
  }, -- Detect tabstop and shiftwidth automatically
}
