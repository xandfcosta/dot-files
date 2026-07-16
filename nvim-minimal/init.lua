-- Minimal Neovim config for VPS / SSH use.
-- Zero plugins, zero network, zero compiler. Just sane defaults + quick edits.
-- Works on Neovim 0.9+. Drop-in: symlink this dir to ~/.config/nvim.

local g = vim.g
local opt = vim.opt

-- Leader (set before any mapping)
g.mapleader = " "
g.maplocalleader = " "

-- ── Options ────────────────────────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"   -- share system clipboard (needs xclip/wl-copy; harmless if absent)
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

-- Indent
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Persistent undo (survive close), no swap/backup clutter
opt.undofile = true
opt.swapfile = false
opt.backup = false

-- Faster completion menu behaviour for built-in omnifunc
opt.completeopt = "menuone,noselect"

-- ── Netrw file explorer (built-in, no plugin) ──────────────────────────────
g.netrw_banner = 0
g.netrw_liststyle = 3           -- tree view
g.netrw_winsize = 25

-- ── Keymaps ────────────────────────────────────────────────────────────────
local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- File explorer toggle
map("n", "<leader>e", "<cmd>Lexplore<cr>", { desc = "Toggle file explorer" })

-- Window nav
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Move lines up/down in visual mode
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move line up" })

-- Keep cursor centred on jumps
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Built-in fuzzy-ish file find (no plugin): :find uses path
opt.path:append("**")
opt.wildmenu = true
opt.wildmode = "longest:full,full"
map("n", "<leader>f", ":find ", { desc = "Find file (:find)" })
map("n", "<leader>b", ":buffer ", { desc = "Switch buffer" })

-- ── Autocmds ───────────────────────────────────────────────────────────────
local aug = vim.api.nvim_create_augroup("vps_minimal", { clear = true })

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})

-- Restore last cursor position
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

-- Strip trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug,
  callback = function()
    local view = vim.fn.winsaveview()
    vim.cmd([[silent! %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- ── Colorscheme (built-in, no download) ────────────────────────────────────
pcall(vim.cmd.colorscheme, "habamax")
