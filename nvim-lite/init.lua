-- Lite Neovim config for VPS / SSH use.
-- Minimal base + lazy.nvim with a few light plugins: treesitter, telescope,
-- gitsigns, tokyonight. No LSP, no Mason.
--
-- Deps on the VPS:
--   git   (required, lazy.nvim clone + gitsigns)
--   gcc   (required, treesitter compiles parsers)
--   ripgrep (recommended, telescope live_grep)
--   fd    (optional, faster telescope find_files)
--
-- Works on Neovim 0.9+. Symlink this dir to ~/.config/nvim.

local g = vim.g
local opt = vim.opt

g.mapleader = " "
g.maplocalleader = " "

-- ── Options ────────────────────────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.termguicolors = true
opt.cursorline = true
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.completeopt = "menuone,noselect"

g.netrw_banner = 0
g.netrw_liststyle = 3
g.netrw_winsize = 25

-- ── Keymaps ────────────────────────────────────────────────────────────────
local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>e", "<cmd>Lexplore<cr>", { desc = "Toggle file explorer" })

map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move line up" })

map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- ── Autocmds ───────────────────────────────────────────────────────────────
local aug = vim.api.nvim_create_augroup("vps_lite", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = aug,
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug,
  callback = function()
    local view = vim.fn.winsaveview()
    vim.cmd([[silent! %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- ── Bootstrap lazy.nvim ────────────────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ── Plugins ────────────────────────────────────────────────────────────────
require("lazy").setup({
  spec = {
    -- Colorscheme
    {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        vim.cmd.colorscheme("tokyonight-night")
      end,
    },

    -- Treesitter (syntax highlighting; compiles parsers -> needs gcc)
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      event = { "BufReadPost", "BufNewFile" },
      opts = {
        ensure_installed = {
          "lua", "vim", "vimdoc", "bash", "json", "yaml",
          "markdown", "markdown_inline", "python", "javascript", "typescript",
        },
        highlight = { enable = true },
        indent = { enable = true },
      },
      config = function(_, opts)
        require("nvim-treesitter.configs").setup(opts)
      end,
    },

    -- Telescope (fuzzy finder; live_grep needs ripgrep)
    {
      "nvim-telescope/telescope.nvim",
      cmd = "Telescope",
      dependencies = { "nvim-lua/plenary.nvim" },
      keys = {
        { "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
        { "<leader>f", "<cmd>Telescope find_files<cr>", desc = "Find files" },
        { "<leader>/", "<cmd>Telescope live_grep<cr>",  desc = "Grep" },
        { "<leader>b", "<cmd>Telescope buffers<cr>",    desc = "Buffers" },
        { "<leader>h", "<cmd>Telescope help_tags<cr>",  desc = "Help" },
      },
    },

    -- Gitsigns (gutter git status; needs git)
    {
      "lewis6991/gitsigns.nvim",
      event = { "BufReadPre", "BufNewFile" },
      opts = {},
    },
  },
  install = { colorscheme = { "tokyonight-night", "habamax" } },
  checker = { enabled = false },   -- no periodic update checks on a VPS
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
