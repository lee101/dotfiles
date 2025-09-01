# Complete Neovim Configuration Guide

## 🚀 Leader Key = SPACE

Your leader key is set to **SPACE** (`<leader>` = spacebar). This is the primary modifier key for most custom commands in your config.

## 📁 File Navigation & Search

### FZF-Lua (Your Fuzzy Finder)
FZF-Lua is your powerful fuzzy finder, configured as a Telescope replacement with better performance.

#### Core File Operations
| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>ff` | Find Files | Fuzzy search all files in project |
| `<Ctrl-p>` | Find Files | Alternative quick access |
| `<leader>fa` | Find in Current Dir | Search files in current file's directory |
| `<leader>fh` | Recent Files | Browse recently opened files |

#### Text Search (Grep)
| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>fg` | Live Grep | Search text content across all files |
| `<Ctrl-f>` | Live Grep | Quick grep access |
| `<leader>fw` | Grep Word | Search word under cursor (exact) |
| `<leader>fW` | Grep WORD | Search WORD under cursor (with punctuation) |
| `<leader>fr` | Resume Grep | Continue last search where you left off |

#### Inside FZF-Lua Window
- **Navigate:** `Ctrl-j/k` or arrow keys
- **Select:** `Enter` to open
- **Preview:** Automatic preview on the right
- **Multi-select:** `Tab` to mark multiple files
- **Actions:**
  - `Ctrl-x` = Open in horizontal split
  - `Ctrl-v` = Open in vertical split
  - `Ctrl-t` = Open in new tab
  - `Esc` = Cancel

### NvimTree (File Explorer)
Your file tree explorer with git integration and icons.

#### Opening & Navigation
| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>e` | Toggle Tree | Show/hide file explorer |
| `<leader>E` | Focus Tree | Jump to file tree window |
| `<leader>tf` | Find File in Tree | Locate current file |
| `<leader>tc` | Collapse All | Collapse all folders |

#### Inside NvimTree
**Navigation:**
- `j/k` or arrows = Move up/down
- `h/l` = Close/open folder or navigate
- `Enter` or `o` = Open file/folder
- `Tab` = Preview file without leaving tree
- `Ctrl-x` = Open in horizontal split
- `Ctrl-v` = Open in vertical split
- `Ctrl-t` = Open in new tab

**File Operations:**
- `a` = Create new file/folder (end with `/` for folder)
- `d` = Delete
- `r` = Rename
- `x` = Cut
- `c` = Copy
- `p` = Paste
- `y` = Copy filename
- `Y` = Copy relative path
- `gy` = Copy absolute path

**View Controls:**
- `H` = Toggle hidden files (dotfiles)
- `I` = Toggle git ignored files
- `R` = Refresh tree
- `W` = Collapse all folders
- `E` = Expand all folders
- `f` = Start live filter (type to filter visible files)
- `F` = Clear filter
- `q` = Close tree

**Git Indicators in Tree:**
- ✗ = Modified/unstaged
- ✓ = Staged
- ★ = Untracked
- ➜ = Renamed
- = Deleted

### Oil.nvim (Alternative File Manager)
A buffer-based file manager that lets you edit directories like text.

| Keybinding | Action |
|------------|--------|
| `<leader>o` | Open Oil | Opens current directory as editable buffer |

In Oil buffer:
- Edit filenames directly like text
- `dd` to mark for deletion
- Save (`:w`) to apply changes
- `-` to go up a directory

## 🔧 LSP (Language Server Protocol)

### Core LSP Navigation
| Keybinding | Action | Description |
|------------|--------|-------------|
| `gd` | Go to Definition | Jump to where symbol is defined |
| `K` | Hover Info | Show documentation popup |
| `<leader>rn` | Rename | Rename symbol across project |
| `<leader>ca` | Code Action | Show available fixes/refactors |

### LSP Search with FZF
| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>fs` | Document Symbols | Find symbols in current file |
| `<leader>fS` | Workspace Symbols | Find symbols across project |
| `<leader>fd` | Find Definitions | Search all definitions |
| `<leader>fD` | Find Declarations | Search declarations |
| `<leader>fi` | Find Implementations | Search implementations |
| `<leader>ft` | Type Definitions | Search type definitions |
| `<leader>fR` | Find References | Find all references to symbol |

## 🚦 Git Integration

### Fugitive (Git Commands)
| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>gs` | Git Status | Open git status window |
| `<leader>gc` | Git Commit | Create commit |
| `<leader>gp` | Git Push | Push to remote |
| `<leader>gl` | Git Pull | Pull from remote |
| `<leader>gb` | Git Blame | Show blame for current file |
| `<leader>gd` | Git Diff | Show diff in split |
| `<leader>gw` | Git Write | Stage current file |

### Gitsigns (Inline Git)
| Keybinding | Action | Description |
|------------|--------|-------------|
| `]c` | Next Change | Jump to next git change |
| `[c` | Previous Change | Jump to previous change |
| `<leader>hs` | Stage Hunk | Stage current change block |
| `<leader>hr` | Reset Hunk | Undo current change |
| `<leader>hp` | Preview Hunk | Show change details |
| `<leader>hb` | Blame Line | Show who changed this line |
| `<leader>tb` | Toggle Blame | Toggle inline blame display |

### Git with FZF
| Keybinding | Action |
|------------|--------|
| `<leader>gc` | Browse commits |
| `<leader>gb` | Browse branches |
| `<leader>gf` | Browse git files |
| `<leader>gs` | Browse git status |

### Neogit & Diffview
| Keybinding | Action |
|------------|--------|
| `<leader>gg` | Open Neogit interface |
| `<leader>dv` | Open Diffview |
| `<leader>dc` | Close Diffview |
| `<leader>dh` | File history |
| `<leader>df` | Current file history |

## 🤖 GitHub Copilot

| Keybinding | Action | Mode |
|------------|--------|------|
| `Tab` or `<Ctrl-j>` | Accept suggestion | Insert |
| `<Ctrl-]>` | Next suggestion | Insert |
| `<Ctrl-[>` | Previous suggestion | Insert |
| `<Ctrl-\>` | Dismiss suggestion | Insert |

## ⚡ Motion & Navigation

### Hop (EasyMotion-style)
Quick jumps to any visible location:

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>j` | Hop Line | Jump to any visible line |
| `<leader>w` | Hop Word | Jump to any visible word |
| `<leader>s` | Hop Char | Jump to any character |

### Leap (Modern Motion)
Default leap mappings are active:
- `s` + 2 chars = Jump forward
- `S` + 2 chars = Jump backward

## 💬 Comments

| Keybinding | Action | Mode |
|------------|--------|------|
| `gcc` | Toggle line comment | Normal |
| `gc` + motion | Comment motion | Normal |
| `<leader>/` | Toggle comment | Normal/Visual |
| `gbc` | Block comment | Normal |

Examples:
- `gcap` = Comment a paragraph
- `gc3j` = Comment 3 lines down

## 🪟 Window Management

### Window Navigation
| Keybinding | Action |
|------------|--------|
| `<Alt-h>` | Move to left window |
| `<Alt-j>` | Move to window below |
| `<Alt-k>` | Move to window above |
| `<Alt-l>` | Move to right window |

### Window Operations
| Keybinding | Action |
|------------|--------|
| `<Ctrl-w>s` | Split horizontal |
| `<Ctrl-w>v` | Split vertical |
| `<Ctrl-w>=` | Equal size all windows |
| `<Ctrl-w>_` | Maximize height |
| `<Ctrl-w>|` | Maximize width |
| `<Ctrl-w>c` | Close window |
| `<Ctrl-w>o` | Close other windows |

## 📑 Buffers & Tabs

### Buffer Navigation
| Keybinding | Action |
|------------|--------|
| `<leader>fb` | Browse buffers with FZF |
| `<leader>bn` | Next buffer |
| `<leader>bp` | Previous buffer |
| `<leader>bd` | Delete buffer |

### Tab Navigation
| Keybinding | Action |
|------------|--------|
| `<Ctrl-t>` | New tab |
| `<Ctrl-Right>` | Next tab |
| `<Ctrl-Left>` | Previous tab |
| `gt` | Go to next tab |
| `gT` | Go to previous tab |

## 🎯 Essential Vim Overrides

### Mode Changes
| Keybinding | Action | Description |
|------------|--------|-------------|
| `jj` | Exit insert mode | Faster than Esc |
| `;` | Enter command mode | Swapped with : |
| `:` | Repeat last f/F/t/T | Swapped with ; |

### Quick Actions
| Keybinding | Action |
|------------|--------|
| `<leader>w` | Save file |
| `<leader>q` | Quit |
| `<leader>x` | Save and quit |
| `<leader>h` | Clear search highlight |
| `<Ctrl-s>` | Save (works in insert too) |
| `<Ctrl-z>` | Undo |
| `<Ctrl-y>` | Redo |

### Enhanced Movement
| Keybinding | Action | Description |
|------------|--------|-------------|
| `j/k` | Smart j/k | Moves by display line (wrapped text) |
| `n/N` | Centered search | Keeps cursor centered |
| `<Ctrl-d>` | Page down centered | Keeps cursor centered |
| `<Ctrl-u>` | Page up centered | Keeps cursor centered |
| `*/#` | Search word centered | Searches and centers |
| `zj` | Create blank line below | Without entering insert |
| `zk` | Create blank line above | Without entering insert |

### Text Manipulation
| Keybinding | Action |
|------------|--------|
| `Y` | Yank to end of line |
| `J` | Join lines (cursor stays) |
| `v` then `J` | Move selected lines down |
| `v` then `K` | Move selected lines up |
| `<leader>sr` | Replace word under cursor |
| `<leader>S` | Quick substitute command |

## 🔌 Other Plugins

### Surround (Text Objects)
- `ys{motion}{char}` = Add surround
- `cs{old}{new}` = Change surround
- `ds{char}` = Delete surround

Examples:
- `ysiw"` = Surround word with quotes
- `cs"'` = Change quotes to single quotes
- `ds(` = Delete parentheses

### Terminal (ToggleTerm)
| Keybinding | Action |
|------------|--------|
| `<Ctrl-\>` | Toggle floating terminal |
| `<Esc>` | Exit terminal mode |

### Autopairs
Automatically closes brackets/quotes:
- Type `(` → `()`
- Type `{` → `{}`
- Type `"` → `""`

### Which-Key
Press `<leader>` and wait to see available commands grouped by category.

## 🔍 Search Helpers

### FZF-Lua Search Patterns
- **Exact match:** `'word` (prefix with single quote)
- **Suffix match:** `word$`
- **Prefix match:** `^word`
- **Exclude:** `!word`

### Inside Quickfix/Location List
| Keybinding | Action |
|------------|--------|
| `<leader>fq` | Browse quickfix with FZF |
| `<leader>fl` | Browse location list with FZF |

## 📝 Auto-completion

### Completion Navigation (Insert Mode)
| Keybinding | Action |
|------------|--------|
| `<Ctrl-Space>` | Trigger completion |
| `<Ctrl-n>` | Next item |
| `<Ctrl-p>` | Previous item |
| `<Enter>` | Accept completion |
| `<Ctrl-e>` | Cancel completion |

Note: Tab is reserved for Copilot, use Ctrl-n/p for completion navigation.

## 💡 Pro Tips

1. **Leader Key Timeout:** After pressing `<leader>`, Which-Key will show available options if you wait
2. **File Preview:** In FZF-Lua, files are automatically previewed on the right
3. **Git Integration:** File tree shows git status with colored icons
4. **Smart Case Search:** Searches are case-insensitive unless you use uppercase
5. **Persistent Undo:** Your undo history persists between sessions
6. **Jump List:** Use `<Ctrl-o>` and `<Ctrl-i>` to navigate through your location history
7. **Marks:** Set with `ma`, jump with `'a` (line) or `` `a`` (exact position)
8. **Macros:** Record with `qa`, stop with `q`, play with `@a`
9. **Registers:** Access with `"`, system clipboard is `"+`
10. **Folding:** `za` toggles fold, `zR/zM` opens/closes all

## 🛠️ Configuration Files

- Main config: `~/.config/nvim/init.lua`
- Plugin list: Managed by Lazy.nvim in init.lua
- LSP servers: Auto-installed via Mason

## 🚑 Troubleshooting

- **Check health:** `:checkhealth`
- **LSP status:** `:LspInfo`
- **Mason UI:** `:Mason`
- **Update plugins:** `:Lazy update`
- **View messages:** `:messages`
- **Plugin profiling:** `:Lazy profile`