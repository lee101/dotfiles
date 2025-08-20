# Helix Tutorial - Complete Guide

## Introduction
Helix is a modern modal text editor with built-in LSP support, tree-sitter syntax highlighting, and multiple selections as a first-class feature. No plugins needed - batteries included!

## Quick Start

### Opening Files
- `hx .` - Open file picker in current directory
- `hx file.txt` - Open specific file
- `hx file1 file2` - Open multiple files
- Space + `f` - File picker (in editor)
- Space + `b` - Buffer picker
- Space + `j` - Jumplist picker

### Essential Movement
- `h/j/k/l` - Left/Down/Up/Right (or arrow keys)
- `w/b` - Word forward/backward
- `W/B` - WORD forward/backward (skip punctuation)
- `e` - End of word
- `0` - Start of line (first character)
- `^` - First non-blank character
- `$` - End of line
- `gg/G` - Start/End of file
- `Ctrl-d/Ctrl-u` - Half page down/up
- `Ctrl-f/Ctrl-b` - Full page down/up
- `%` - Jump to matching bracket

### Modes
- `Normal` - Default mode for movement
- `Insert` (i) - Text insertion
- `Select` (v) - Visual selection
- Press `Esc` to return to Normal mode

## File Browser & Navigation

### Built-in File Picker (FZF-style)
**Access Methods:**
- Space + `f` - Open file picker
- Space + `F` - Open file picker at current file's directory
- `:open <path>` - Open file by path

**In File Picker:**
- Type to fuzzy search
- `Enter` - Open file
- `Ctrl-s` - Open in horizontal split
- `Ctrl-v` - Open in vertical split
- `Ctrl-t` - Open in new tab
- `Tab` - Toggle preview
- `Esc` - Cancel

### Buffer & Symbol Navigation
- Space + `b` - Buffer picker (switch between open files)
- Space + `s` - Symbol picker (functions, classes in current file)
- Space + `S` - Workspace symbol picker (all project symbols)
- Space + `'` - Last picker (reopen)
- Space + `j` - Jumplist picker
- Space + `g` - Diagnostics picker

### Workspace Navigation
- Space + `e` - File explorer (tree view)
- `:cd <path>` - Change working directory
- `:pwd` - Show current directory

## Code Navigation & Jumping

### Quick Jumps
- `f<char>` - Find character forward
- `F<char>` - Find character backward
- `t<char>` - Till character forward (before char)
- `T<char>` - Till character backward
- `Alt-p/Alt-n` - Previous/Next selection
- `;` - Repeat last f/t motion
- `,` - Repeat last f/t motion backwards

### Go To Commands
- `gd` - Go to definition
- `gy` - Go to type definition
- `gr` - Go to references
- `gi` - Go to implementation
- `ga` - Go to last accessed file
- `gm` - Go to last modification
- `gn` - Go to next change
- `gp` - Go to previous change
- `g.` - Go to last edit

### Jump History
- `Ctrl-o` - Jump backward in history
- `Ctrl-i` - Jump forward in history
- Space + `j` - View jumplist

### Search
- `/` - Search forward
- `?` - Search backward
- `n/N` - Next/Previous match
- `*` - Search word under cursor
- Space + `/` - Global search in project (grep)
- Space + `?` - Global search under cursor

## LSP Features (Built-in)

### Auto-configured Languages
Helix auto-detects and uses LSP servers if installed:
- Rust: `rust-analyzer`
- Python: `pylsp` or `pyright`
- JavaScript/TypeScript: `typescript-language-server`
- Go: `gopls`
- C/C++: `clangd`
- And many more...

### Install Language Servers
```bash
# Examples:
npm i -g typescript-language-server  # TypeScript/JavaScript
pip install python-lsp-server        # Python
rustup component add rust-analyzer   # Rust
go install golang.org/x/tools/gopls@latest  # Go
```

### LSP Key Bindings
**Information:**
- `K` - Hover documentation
- Space + `k` - Show documentation popup
- Space + `s` - Symbol picker (current file)
- Space + `S` - Workspace symbols

**Navigation:**
- `gd` - Go to definition
- `gr` - Go to references
- `gi` - Go to implementation
- `gy` - Go to type definition

**Actions:**
- Space + `r` - Rename symbol
- Space + `a` - Code actions
- Space + `h` - Show signature help
- `=` - Format selection
- Space + `=` - Format entire file

**Diagnostics:**
- `]d` - Next diagnostic
- `[d` - Previous diagnostic
- `]D` - Last diagnostic
- `[D` - First diagnostic
- Space + `d` - Show diagnostics picker
- `gl` - Show diagnostics in line

### Auto-completion
Completion triggers automatically while typing.
- `Tab/Shift-Tab` - Navigate completions
- `Enter` - Accept completion
- `Ctrl-Space` - Manually trigger completion
- `Esc` - Cancel completion

## Multiple Selections (Helix's Superpower)

### Creating Selections
- `C` - Copy selection and add below
- `Alt-C` - Copy selection and add above
- `s` - Select all matches in selection
- `S` - Split selection into lines
- `Alt-s` - Split selection on matches
- `;` - Collapse selection to cursor
- `Alt-;` - Flip selection cursor/anchor
- `,` - Keep only primary selection

### Selection Commands
- `x` - Extend selection to line
- `X` - Extend to line bounds
- `%` - Select entire file
- `mi(` - Select inside parentheses
- `ma(` - Select around parentheses
- Similar: `mi[`, `mi{`, `mi"`, `mi'`, `mit` (tag)

### Multi-cursor Workflow
1. Select pattern: `/pattern` then `n`
2. Select all matches: `Alt-*` or `s`
3. Edit all: `c` to change, `i` to insert
4. Align: `&` to align selections

## Editing Operations

### Basic Editing
- `i/a` - Insert before/after selection
- `I/A` - Insert at start/end of line
- `o/O` - Open line below/above
- `c` - Change selection (delete + insert)
- `d` - Delete selection
- `x` - Delete character/selection
- `r<char>` - Replace with character
- `~` - Toggle case
- `Alt-```` - Switch case

### Copy & Paste
- `y` - Yank (copy) selection
- `p/P` - Paste after/before
- `R` - Replace selection with yanked text
- Space + `p` - Paste from system clipboard
- Space + `y` - Yank to system clipboard
- `"<reg>y` - Yank to register
- `"<reg>p` - Paste from register

### Undo/Redo
- `u` - Undo
- `U` - Redo
- `Alt-u` - Earlier in history
- `Alt-U` - Later in history
- `:earlier 5m` - Go back 5 minutes
- `:later 2h` - Go forward 2 hours

### Advanced Editing
- `>/<` - Indent/Outdent
- `J` - Join lines
- `Alt-J` - Join and select
- `Ctrl-a/Ctrl-x` - Increment/Decrement number
- `Q` - Record macro
- `q` - Play macro
- `.` - Repeat last insert

## Window & View Management

### Splits
- `Ctrl-w` + `s` - Horizontal split
- `Ctrl-w` + `v` - Vertical split
- `Ctrl-w` + `h/j/k/l` - Navigate splits
- `Ctrl-w` + `H/J/K/L` - Move split
- `Ctrl-w` + `o` - Close other windows
- `Ctrl-w` + `q` - Close current window

### Tabs (Views)
- `:new` - New empty buffer
- `:buffer-close` (`:bc`) - Close buffer
- `:buffer-next` (`:bn`) - Next buffer
- `:buffer-previous` (`:bp`) - Previous buffer
- `Space` + `b` - Buffer picker

### View Adjustments
- `zh/zl` - Scroll horizontally
- `zt` - Scroll cursor to top
- `zz` - Center cursor
- `zb` - Scroll cursor to bottom
- `Ctrl-e/Ctrl-y` - Scroll view up/down

## Special Features

### Surround Operations
- `ms<char>` - Surround selection with char
- `md<char>` - Delete surrounding char
- `mr<old><new>` - Replace surrounding

Examples:
- `ms(` - Surround with parentheses
- `md"` - Delete surrounding quotes
- `mr'"` - Replace ' with "

### Text Objects
- `w` - Word
- `W` - WORD (includes punctuation)
- `(/)` or `[/]` or `{/}` - Pairs
- `m` - Use with `i` (inside) or `a` (around)
  - `miw` - Inside word
  - `ma(` - Around parentheses
  - `mi"` - Inside quotes
  - `mat` - Around tag (HTML/XML)
  - `mif` - Inside function
  - `mic` - Inside class

### Macros
- `Q` - Start/stop recording macro
- `q` - Replay last macro
- `"<reg>Q` - Record to specific register
- `"<reg>q` - Play from specific register

### Registers
- `"` - Access register
- `"ay` - Yank to register 'a'
- `"ap` - Paste from register 'a'
- `:reg` - View registers
- Special registers:
  - `"_` - Black hole (delete without yanking)
  - `"+` - System clipboard
  - `".` - Last inserted text
  - `"%` - Current filename

## Commands & Configuration

### Essential Commands
- `:w` - Write (save) file
- `:q` - Quit
- `:wq` - Write and quit
- `:q!` - Force quit
- `:wa` - Write all buffers
- `:qa` - Quit all
- `:reload` - Reload current file
- `:config-reload` - Reload configuration
- `:config-open` - Open config file

### Settings
- `:set <option>` - Set option
- `:set-option` - Set option for current view
- `:toggle <option>` - Toggle boolean option

Common options:
- `:set line-number relative` - Relative line numbers
- `:set cursorline true` - Highlight current line
- `:set auto-save true` - Enable auto-save
- `:set mouse false` - Disable mouse

### Themes
- `:theme` - List/select theme
- `:theme <name>` - Set specific theme
- Popular themes: `onedark`, `gruvbox`, `catppuccin`

### Help
- `:help` - Open help
- `:help <topic>` - Help on specific topic
- F1 - Context-sensitive help

## Configuration File

Location: `~/.config/helix/config.toml`

Example configuration:
```toml
theme = "onedark"

[editor]
line-number = "relative"
cursorline = true
auto-save = false
rulers = [80, 120]
idle-timeout = 400
completion-trigger-len = 2

[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"

[editor.file-picker]
hidden = false

[editor.whitespace.render]
space = "all"
tab = "all"

[editor.indent-guides]
render = true

[keys.normal]
# Custom keybindings
C-s = ":w" # Ctrl-s to save
g-a = "code_action" # ga for code actions

[keys.insert]
C-s = ["normal_mode", ":w"] # Save in insert mode
```

## Language-Specific Setup

### Languages Configuration
Location: `~/.config/helix/languages.toml`

Example for Python with formatter:
```toml
[[language]]
name = "python"
formatter = { command = "black", args = ["-", "-q"] }
auto-format = true

[[language]]
name = "rust"
auto-format = true

[[language]]
name = "typescript"
formatter = { command = "prettier", args = ["--parser", "typescript"] }
auto-format = true
```

## Tips & Tricks

### Productivity Boosters
1. **Multi-cursor magic:** `/pattern<Enter>` then `Alt-*` selects all
2. **Quick surround:** Select text, then `ms(` for parentheses
3. **Smart selection:** `x` extends to line, `%` selects all
4. **Jump to changes:** `g.` goes to last edit
5. **Quick save:** Map `Ctrl-s` in config
6. **Persistent undo:** Helix saves undo history between sessions
7. **Smart indent:** `>` and `<` work on selections
8. **Quick comment:** No default binding, but LSP provides it via code actions

### Common Workflows

**Rename Variable Everywhere:**
1. Place cursor on variable
2. `*` to select word
3. `Alt-*` to select all occurrences
4. `c` to change all

**Search and Replace:**
1. `%` to select all
2. `s` to enter select mode
3. Type pattern to match
4. `c` to change all matches

**Format Document:**
- Space + `=` formats entire file
- Select text then `=` formats selection

**Quick File Switch:**
- Space + `b` for buffer picker
- Space + `f` for file picker
- `ga` to alternate file

### Troubleshooting

**LSP Not Working:**
1. Check language server installed: `which <lsp-name>`
2. Check `:log-open` for errors
3. Verify in `:language-server-status`
4. Check `~/.config/helix/languages.toml`

**Key Bindings Not Working:**
1. Check `:help keys` for defaults
2. Verify custom bindings in `config.toml`
3. Some terminals capture certain keys

**Performance Issues:**
1. Disable renders in config:
   ```toml
   [editor.whitespace.render]
   space = "none"
   ```
2. Reduce idle-timeout
3. Check `:log-open` for errors

**Syntax Highlighting Issues:**
- Helix uses tree-sitter, grammar should auto-install
- Try `:config-reload`
- Check `:health` for issues

## Helix vs Vim/Neovim

### Key Differences
1. **Selection-first:** Helix selects then acts (vs Vim's verb-noun)
2. **Built-in LSP:** No plugins needed
3. **Multiple cursors:** First-class feature
4. **Tree-sitter:** Better syntax understanding
5. **No plugins:** Everything built-in
6. **Persistent undo:** Survives restarts
7. **Modern defaults:** Better out-of-box experience

### Migration Tips for Vim Users
- Movement is similar (hjkl)
- `x` extends selection (not delete char)
- `s` is select (not substitute)
- No `:s` command (use select + change)
- No leader key (use Space)
- Registers work differently
- Macros use `Q/q` (not `q/@`)

## Quick Reference Card

### Most Used Commands
| Key | Action |
|-----|--------|
| Space-f | File picker |
| Space-b | Buffer picker |
| Space-s | Symbol picker |
| Space-/ | Project search |
| gd | Go to definition |
| K | Hover docs |
| Space-a | Code actions |
| Space-r | Rename |
| c | Change selection |
| ms( | Surround with () |
| % | Select all |
| x | Extend to line |
| / | Search |
| * | Search word |

### Mode Indicators
- `NOR` - Normal mode
- `INS` - Insert mode
- `SEL` - Select/Visual mode
- `REP` - Replace mode

Remember: Helix is selection-based. Think "select then act" rather than "verb then noun"!