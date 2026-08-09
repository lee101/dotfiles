# Neovim Tutorial - Complete Guide

## 📚 Documentation Index
- **This file:** Basic tutorial and getting started
- **`nvim_keybindings.md`:** Quick keybinding reference
- **`nvim-complete-guide.md`:** Comprehensive guide with all features

## 🎯 Your Leader Key = SPACE
Most custom commands start with pressing the spacebar (your leader key).

## Quick Start

### Opening Files & Directories
- `nvim .` - Open file explorer in current directory
- `nvim file.txt` - Open specific file
- `:e filename` - Open file from within Neovim
- `:Ex` - Open native file explorer

### Essential Movement
- `h/j/k/l` - Left/Down/Up/Right
- `w/b` - Word forward/backward
- `0/$` - Start/End of line
- `gg/G` - Start/End of file
- `{/}` - Paragraph up/down
- `Ctrl-d/Ctrl-u` - Page down/up
- `zz` - Center cursor line

### Editing Basics
- `i/a` - Insert before/after cursor
- `I/A` - Insert at line start/end
- `o/O` - Open line below/above
- `x/X` - Delete char forward/backward
- `dd` - Delete line
- `yy` - Yank (copy) line
- `p/P` - Paste after/before
- `u/Ctrl-r` - Undo/Redo
- `.` - Repeat last command

## File Browser & Navigation

### NvimTree File Explorer (Plugin)
**Toggle:** `Ctrl-j` - Toggle file tree sidebar

**In NvimTree:**
- `Enter` - Open file/directory
- `a` - Create new file
- `d` - Delete file
- `r` - Rename file
- `x` - Cut file
- `c` - Copy file
- `p` - Paste file
- `R` - Refresh tree
- `H` - Toggle hidden files
- `g?` - Show help

### fzf-lua Fuzzy Finder
This config uses `fzf-lua`, which wraps the `fzf` command-line tool inside Neovim.

Install the required search tools:

```bash
# Ubuntu/Debian/WSL
sudo apt install fzf ripgrep fd-find bat

# macOS
brew install fzf ripgrep fd bat
```

**Key Bindings:**
- `<leader>ff` - Find files (fuzzy search)
- `<leader>fg` - Live grep (search text in files)
- `<leader>fb` - Browse open buffers
- `<leader>fh` - Help tags search

**In fzf-lua:**
- Type to fuzzy search
- `Ctrl-j/k` - Navigate results
- `Enter` - Open file
- `Ctrl-x` - Open horizontal split
- `Ctrl-v` - Open vertical split
- `Ctrl-t` - Open in new tab
- `Esc` - Close Telescope

## Code Navigation & Jumping

### Basic Navigation
- `%` - Jump to matching bracket/parenthesis
- `*/#` - Search word under cursor forward/backward
- `n/N` - Next/Previous search result
- `/pattern` - Search forward
- `?pattern` - Search backward
- `f{char}` - Jump to next {char} on line
- `F{char}` - Jump to previous {char} on line
- `t/T` - Jump till (before) char

### Marks & Jumps
- `ma` - Set mark 'a' at cursor
- `'a` - Jump to line of mark 'a'
- `` `a`` - Jump to exact position of mark 'a'
- `''` - Jump to last position
- `Ctrl-o` - Jump back (older position)
- `Ctrl-i` - Jump forward (newer position)
- `:jumps` - View jump list

### Tags (CTags Integration)
**Setup CTags:**
```bash
# Install ctags
sudo apt install universal-ctags  # Ubuntu/Debian
brew install universal-ctags      # macOS

# Generate tags file
ctags -R .                        # In project root
```

**Navigation:**
- `Ctrl-]` - Jump to definition
- `Ctrl-t` - Jump back from definition
- `g]` - List matching tags
- `:tag function_name` - Jump to specific tag
- `:tags` - View tag stack
- `:tn/:tp` - Next/Previous tag

## LSP (Language Server Protocol)

### Installation & Setup
LSP is configured via Mason in this config. Servers auto-install for:
- Lua (`lua_ls`)
- Rust (`rust_analyzer`)
- Python (`pyright`)
- TypeScript/JavaScript (`ts_ls`)
- HTML/CSS (`html`, `cssls`)
- Go (`gopls`)
- JSON (`jsonls`)

**Manage LSP Servers:**
- `:Mason` - Open Mason UI
- `:MasonInstall <server>` - Install specific server
- `:LspInfo` - Current buffer LSP info

### LSP Key Bindings
**Go To:**
- `gd` - Go to definition
- `gD` - Go to declaration
- `gi` - Go to implementation
- `go` - Go to type definition
- `gr` - Show references
- `gl` - Show diagnostics float
- `K` - Hover documentation
- `gs` - Signature help

**Actions:**
- `<F2>` - Rename symbol
- `<F3>` - Format document
- `<F4>` - Code action
- `[d/]d` - Previous/Next diagnostic

### Auto-completion
**In Insert Mode:**
- `Ctrl-Space` - Trigger completion
- `Tab/Shift-Tab` - Navigate suggestions
- `Enter` - Accept completion
- `Ctrl-e` - Close completion menu

## Plugin Features

### GitHub Copilot
GitHub Copilot is currently commented out in `nvim/init.lua`.

### text-generator-nvim
The active config includes a local `text-generator-nvim` plugin:

```lua
{
  dir = "/nvme0n1-disk/code/text-generator-nvim",
  name = "text-generator-nvim",
  event = "InsertEnter",
  config = function()
    require("text-generator").setup({
      min_probability = 0.4,
      max_tokens = 48,
    })
  end,
}
```

Setup checklist:
- Clone or keep the plugin at `/nvme0n1-disk/code/text-generator-nvim`.
- Open Neovim and run `:Lazy sync`.
- Enter insert mode once so the lazy-loaded plugin initializes.
- Run `:checkhealth` and `:messages` if completions do not appear.

### Git Integration (Gitsigns)
**Hunks:**
- `]c` - Next hunk
- `[c` - Previous hunk
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk
- `<leader>hS` - Stage buffer
- `<leader>hu` - Undo stage hunk
- `<leader>hp` - Preview hunk
- `<leader>hb` - Blame line
- `<leader>tb` - Toggle blame
- `<leader>td` - Toggle deleted

### Comments
- `gcc` - Toggle line comment
- `gbc` - Toggle block comment
- `gc` + motion - Comment motion (e.g., `gcap` for paragraph)
- Visual mode `gc` - Comment selection

### Auto-pairs
Automatically closes brackets, quotes, etc.
- Type `(` → `()`
- Type `{` → `{}`
- Type `"` → `""`

### Which-key
Press `<leader>` and wait to see available keybindings.
Leader groups:
- `<leader>c` - Code actions
- `<leader>f` - Find/Files
- `<leader>g` - Git
- `<leader>h` - Git hunks
- `<leader>r` - Rename
- `<leader>w` - Workspace

### Treesitter
Provides enhanced syntax highlighting and code understanding.
- `:TSInstall <language>` - Install language parser
- `:TSUpdate` - Update parsers
- `:TSInstallInfo` - Show installed parsers

### SmoothCursor
Visual cursor animation - automatically active with rainbow trail effect.

## Window & Buffer Management

### Windows
- `Ctrl-w s` - Split horizontal
- `Ctrl-w v` - Split vertical
- `Ctrl-w h/j/k/l` - Navigate windows
- `Ctrl-w H/J/K/L` - Move window
- `Ctrl-w =` - Equal size windows
- `Ctrl-w _` - Max height
- `Ctrl-w |` - Max width
- `Ctrl-w c` - Close window
- `Ctrl-w o` - Close other windows

### Buffers
- `:ls` - List buffers
- `:b <name>` - Switch to buffer
- `:bn/:bp` - Next/Previous buffer
- `:bd` - Delete buffer
- `<leader>fb` - Telescope buffer picker

### Tabs
- `:tabnew` - New tab
- `gt/gT` - Next/Previous tab
- `:tabclose` - Close tab
- `1gt` - Go to tab 1

## Advanced Features

### Macros
- `qa` - Start recording macro 'a'
- `q` - Stop recording
- `@a` - Play macro 'a'
- `@@` - Repeat last macro
- `5@a` - Play macro 5 times

### Registers
- `"ay` - Yank to register 'a'
- `"ap` - Paste from register 'a'
- `:reg` - View all registers
- `"+y` - Copy to system clipboard
- `"+p` - Paste from system clipboard

### Visual Mode
- `v` - Character visual
- `V` - Line visual
- `Ctrl-v` - Block visual
- `gv` - Reselect last visual
- `o` - Toggle cursor end in visual

### Search & Replace
- `:%s/old/new/g` - Replace all in file
- `:%s/old/new/gc` - Replace with confirm
- `:s/old/new/g` - Replace in line
- `:'<,'>s/old/new/g` - Replace in selection

### Folding
- `za` - Toggle fold
- `zo/zc` - Open/Close fold
- `zR/zM` - Open/Close all folds
- `zf` + motion - Create fold

## Configuration

### Config Location
- `~/.config/nvim/init.lua` - Main config
- This repo's active source is `nvim/init.lua`, symlinked by `setup-nvim.sh`
- Shared user modules live in `lua/user/`

### Custom Keymaps
Add to `init.lua`:
```lua
vim.keymap.set('n', '<leader>key', ':command<CR>', {desc = 'Description'})
```

### Install New Plugin
Edit the `spec = { ... }` list in `nvim/init.lua`, then restart Neovim and run `:Lazy sync`.

## Tips & Tricks

1. **Quick Save:** `:w` or `ZZ`
2. **Quick Quit:** `:q` or `ZQ`
3. **Save & Quit:** `:wq` or `:x`
4. **Force Quit:** `:q!`
5. **Reload Config:** `:source %` (in config file)
6. **Check Health:** `:checkhealth`
7. **View Messages:** `:messages`
8. **Command History:** `q:` or `:` then `Ctrl-f`
9. **Insert Mode Completion:**
   - `Ctrl-x Ctrl-f` - File paths
   - `Ctrl-x Ctrl-l` - Whole lines
   - `Ctrl-x Ctrl-o` - Omni completion
10. **Quick Fix List:**
    - `:copen` - Open quickfix
    - `:cn/:cp` - Next/Previous item

## Troubleshooting

### LSP Not Working
1. Check `:LspInfo`
2. Ensure language server installed: `:Mason`
3. Check logs: `:LspLog`

### Space fg says fzf not found
1. Install `fzf`: `sudo apt install fzf` or `brew install fzf`
2. Install `ripgrep`: `sudo apt install ripgrep` or `brew install ripgrep`
3. Restart Neovim
4. From this repo, run `./test_nvim_config.sh`

### Slow Performance
1. Disable plugins temporarily
2. Check `:checkhealth`
3. Profile startup: `nvim --startuptime startup.log`

### Plugin Issues
1. Update plugins: `:Lazy update`
2. Clean unused: `:Lazy clean`
3. Reinstall: Delete `~/.local/share/nvim/lazy` and restart
