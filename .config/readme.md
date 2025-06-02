# Neovim Setup Guide

## Introduction to Neovim

Neovim is a hyperextensible Vim-based text editor that seeks to aggressively refactor Vim. It offers improved extensibility through a better API, better UI, and better plugin support.

### Basic Neovim Commands

- `:q` - Quit
- `:w` - Save
- `:wq` - Save and quit
- `i` - Enter insert mode
- `Esc` - Return to normal mode
- `/pattern` - Search for pattern
- `n` - Next search result
- `N` - Previous search result

## My Neovim Configuration

My Neovim setup uses [lazy.nvim](https://github.com/folke/lazy.nvim) as a plugin manager. Here's a breakdown of the configuration:

### Core Setup

- **Plugin Manager**: lazy.nvim for efficient plugin management
- **Leader Key**: Space
- **Local Leader**: Backslash

### Key Plugins

1. **avante.nvim** - AI assistant with various dependencies including:
   - img-clip.nvim for image handling
   - render-markdown.nvim for markdown rendering

2. **UI Enhancements**:
   - lualine.nvim - Status line
   - nvim-tree.lua - File explorer (toggle with `<leader>e`)
   - tokyonight.nvim - Color scheme
   - nvim-web-devicons - Icons

3. **Development Tools**:
   - nvim-treesitter - Syntax highlighting
   - telescope.nvim - Fuzzy finder (`<leader>ff` for files, `<leader>fg` for grep)
   - gitsigns.nvim - Git integration
   - nvim-dap - Debugging support
   - toggleterm.nvim - Terminal integration (toggle with `<C-\>`)
   - nvim-autopairs - Auto-pairing brackets

4. **Utility**:
   - which-key.nvim - Key binding helper
   - image.nvim - Image support

### Notable Keybindings

- `<leader>e` - Toggle file explorer
- `<leader>ff` - Find files
- `<leader>fg` - Live grep
- `<leader>db` - Toggle breakpoint
- `<leader>dc` - Continue debugging
- `<C-\>` - Toggle terminal

### Getting Started

1. Clone this configuration to your `.config/nvim/` directory
2. Start Neovim - plugins will be automatically installed
3. Restart Neovim to ensure all plugins are properly loaded

## Navigation Tips for Intermediate Neovim Users

### Efficient Movement

- **Word Navigation**: `w` (next word), `b` (previous word), `e` (end of word)
- **Line Navigation**: `0` (start of line), `$` (end of line), `^` (first non-blank character)
- **Screen Navigation**: `H` (top of screen), `M` (middle of screen), `L` (bottom of screen)
- **File Navigation**: `gg` (start of file), `G` (end of file), `{number}G` (go to line number)
- **Paragraph Movement**: `{` (previous paragraph), `}` (next paragraph)
- **Matching Pairs**: `%` (jump to matching bracket/parenthesis)

### Search and Jump

- **Search**: `/pattern` (forward search), `?pattern` (backward search)
- **Search Navigation**: `n` (next match), `N` (previous match)
- **Character Search**: `f{char}` (find char forward), `F{char}` (find char backward)
- **Till Character**: `t{char}` (till char forward), `T{char}` (till char backward)
- **Last Edit**: `g;` (jump to previous edit), `g,` (jump to next edit)

### Marks and Jumps

- **Set Mark**: `m{a-zA-Z}` (lowercase for buffer-local, uppercase for global)
- **Jump to Mark**: `` `{a-zA-Z}`` (exact position), `'{a-zA-Z}` (line of mark)
- **Special Marks**: `` `. `` (last change), `` `^ `` (last insert position), `` `[ `` and `` `] `` (start/end of last change)
- **Jump List**: `<C-o>` (jump back), `<C-i>` (jump forward)
- **Change List**: `g;` (older change), `g,` (newer change)

### Window Management

- **Split Windows**: `<C-w>s` (horizontal split), `<C-w>v` (vertical split)
- **Window Navigation**: `<C-w>h/j/k/l` (move between windows)
- **Resize Windows**: `<C-w>+/-` (increase/decrease height), `<C-w>>/<<` (increase/decrease width)
- **Equal Size**: `<C-w>=` (make all windows equal size)
- **Maximize**: `<C-w>_` (maximize height), `<C-w>|` (maximize width)

### Buffer Management

- **List Buffers**: `:ls` or `:buffers`
- **Switch Buffers**: `:b{number}` or `:b{partial name}`, `:bnext` (`:bn`), `:bprev` (`:bp`)
- **Delete Buffer**: `:bd` (delete current buffer)

### Text Objects

- **Inner/Around**: `i` (inner), `a` (around)
- **Common Objects**: `w` (word), `s` (sentence), `p` (paragraph), `"` (quotes), `'` (single quotes), `)` or `(` (parentheses)
- **Examples**: `diw` (delete inner word), `ca"` (change around quotes), `yi(` (yank inner parentheses)

### Macros

- **Record Macro**: `q{a-z}` (start recording to register), `q` (stop recording)
- **Play Macro**: `@{a-z}` (play macro from register), `@@` (repeat last macro)
- **Multiple Executions**: `{number}@{a-z}` (execute macro multiple times)

### Advanced Telescope Usage

- **Resume Last Picker**: `<leader>fr` (if configured)
- **Buffer Search**: `<leader>fb` (search open buffers)
- **Help Tags**: `<leader>fh` (search help documentation)
- **Grep with Selection**: Visual select text then `<leader>fg` to search for selection

### Quickfix and Location Lists

- **Navigate Quickfix**: `:cnext` (`:cn`), `:cprev` (`:cp`), `:cfirst` (`:cfir`), `:clast` (`:cla`)
- **Open/Close Quickfix**: `:copen` (`:cope`), `:cclose` (`:ccl`)
- **Location List**: Same commands with 'l' instead of 'c' (`:lnext`, `:lprev`, etc.)
