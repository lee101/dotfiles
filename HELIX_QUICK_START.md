# Helix Quick Reference for Vim Users

## ✅ Configuration Fixed!

Your Helix configuration is now working properly with:
- ✅ No configuration errors
- ✅ Relative line numbers
- ✅ Smart case search  
- ✅ System clipboard (x-clip)
- ✅ Mouse support
- ✅ `jj` escape mapping
- ✅ `;` for command mode
- ✅ Centered search results

## 🚀 Quick Start

```bash
# Launch Helix
hx

# Open a file
hx filename.txt

# Interactive tutorial
hx
:tutor
```

## ⚡ Essential Commands

### Your Familiar Vim Commands (Work the Same)
- `:w` - Save file
- `:q` - Quit
- `:wq` - Save and quit
- `/text` - Search forward
- `?text` - Search backward
- `jj` - Escape to normal mode (in insert)
- `;` - Command mode (like `:` in Vim)

### Basic Navigation (Same as Vim)
- `h j k l` - Move left/down/up/right
- `w b e` - Word movement
- `0 $` - Start/end of line
- `gg G` - Start/end of file
- `f<char>` - Find character forward
- `t<char>` - Till character forward

### Helix Selection Model (NEW!)
1. **Select first, then act** (vs Vim's act then select)
2. Examples:
   - `w` - Select word
   - `d` - Delete selection
   - `c` - Change selection
   - `y` - Yank selection

### Common Patterns
```
Vim: dw    →  Helix: wd    (select word, delete)
Vim: ciw   →  Helix: wc    (select word, change)
Vim: yap   →  Helix: py    (select paragraph, yank)
Vim: di"   →  Helix: "d    (select inside quotes, delete)
```

### Space Menu (NEW!)
- `Space f` - File picker
- `Space b` - Buffer picker  
- `Space s` - Save file
- `Space q` - Quit

### Multiple Cursors (NEW!)
- `C` - Add cursor on next line
- `Alt-C` - Add cursor on previous line
- `,` - Remove primary cursor
- `;` - Collapse to primary cursor

## 🎯 Practice Exercise

1. Launch Helix: `hx`
2. Try the tutorial: `:tutor`
3. Open your test file: `hx test.js`
4. Practice selection:
   - `w` to select a word
   - `d` to delete it
   - `u` to undo
5. Try multiple cursors:
   - `x` to select line
   - `C` to add cursor below
   - Type something to edit both lines

## 🔧 Your Custom Keys
- `jj` - Normal mode (works in insert)
- `;` - Command mode  
- `n/N` - Search next/previous (auto-centered)

## 💡 Pro Tips
1. **Embrace the selection model** - it's powerful once you get used to it
2. **Use Space menu** - it's your main command palette
3. **Multiple cursors are easy** - much simpler than in Vim
4. **Everything is built-in** - no plugins needed
5. **LSP works automatically** - just install language servers

## 🆘 If Something Goes Wrong
```bash
# Check configuration
hx --health

# Reset config (backup first!)
mv ~/.config/helix ~/.config/helix.backup
```

## 📁 Config Locations
- Main config: `~/.config/helix/config.toml`
- Languages: `~/.config/helix/languages.toml`
- Themes: `~/.config/helix/themes/`

Start with the basics and gradually explore more features!
