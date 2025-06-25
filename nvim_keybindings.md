# Neovim Search & File Tree Quick Reference

## Fuzzy Finding with fzf-lua (Telescope replacement)

### File Search
- `<leader>ff` - Find files
- `<leader>fa` - Find files in current directory
- `<leader>fh` - Find recent files (oldfiles)
- `<Ctrl-p>` - Find files (familiar shortcut)

### Text Search
- `<leader>fg` - Live grep (search in files)
- `<leader>fw` - Grep word under cursor
- `<leader>fW` - Grep WORD under cursor
- `<leader>fr` - Resume last grep search
- `<Ctrl-f>` - Live grep (familiar shortcut)

### Buffers & Navigation
- `<leader>fb` - Find buffers
- `<leader>fj` - Find jumps
- `<leader>fm` - Find marks
- `<leader>fq` - Find quickfix entries
- `<leader>fl` - Find location list entries

### Git Integration
- `<leader>gc` - Git commits
- `<leader>gb` - Git branches
- `<leader>gf` - Git files
- `<leader>gs` - Git status

### Help & Commands
- `<leader>fh` - Find help tags
- `<leader>fc` - Find commands
- `<leader>fk` - Find keymaps

### LSP Integration
- `<leader>fs` - Document symbols
- `<leader>fS` - Workspace symbols
- `<leader>fd` - LSP definitions
- `<leader>fD` - LSP declarations
- `<leader>fi` - LSP implementations
- `<leader>ft` - LSP type definitions
- `<leader>fR` - LSP references

## File Tree with nvim-tree

### Basic Operations
- `<leader>e` - Toggle file tree
- `<leader>E` - Focus file tree
- `<leader>tf` - Find current file in tree
- `<leader>tc` - Collapse file tree

### Inside File Tree
- `Enter` or `o` - Open file/folder
- `<Tab>` - Preview file
- `a` - Create file/folder
- `d` - Delete file/folder
- `r` - Rename file/folder
- `x` - Cut file/folder
- `c` - Copy file/folder
- `p` - Paste file/folder
- `y` - Copy name to clipboard
- `Y` - Copy relative path to clipboard
- `gy` - Copy absolute path to clipboard
- `R` - Refresh tree
- `H` - Toggle hidden files
- `I` - Toggle git ignored files
- `f` - Live filter
- `F` - Clear live filter
- `q` - Close tree

## GitHub Copilot
- `<Ctrl-j>` - Accept Copilot suggestion
- `<Ctrl-]>` - Next Copilot suggestion
- `<Ctrl-[>` - Previous Copilot suggestion
- `<Ctrl-\>` - Dismiss Copilot suggestion

## Essential Vim Shortcuts
- `jj` - Exit insert mode
- `;` - Command mode (instead of :)
- `:` - Repeat last find (instead of ;)
- `<Ctrl-s>` - Save file
- `<Ctrl-z>` - Undo
- `<Ctrl-y>` - Redo

## Window Navigation
- `<Alt-h>` - Move to left window
- `<Alt-j>` - Move to window below
- `<Alt-k>` - Move to window above
- `<Alt-l>` - Move to right window

## LSP Features
- `gd` - Go to definition
- `K` - Hover documentation
- `<leader>rn` - Rename symbol
- `<leader>ca` - Code actions 