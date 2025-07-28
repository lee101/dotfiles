-- ~/.config/nvim/lua/user/options.lua

vim.cmd('filetype plugin indent on')
vim.cmd('syntax enable')

vim.opt.showcmd = true          -- Show command in bottom bar
vim.opt.foldmethod = "marker"   -- Enable folding with markers
vim.opt.grepprg = "grep -nH $*" -- Use grep for :grep command

vim.opt.autoindent = true       -- Enable auto-indenting
vim.opt.expandtab = true        -- Use spaces instead of tabs
vim.opt.smarttab = true         -- Insert tabs at the start of a line according to shiftwidth

vim.opt.shiftwidth = 3          -- Number of spaces to use for autoindent
vim.opt.softtabstop = 3         -- Number of spaces that a <Tab> counts for

vim.opt.spelllang = "en"        -- Set spell language to English
vim.opt.spell = false           -- Disable spell checking by default

vim.opt.wildmenu = true         -- Enable enhanced command-line completion
vim.opt.wildmode = "list:longest,full" -- Completion mode

if vim.fn.has("mouse") == 1 then
  vim.opt.mouse = "a"             -- Enable mouse support in all modes
end

vim.opt.backspace = "indent,eol,start" -- Allow backspacing over everything in insert mode

vim.opt.number = true           -- Show line numbers
vim.opt.relativenumber = true   -- Show relative line numbers

vim.opt.ignorecase = true       -- Ignore case in search patterns
vim.opt.smartcase = true        -- Override ignorecase if pattern has uppercase letters

vim.opt.incsearch = true        -- Show matches while typing search pattern
vim.opt.hlsearch = true         -- Highlight all matches

-- Use system clipboard for all unnamed yanks and deletes
-- Requires a clipboard tool like xclip (Linux) or pbcopy/pbpaste (macOS)
vim.opt.clipboard = "unnamedplus"

vim.opt.hidden = false          -- Do not hide buffers when abandoned

-- Status line: lualine is used, so we don't set statusline here
vim.opt.laststatus = 2          -- Always show the status line (0=never, 1=only if multiple windows, 2=always, 3=global statusline Nvim 0.8+)

vim.opt.completeopt = "longest,menuone,preview" -- Completion options (nvim-cmp might override)

-- Set leader key before plugins that might use it (already in init.lua, but good to be aware)
-- vim.g.mapleader = " "
-- vim.g.maplocalleader = "\\" 

-- SmoothCursor highlight groups
vim.api.nvim_set_hl(0, "SmoothCursor", { fg = "#8aa872" })
vim.api.nvim_set_hl(0, "SmoothCursorRed", { fg = "#ff5189" })
vim.api.nvim_set_hl(0, "SmoothCursorOrange", { fg = "#ffb964" })
vim.api.nvim_set_hl(0, "SmoothCursorYellow", { fg = "#ffda64" })
vim.api.nvim_set_hl(0, "SmoothCursorGreen", { fg = "#8aa872" })
vim.api.nvim_set_hl(0, "SmoothCursorAqua", { fg = "#64ffda" })
vim.api.nvim_set_hl(0, "SmoothCursorBlue", { fg = "#64d2ff" })
vim.api.nvim_set_hl(0, "SmoothCursorPurple", { fg = "#d264ff" })