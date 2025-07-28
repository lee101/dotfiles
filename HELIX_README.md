# Helix Editor Configuration

Welcome to your Helix configuration! This setup migrates your Vim/Neovim preferences to Helix while embracing Helix's unique paradigms.

## 🚀 Quick Start

1. **Install and Setup:**
   ```bash
   ./setup-helix.sh
   ```

2. **Launch Helix:**
   ```bash
   hx
   ```

3. **Try the interactive tutorial:**
   ```bash
   hx
   :tutor
   ```

## 🔧 Key Configuration Highlights

### Migrated from Your Vim/Neovim Config

| Vim/Neovim Feature | Helix Equivalent | Notes |
|-------------------|------------------|-------|
| `jj` in insert mode → ESC | `jj` in insert mode → Normal | ✅ Same behavior |
| `set number relativenumber` | `line-number = "relative"` | ✅ Relative line numbers |
| `set shiftwidth=3 softtabstop=3` | `indent = { tab-width = 3, unit = "   " }` | ✅ 3-space indentation |
| `set expandtab` | Default behavior | ✅ Spaces over tabs |
| `set smartcase` | `smart-case = true` | ✅ Smart case search |
| `nnoremap <space> za` | `z = { a = "toggle_fold" }` | ✅ Fold toggle |
| `nnoremap ; :` | `";" = "command_mode"` | ✅ Semicolon for commands |
| `nnoremap n nzz` | `"n" = ["search_next", "align_view_center"]` | ✅ Centered search |
| `set mouse=a` | `mouse = true` | ✅ Mouse support |
| Trim trailing whitespace | `trim-trailing-whitespace = true` | ✅ Auto-trim |
| System clipboard | `clipboard-provider = "x-clip"` | ✅ System clipboard |

### New Helix-Specific Features

- **Selection → Action paradigm**: Select text first, then perform actions
- **Multiple cursors**: Native multiple cursor support
- **Tree-sitter**: Built-in syntax highlighting and text objects
- **LSP integration**: Language servers work out of the box
- **No plugin system**: Everything you need is built-in

## ⌨️ Key Mappings

### Normal Mode

| Key | Action | Notes |
|-----|--------|-------|
| `jj` (in insert) | Normal mode | Your familiar escape |
| `;` | Command mode | Like `:` in Vim |
| `Space f` | File picker | Like `C-t` for new tab |
| `Space b` | Buffer picker | Switch between open files |
| `Space s` | Save file | Quick save |
| `Space q` | Quit | Quick quit |
| `C-right` | Next buffer | Tab navigation equivalent |
| `C-left` | Previous buffer | Tab navigation equivalent |
| `n` | Search next (centered) | Your centered search |
| `N` | Search previous (centered) | Your centered search |
| `za` | Toggle fold | Like Space in your Vim config |

### Essential Helix Commands

| Command | Action |
|---------|--------|
| `:w` | Write/save file |
| `:q` | Quit |
| `:wq` | Write and quit |
| `:help` | Show help |
| `:theme` | Change theme |
| `:set` | Modify settings |

## 🎨 Themes

Your config uses `catppuccin_mocha` (similar to your Neovim setup). To change themes:

```
:theme <TAB>  # See available themes
:theme dark_plus
:theme onedarker
:theme gruvbox
```

## 📁 File Structure

```
~/.config/helix/
├── config.toml      # Main configuration
├── languages.toml   # Language-specific settings
└── themes/          # Custom themes (if any)
```

## 🔍 Key Differences from Vim/Neovim

### Selection First Paradigm

In Vim: `dw` (delete word)
In Helix: `w` (select word) → `d` (delete selection)

### Common Text Objects

| Object | Description |
|--------|-------------|
| `w` | Select word |
| `W` | Select WORD |
| `p` | Select paragraph |
| `(` | Select inside parentheses |
| `[` | Select inside brackets |
| `"` | Select inside quotes |
| `f<char>` | Select to character |
| `t<char>` | Select until character |

### Multiple Cursors

- `C` - Duplicate cursor to next line
- `A-C` - Duplicate cursor to previous line  
- `;` - Collapse to primary cursor
- `,` - Remove primary cursor

### Advanced Selection

- `x` - Select line
- `X` - Extend selection to line bounds
- `J` - Join lines
- `K` - Keep selections matching regex
- `A-K` - Remove selections matching regex

## 🛠️ Language Server Configuration

Your setup includes configurations for:

- **JavaScript/TypeScript**: `typescript-language-server`
- **Python**: `pylsp`
- **Rust**: `rust-analyzer`
- **HTML/CSS**: `vscode-langservers-extracted`
- **JSON**: `vscode-json-languageserver`

## 🔧 Customization Tips

### Adding New Key Mappings

Edit `~/.config/helix/config.toml`:

```toml
[keys.normal]
"C-n" = "file_picker"  # Ctrl+n for file picker

[keys.insert]
"C-space" = "completion"  # Ctrl+Space for completion
```

### Changing Indentation for Specific Languages

Edit `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "python"
indent = { tab-width = 4, unit = "    " }  # 4 spaces for Python
```

### Custom Themes

Place custom themes in `~/.config/helix/themes/mytheme.toml`

## 📚 Learning Resources

1. **Built-in tutorial**: `:tutor`
2. **Help system**: `:help`
3. **Official documentation**: https://docs.helix-editor.com/
4. **Community themes**: https://github.com/helix-editor/helix/wiki/Themes

## 🤝 Migration Tips

### From Vim Habits

1. **Think selection first**: Instead of `diw`, think `wd` (select word, then delete)
2. **Use Space**: Space is your friend for commands and pickers
3. **Embrace multiple cursors**: They're much easier than in Vim
4. **Trust the built-ins**: No need for plugins, everything is included

### Gradually Transition

1. Keep using `:w`, `:q`, and other command-mode commands
2. Your `jj` escape and `;` for commands work the same
3. Search with `/` and `?` works similarly
4. Your mouse and clipboard preferences are preserved

## 🐛 Troubleshooting

### Clipboard not working?
- Linux: Install `xclip` or `wl-clipboard`
- macOS: Should work out of the box
- Windows: Should work out of the box

### Language server not working?
```bash
:lsp-restart  # Restart language server
:checkhealth  # Check LSP status
```

### Reset to defaults?
```bash
mv ~/.config/helix ~/.config/helix.backup
```

## 🎯 Quick Reference Card

Print this out and keep it handy while learning:

```
SELECTION:           NAVIGATION:          EDITING:
w - word             h j k l - movement   d - delete
W - WORD             f/F - find char      c - change  
p - paragraph        t/T - till char      y - yank
( ) [ ] " ' - pairs  / ? - search         p - paste
x - line             g g/G - goto         u - undo
% - whole file       C-u/d - page up/dn   U - redo
                     m - goto matching    J - join lines

MULTI-CURSOR:        COMMAND MODE:        SPACE MENU:
C - cursor below     ; - command mode     f - files
A-C - cursor above   :w - write          b - buffers  
, - remove primary   :q - quit           s - save
; - collapse all     :help - help        q - quit
```

Happy editing with Helix! 🎉
