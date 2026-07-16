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
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Save (LazyVim parity)
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save" })

-- File explorer toggle
map("n", "<leader>e", "<cmd>Lexplore<cr>", { desc = "Toggle file explorer" })

-- New file
map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })

-- Window nav
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Window split / close
map("n", "<leader>-", "<C-w>s", { desc = "Split below" })
map("n", "<leader>|", "<C-w>v", { desc = "Split right" })
map("n", "<leader>wd", "<C-w>c", { desc = "Close window" })

-- Resize windows
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Increase height" })
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Decrease height" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase width" })

-- Buffer nav
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })
map("n", "[b",    "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "]b",    "<cmd>bnext<cr>",     { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Quickfix nav
map("n", "[q", "<cmd>cprevious<cr>", { desc = "Prev quickfix" })
map("n", "]q", "<cmd>cnext<cr>",     { desc = "Next quickfix" })

-- Move lines up/down (normal, insert, visual)
map("n", "<A-j>", "<cmd>m .+1<cr>==",        { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==",        { desc = "Move line up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv",        { desc = "Move line down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv",        { desc = "Move line up" })
-- Legacy J/K in visual (kept)
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move line up" })

-- Indent, keep selection
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Toggles (builtin options)
map("n", "<leader>uw", "<cmd>set wrap!<cr>",   { desc = "Toggle wrap" })
map("n", "<leader>us", "<cmd>set spell!<cr>",  { desc = "Toggle spell" })
map("n", "<leader>ul", "<cmd>set number!<cr>", { desc = "Toggle number" })
map("n", "<leader>uL", "<cmd>set relativenumber!<cr>", { desc = "Toggle relativenumber" })

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
