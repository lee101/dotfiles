# Neovim Cheat Sheet - Essential Commands

**LEADER = SPACE**

## Most Used Commands

### Files & Search
```
Space ff     Find files (or Ctrl-p)
Space fg     Search text in files (or Ctrl-f)  
Space e      Toggle file tree
Space fb     Browse open buffers
Space fw     Search word under cursor
```

### Navigation
```
gd           Go to definition
K            Show documentation
Space j      Jump to any line (Hop)
Space w      Jump to any word (Hop)
s{2chars}    Jump forward (Leap)
```

### Git
```
Space gs     Git status
]c / [c      Next/prev git change
Space hs     Stage change
Space hr     Reset change
Space hp     Preview change
```

### Editing
```
gcc          Toggle comment
Space /      Comment line/selection
cs"'         Change " to ' (surround)
ysiw"        Surround word with "
Space rn     Rename symbol
Space ca     Code actions
```

### Windows & Buffers
```
Alt-h/j/k/l  Navigate windows
Ctrl-w v     Vertical split
Ctrl-w s     Horizontal split
Space bn/bp  Next/prev buffer
Space w/q    Save/quit
```

### Copilot
```
Tab          Accept suggestion
Ctrl-]       Next suggestion
Ctrl-[       Prev suggestion
```

### Quick Tips
- Press `jj` to exit insert mode
- Press `;` for command mode (not `:`)
- Wait after pressing Space to see options
- In file tree: `a` create, `d` delete, `r` rename
- In FZF: `Tab` to multi-select, preview on right