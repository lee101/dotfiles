-- ~/.config/nvim/lua/user/keymaps.lua

local map = vim.keymap.set
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
map('n', '<Leader>w', '<Cmd>lua _G.OpenURLUnderCursor()<CR>', nomap_opts)

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

-- Space will toggle folds
map('n', '<Space>', 'za', { noremap = true }) -- not silent, so you see the fold status change

-- Search mappings to center screen
map({'n', 'v', 'o'}, 'N', 'Nzz', map_opts)
map({'n', 'v', 'o'}, 'n', 'nzz', map_opts)

-- Swap ; and :
map('n', ';', ':', { noremap = true })
map('n', ':', ';', { noremap = true })

-- Fix email paragraphs (remove leading '>')
map('n', '<leader>par', ':%s/^>\s*//<CR>', nomap_opts)


-- Example for <F9> to remove DOS line endings
-- map('n', '<F9>', ':%s/\r$//g<CR>', nomap_opts)
-- Please confirm what your <F9> mapping was for.

-- For <F10> paste toggle, add this to lua/user/options.lua:
-- vim.opt.pastetoggle = "<F10>"

-- If you want <C-j> to also toggle nvim-tree:
-- map('n', '<C-j>', '<Cmd>NvimTreeToggle<CR>', nomap_opts) 