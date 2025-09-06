-- ~/.config/nvim/lua/user/keymaps.lua

local map = vim.api.nvim_set_keymap
local nomap_opts = { noremap = true, silent = true }
local map_opts = { noremap = false, silent = true } -- for recursive maps like nzz

-- Insert mode jj to Escape
map('i', 'jj', '<Esc>', { noremap = true })

-- Normal mode JJJJ to No operation
map('n', 'JJJJ', '<Nop>', nomap_opts)

-- Function to open URL (assuming xdg-open for Linux)
-- You might need to adjust the command for your OS if not Linux (e.g., 'open' for macOS)
function _G.OpenURLUnderCursor()
  local line = vim.fn.getline(".")
  local url = vim.fn.matchstr(line, "http[^ \t]*")
  if url ~= "" and url ~= nil then
    local cmd = "xdg-open"
    if vim.fn.has("macunix") == 1 then cmd = "open" end
    vim.fn.system(cmd .. " " .. vim.fn.shellescape(url))
  else
    print("No URL found on current line.")
  end
end
map('n', '<Leader>u', '<Cmd>lua _G.OpenURLUnderCursor()<CR>', nomap_opts)

-- Tab navigation
map('n', '<C-Right>', '<Cmd>tabnext<CR>', nomap_opts)
map('n', '<C-Left>', '<Cmd>tabprevious<CR>', nomap_opts)
map('n', '<C-t>', '<Cmd>tabnew<CR>', nomap_opts)

-- Edit Neovim config
map('n', '<Leader>ev', '<Cmd>tabnew $MYVIMRC<CR>', nomap_opts) -- $MYVIMRC points to init.lua/init.vim

-- Visual movement with gk and gj
map('n', 'k', 'gk', nomap_opts)
map('n', 'j', 'gj', nomap_opts)
map('i', '<Up>', '<Esc>gka', nomap_opts)
map('i', '<Down>', '<Esc>gja', nomap_opts)

-- Intended <Home> and <End> mappings (please verify if 'r' was intended or if 'I'/'A' are better)
map('n', '<Home>', 'i<Esc>r', nomap_opts)
map('n', '<End>', 'a<Esc>r', nomap_opts)

-- Create blank newlines and stay in Normal mode
map('n', 'zj', 'o<Esc>', nomap_opts)
map('n', 'zk', 'O<Esc>', nomap_opts)

-- Use leader key for fold toggle instead of Space to avoid conflicts
map('n', '<leader>z', 'za', { noremap = true }) -- not silent, so you see the fold status change

-- Search mappings to center screen
map('n', 'N', 'Nzz', map_opts)
map('v', 'N', 'Nzz', map_opts)
map('o', 'N', 'Nzz', map_opts)
map('n', 'n', 'nzz', map_opts)
map('v', 'n', 'nzz', map_opts)
map('o', 'n', 'nzz', map_opts)

-- Swap ; and :
map('n', ';', ':', { noremap = true })
map('n', ':', ';', { noremap = true })

-- Fix email paragraphs (remove leading '>')
map('n', '<leader>par', ':%s/^>\\s*//<CR>', nomap_opts)


-- Example for <F9> to remove DOS line endings
-- map('n', '<F9>', ':%s/\r$//g<CR>', nomap_opts)
-- Please confirm what your <F9> mapping was for.

-- For <F10> paste toggle, add this to lua/user/options.lua:
-- vim.opt.pastetoggle = "<F10>"

-- If you want <C-j> to also toggle nvim-tree:
-- map('n', '<C-j>', '<Cmd>NvimTreeToggle<CR>', nomap_opts)

-- Jump list navigation (go back/forward)
-- Ctrl-[ to go back (like in PyCharm/IntelliJ)
-- Note: Ctrl-] is already default for goto definition
map('n', '<C-[>', '<C-o>', nomap_opts)  -- Jump back in jumplist

-- Smart selection expand/shrink using Treesitter
-- Ctrl-Alt-Up to expand selection
-- Ctrl-Alt-Down to shrink selection
map('n', '<C-A-Up>', ':lua require"nvim-treesitter.incremental-selection".init_selection()<CR>', nomap_opts)
map('v', '<C-A-Up>', ':lua require"nvim-treesitter.incremental-selection".node_incremental()<CR>', nomap_opts)
map('v', '<C-A-Down>', ':lua require"nvim-treesitter.incremental-selection".node_decremental()<CR>', nomap_opts)

-- Alternative mappings if terminal doesn't support Ctrl-Alt combinations
-- You can also use these simpler keybindings
map('v', '<C-Up>', ':lua require"nvim-treesitter.incremental-selection".node_incremental()<CR>', nomap_opts)
map('v', '<C-Down>', ':lua require"nvim-treesitter.incremental-selection".node_decremental()<CR>', nomap_opts) 

-- IDE-like editing
-- NOTE: Removed Ctrl+D override since terminals can't distinguish Ctrl+D from Ctrl+Shift+D
-- Ctrl+D stays as default (half-page down)
-- Use Alt+D for delete line instead
map('n', '<A-d>', '"_dd', nomap_opts)
map('v', '<A-d>', '"_d', nomap_opts) 
map('i', '<A-d>', '<Esc>"_ddi', nomap_opts)

-- Duplicate line/selection
-- Leader+d: duplicate line (most reliable)
map('n', '<leader>d', 'yyp', { noremap = true, silent = true, desc = "Duplicate line" })
map('v', '<leader>d', 'y`>p', { noremap = true, silent = true, desc = "Duplicate selection" })
-- Alt+Shift+D: alternative duplicate  
map('n', '<A-S-d>', 'yyp', nomap_opts)
map('v', '<A-S-d>', 'y`>p', nomap_opts)

-- Formatting shortcuts (Conform provides <C-S-f> and <leader>F in init.lua)
-- Add an extra backup: <leader>cf
map('n', '<leader>cf', '<Cmd>lua require("conform").format({ async = true, lsp_fallback = true })<CR>', nomap_opts)
map('v', '<leader>cf', '<Cmd>lua require("conform").format({ async = true, lsp_fallback = true })<CR>', nomap_opts)

-- Expert-level keybindings

-- Quick save/quit
map('n', '<leader>s', '<Cmd>update<CR>', nomap_opts)  -- Save only if modified
map('n', 'ZZ', '<Cmd>x<CR>', nomap_opts)              -- Save and quit
map('n', 'ZQ', '<Cmd>q!<CR>', nomap_opts)             -- Quit without saving

-- Better window resizing with Leader+Arrows (avoiding Terminator conflicts)
map('n', '<leader><Up>', '<Cmd>resize +2<CR>', nomap_opts)
map('n', '<leader><Down>', '<Cmd>resize -2<CR>', nomap_opts)
map('n', '<leader><Left>', '<Cmd>vertical resize -2<CR>', nomap_opts)
map('n', '<leader><Right>', '<Cmd>vertical resize +2<CR>', nomap_opts)

-- Quick fix list navigation
map('n', '<leader>cn', '<Cmd>cnext<CR>zz', nomap_opts)
map('n', '<leader>cp', '<Cmd>cprev<CR>zz', nomap_opts)
map('n', '<leader>co', '<Cmd>copen<CR>', nomap_opts)
map('n', '<leader>cc', '<Cmd>cclose<CR>', nomap_opts)

-- Move lines up/down in visual mode (J/K for visual mode)
map('v', 'J', ":m '>+1<CR>gv=gv", nomap_opts)
map('v', 'K', ":m '<-2<CR>gv=gv", nomap_opts)

-- Smart line movement like IntelliJ (Ctrl+Shift+Up/Down)
-- Works in both normal and visual mode, maintains indentation
map('n', '<C-S-Up>', '<Cmd>lua require("user.smart-move").smart_move_up()<CR>', nomap_opts)
map('n', '<C-S-Down>', '<Cmd>lua require("user.smart-move").smart_move_down()<CR>', nomap_opts)
map('v', '<C-S-Up>', '<Cmd>lua require("user.smart-move").smart_move_visual_up()<CR>', nomap_opts)
map('v', '<C-S-Down>', '<Cmd>lua require("user.smart-move").smart_move_visual_down()<CR>', nomap_opts)
map('i', '<C-S-Up>', '<Esc><Cmd>lua require("user.smart-move").smart_move_up()<CR>gi', nomap_opts)
map('i', '<C-S-Down>', '<Esc><Cmd>lua require("user.smart-move").smart_move_down()<CR>gi', nomap_opts)

-- Alternative bindings using Ctrl+Alt for terminals that don't support Ctrl+Shift
map('n', '<C-A-Up>', '<Cmd>lua require("user.smart-move").smart_move_up()<CR>', nomap_opts)
map('n', '<C-A-Down>', '<Cmd>lua require("user.smart-move").smart_move_down()<CR>', nomap_opts)
map('v', '<C-A-Up>', '<Cmd>lua require("user.smart-move").smart_move_visual_up()<CR>', nomap_opts)
map('v', '<C-A-Down>', '<Cmd>lua require("user.smart-move").smart_move_visual_down()<CR>', nomap_opts)
map('i', '<C-A-Up>', '<Esc><Cmd>lua require("user.smart-move").smart_move_up()<CR>gi', nomap_opts)
map('i', '<C-A-Down>', '<Esc><Cmd>lua require("user.smart-move").smart_move_down()<CR>gi', nomap_opts)

-- Keep cursor centered when jumping
map('n', '<C-d>', '<C-d>zz', nomap_opts)
map('n', '<C-u>', '<C-u>zz', nomap_opts)
map('n', '{', '{zz', nomap_opts)
map('n', '}', '}zz', nomap_opts)

-- Better indenting in visual mode (stay in visual mode)
map('v', '<', '<gv', nomap_opts)
map('v', '>', '>gv', nomap_opts)

-- Paste without losing register
map('v', '<leader>p', '"_dP', nomap_opts)

-- Delete without yanking
map('n', '<leader>x', '"_x', nomap_opts)
map('v', '<leader>x', '"_x', nomap_opts)

-- Select all
map('n', '<C-a>', 'ggVG', nomap_opts)

-- Quick macro replay
map('n', 'Q', '@q', nomap_opts)
map('v', 'Q', ':norm @q<CR>', nomap_opts)

-- Smart home (go to first non-blank or beginning)
vim.keymap.set('n', '0', function()
  local col = vim.fn.col('.')
  local line = vim.fn.getline('.')
  local first_non_blank = vim.fn.match(line, '\\S') + 1
  if col == first_non_blank then
    return '0'
  else
    return '^'
  end
end, { expr = true, noremap = true })

-- Replace word under cursor
map('n', '<leader>rw', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { noremap = true })

-- Toggle relative line numbers
map('n', '<leader>ln', '<Cmd>set relativenumber!<CR>', nomap_opts)
