# Vim to Helix Quick Migration Guide

## 🔄 Key Paradigm Shift

**Vim**: Action → Motion (e.g., `dw` = delete word)  
**Helix**: Selection → Action (e.g., `w` then `d` = select word, then delete)

## 🎯 Your Familiar Mappings (Preserved)

| Your Vim Habit | Helix Equivalent | Status |
|----------------|------------------|--------|
| `jj` → ESC | `jj` → Normal mode | ✅ Works exactly the same |
| `;` → Command mode | `;` → Command mode | ✅ Works exactly the same |
| `Space` → Fold toggle | `za` → Fold toggle | ✅ Moved to 'z' prefix |
| `Ctrl+t` → New tab | `Space f` → File picker | ✅ Different key, same function |
| `n/N` → Search + center | `n/N` → Search + center | ✅ Same centering behavior |

## ⚡ Essential Helix Commands

### Movement (Same as Vim)
- `h j k l` - Basic movement
- `w b e` - Word movement  
- `f F t T` - Find/till character
- `/ ?` - Search forward/backward
- `g g` / `G` - Go to start/end

### Selection (New Paradigm)
- `w` - Select word
- `W` - Select WORD
- `x` - Select line
- `p` - Select paragraph
- `%` - Select whole file

### Actions (Apply to Selection)
- `d` - Delete selection
- `c` - Change selection
- `y` - Yank selection
- `p` - Paste

### Examples
```
Vim: dw          → Helix: wd
Vim: ciw         → Helix: wc  
Vim: yap         → Helix: py
Vim: di"         → Helix: "d
```

## 🚀 Getting Started Workflow

1. **Run the setup script:**
   ```bash
   ./setup-helix.sh
   ```

2. **Launch and try tutorial:**
   ```bash
   hx
   :tutor
   ```

3. **Start with familiar commands:**
   - `:w` to save
   - `:q` to quit
   - `/text` to search
   - `jj` to escape insert mode

4. **Practice the selection paradigm:**
   - Select a word: `w`
   - Delete it: `d`
   - Undo: `u`

## 📁 Your Custom Config Applied

- ✅ 3-space indentation (from your vimrc)
- ✅ Relative line numbers
- ✅ Smart case search
- ✅ Trailing whitespace removal
- ✅ Mouse support
- ✅ System clipboard integration
- ✅ Catppuccin theme (from your nvim config)

## 🎨 Quick Theme Test

Try different themes to find your favorite:
```
:theme catppuccin_mocha    # Your default
:theme onedarker          # Dark theme
:theme gruvbox            # Popular theme  
:theme github_light       # Light theme
```

## 💡 Pro Tips for Vim Users

1. **Don't fight the selection model** - embrace it!
2. **Use Space menu** - `Space` then `f` for files, `b` for buffers
3. **Multiple cursors are easy** - `C` for cursor below, `A-C` for above
4. **Tree-sitter is built-in** - better syntax highlighting automatically
5. **LSP works out of the box** - no complex plugin setup needed

Start with these basics and gradually explore more Helix features!
