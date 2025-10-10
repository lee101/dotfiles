# Neovim Navigation Guide

## Quick Reference

### Essential Navigation Shortcuts

| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+p` | Find files | Quick file finder (fzf-style) |
| `Space ff` | Find files | Alternative file finder |
| `Space fg` | Live grep | Search text across all files |
| `Space fw` | Find word | Search word under cursor |
| `Space fb` | Buffers | Switch between open buffers |
| `Space fr` | Recent files | Open recently edited files |
| `Space /` | Buffer search | Search within current file |
| `Space @` | Document symbols | Jump to function/class in file |
| `Space @@` | Workspace symbols | Jump to any symbol in project |
| `gm` | Go to method | Quick jump to methods/functions |
| `gd` | Go to definition | Jump to definition (LSP) |
| `gr` | Go to references | Find all references (LSP) |
| `gi` | Go to implementation | Jump to implementation (LSP) |

## File Navigation

### Finding Files
- **`Ctrl+p`** or **`Space ff`** - Opens fuzzy file finder
  - Type partial filename to filter
  - Supports fuzzy matching: `usrkemap` finds `user/keymaps.lua`
  - Hidden files included (except .git)
  
### Recent Files & Buffers
- **`Space fr`** - Recent files across sessions
- **`Space fb`** - Currently open buffers
  - `dd` in normal mode to delete buffer
  - `Ctrl+w` in insert mode to delete buffer
- **`Tab`** / **`Shift+Tab`** - Cycle through buffers

## Code Navigation

### Symbol Search (@-notation)
The @ symbol is used for jumping to code symbols (functions, classes, variables):

- **`Space @`** or **`Space fs`** - Search symbols in current file
  - Type `@` followed by symbol name
  - Example: `@handle` finds `handleRequest()`
  
- **`Space @@`** or **`Space fS`** - Search symbols across entire workspace
  - Searches all files in project
  - Great for finding class/function definitions

- **`gm`** - Quick jump to methods/functions only
- **`gM`** - Jump to methods across workspace

### Text Search

- **`Space fg`** - Live grep (ripgrep)
  - Real-time search as you type
  - Respects .gitignore
  - Searches hidden files with --hidden flag

- **`Space fw`** - Search word under cursor
  - Place cursor on any word
  - Instantly searches all occurrences

- **`Space /`** - Fuzzy search in current buffer
  - Quick navigation within file
  - Shows preview of matching lines

### LSP Navigation

| Key | Action | Works Best For |
|-----|--------|----------------|
| `gd` | Go to definition | Jump to where symbol is defined |
| `gD` | Go to declaration | Jump to declaration (C/C++) |
| `gr` | Go to references | Find all uses of symbol |
| `gi` | Go to implementation | Jump to implementation (interfaces) |
| `K` | Hover documentation | Show docs in popup |
| `[d` | Previous diagnostic | Jump to previous error/warning |
| `]d` | Next diagnostic | Jump to next error/warning |

## Advanced Features

### Telescope Shortcuts in Picker

While in any Telescope picker:

| Key | Action |
|-----|--------|
| `Ctrl+j/k` | Move selection up/down |
| `Ctrl+v` | Open in vertical split |
| `Ctrl+x` | Open in horizontal split |
| `Ctrl+t` | Open in new tab |
| `Tab` | Toggle selection (multi-select) |
| `Ctrl+q` | Send to quickfix list |
| `Ctrl+/` | Show help for picker |
| `Esc` | Close picker |

### Git Navigation

- **`Space gc`** - Browse git commits
- **`Space gb`** - Switch git branches
- **`Space gs`** - View git status
- **`Space gS`** - Browse git stash

### Marks & Jumps

- **`Space fm`** - Browse marks
- **`Space fj`** - Browse jumplist
- **`Ctrl+o`** - Jump back in history
- **`Ctrl+i`** - Jump forward in history
- **`''`** - Jump to last position

## Tips & Tricks

### Fuzzy Matching Patterns
- `usrkeymap` → finds `user/keymaps.lua`
- `^init` → files starting with "init"
- `.lua$` → files ending with ".lua"
- `!test` → exclude files with "test"

### Search Operators
In live grep (`Space fg`):
- `word1 word2` - Find lines with both words
- `"exact phrase"` - Search exact phrase
- `\bword\b` - Whole word search
- `.*pattern.*` - Regex patterns

### Quick Workflows

**Jump to specific function:**
1. `Space @` or `gm`
2. Type function name
3. Enter to jump

**Find and replace across files:**
1. `Space fg` to search term
2. `Ctrl+q` to send results to quickfix
3. `:cdo s/old/new/g` to replace all
4. `:wall` to save all

**Navigate project structure:**
1. `Ctrl+n` to toggle file tree
2. Use `h/j/k/l` to navigate
3. `Enter` to open file
4. `v` for vertical split

## Customization

All keybindings are defined in:
- `init.lua` - Telescope mappings (lines 898-932)
- `lua/user/keymaps.lua` - General navigation keys

To add custom search:
```lua
vim.api.nvim_set_keymap('n', '<leader>fx', 
  '<cmd>Telescope command_name<CR>', 
  { noremap = true, silent = true, desc = "Description" })
```

## Troubleshooting

**Telescope not finding files?**
- Check if ripgrep is installed: `which rg`
- Verify file isn't in .gitignore
- Try with hidden files: add `--hidden` flag

**Symbols not working?**
- Ensure LSP is running: `:LspInfo`
- Install language server via Mason: `:Mason`
- Check if file type is supported

**Slow search?**
- Exclude large directories in Telescope config
- Use more specific search patterns
- Consider using `:Telescope resume` to continue last search