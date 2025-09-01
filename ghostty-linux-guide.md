# Ghostty Terminal Guide for Linux

## Important: Linux System Shortcut Conflicts

When configuring Ghostty on Linux, avoid these common system shortcuts:
- **Alt+Tab** - System window switching
- **Ctrl+Alt+Left/Right/Up/Down** - Workspace switching
- **Super+Left/Right/Up/Down** - Window tiling/snapping
- **Alt+F4** - Close window
- **Ctrl+Alt+T** - Open terminal (Ubuntu/GNOME)
- **Ctrl+Alt+L** - Lock screen
- **Alt+F1-F12** - System/WM functions

Our keybindings use **Ctrl+Shift** as the primary modifier to avoid these conflicts.

## Window Management

### Windows & Tabs
- **New Window**: `new_window` - Opens a new Ghostty window
- **New Tab**: `new_tab` - Creates a new tab in current window
- **Navigate Tabs**:
  - `previous_tab` - Go to previous tab
  - `next_tab` - Go to next tab  
  - `last_tab` - Go to the highest-indexed tab
  - `goto_tab` - Go to specific tab number (1-indexed)
  - `move_tab` - Move tab position (e.g., `move_tab:-1` for left, `move_tab:1` for right)
- **Close Operations**:
  - `close_surface` - Close current surface (window/tab/split)
  - `close_tab` - Close entire tab with all splits
  - `close_window` - Close entire window with all tabs
  - `close_all_windows` - Close all Ghostty windows

### Split Management
- **Create Splits**: `new_split` with directions:
  - `new_split:right` - Split to the right
  - `new_split:down` - Split downward
  - `new_split:left` - Split to the left
  - `new_split:up` - Split upward
  - `new_split:auto` - Split along larger dimension
- **Navigate Splits**: `goto_split` with directions:
  - `goto_split:left`, `goto_split:right` - Move left/right
  - `goto_split:up`, `goto_split:down` - Move up/down
  - `goto_split:previous` - Go to previous split
  - `goto_split:next` - Go to next split
- **Resize Splits**: `resize_split` with direction and pixels:
  - Example: `resize_split:up,10` - Move divider up 10 pixels
  - Directions: `up`, `down`, `left`, `right`
- **Split Features**:
  - `toggle_split_zoom` - Zoom/unzoom current split
  - `equalize_splits` - Make all splits equal size

## Window Controls

### Display Modes
- `toggle_fullscreen` - Toggle fullscreen mode
- `toggle_maximize` - Toggle window maximization (Linux only)
- `toggle_window_decorations` - Toggle title bar on/off (Linux only)

### Quick Terminal
- `toggle_quick_terminal` - Show/hide quick access terminal
  - Appears on demand from keybinding
  - Disappears when loses focus
  - State preserved between appearances
  - Supports splits but not tabs
  - For global access: `keybind = global:cmd+grave_accent=toggle_quick_terminal`

## Configuration & Tools

### Configuration Management
- `open_config` - Open config file in default editor
- `reload_config` - Reload and apply configuration changes

### Development Tools
- `inspector` - Control terminal inspector:
  - `inspector:toggle` - Toggle visibility
  - `inspector:show` - Show inspector
  - `inspector:hide` - Hide inspector

### Application Controls
- `toggle_visibility` - Show/hide all windows
- `quit` - Exit Ghostty

## Keyboard Shortcuts Reference

### Text Selection and Clipboard Actions
- **Select All**: `select_all` - Select all text in terminal
- **Copy Text**: `copy_to_clipboard` - Copy selected text
- **Paste Text**: `paste_from_clipboard` - Paste from clipboard  
- **Copy Link**: `copy_link` - Copy URL under cursor
- **Clear Selection**: `clear_selection` - Clear current text selection

### Scrolling and Navigation
- **Scroll Page Up**: `scroll_page_up` - Move up one page
- **Scroll Page Down**: `scroll_page_down` - Move down one page
- **Scroll Line Up**: `scroll_line_up` - Move up one line
- **Scroll Line Down**: `scroll_line_down` - Move down one line
- **Scroll to Top**: `scroll_to_top` - Jump to beginning of scrollback
- **Scroll to Bottom**: `scroll_to_bottom` - Jump to current prompt
- **Scroll to Prompt**: `scroll_to_prompt` - Navigate between shell prompts:
  - `scroll_to_prompt:previous` - Previous command
  - `scroll_to_prompt:next` - Next command

### Font Size Control
- **Increase Font**: `increase_font_size` - Make text larger
- **Decrease Font**: `decrease_font_size` - Make text smaller  
- **Reset Font**: `reset_font_size` - Return to default size

### Search Functions
- **Find Text**: `text_search` - Open search overlay
- **Find Next**: `text_search:next` - Jump to next match
- **Find Previous**: `text_search:previous` - Jump to previous match

## Linux-Friendly Keybindings (Avoiding System Conflicts)

**IMPORTANT**: These keybindings avoid Linux system shortcuts like Alt+Tab, Ctrl+Alt+arrows, etc.

```
# === WINDOW & TAB MANAGEMENT ===
keybind = ctrl+shift+n=new_window
keybind = ctrl+shift+t=new_tab
keybind = ctrl+shift+w=close_tab
keybind = ctrl+tab=next_tab
keybind = ctrl+shift+tab=previous_tab
keybind = ctrl+shift+l=last_tab

# Go to specific tabs (safe - no conflicts)
keybind = ctrl+1=goto_tab:1
keybind = ctrl+2=goto_tab:2
keybind = ctrl+3=goto_tab:3
keybind = ctrl+4=goto_tab:4
keybind = ctrl+5=goto_tab:5
keybind = ctrl+6=goto_tab:6
keybind = ctrl+7=goto_tab:7
keybind = ctrl+8=goto_tab:8
keybind = ctrl+9=goto_tab:9

# === SPLIT MANAGEMENT ===
# Using Ctrl+Shift to avoid conflicts with window managers
keybind = ctrl+shift+backslash=new_split:right
keybind = ctrl+shift+minus=new_split:down
keybind = ctrl+shift+enter=new_split:auto

# Navigate splits (vim-style with Ctrl+Shift)
keybind = ctrl+shift+h=goto_split:left
keybind = ctrl+shift+j=goto_split:down
keybind = ctrl+shift+k=goto_split:up
# Note: ctrl+shift+l conflicts with last_tab, choose one:
# keybind = ctrl+shift+l=goto_split:right
keybind = ctrl+shift+bracketleft=goto_split:previous
keybind = ctrl+shift+bracketright=goto_split:next

# Split controls
keybind = ctrl+shift+z=toggle_split_zoom
keybind = ctrl+shift+equal=equalize_splits

# Resize splits (using all three modifiers to be unique)
keybind = ctrl+shift+alt+h=resize_split:left,10
keybind = ctrl+shift+alt+j=resize_split:down,10
keybind = ctrl+shift+alt+k=resize_split:up,10
keybind = ctrl+shift+alt+l=resize_split:right,10

# === TEXT SELECTION & CLIPBOARD ===
keybind = ctrl+shift+c=copy_to_clipboard
keybind = ctrl+shift+v=paste_from_clipboard
keybind = ctrl+shift+a=select_all
keybind = shift+escape=clear_selection

# === SCROLLING & NAVIGATION ===
keybind = shift+page_up=scroll_page_up
keybind = shift+page_down=scroll_page_down
keybind = shift+home=scroll_to_top
keybind = shift+end=scroll_to_bottom
keybind = ctrl+shift+up=scroll_line_up
keybind = ctrl+shift+down=scroll_line_down

# === FONT SIZE CONTROL ===
keybind = ctrl+plus=increase_font_size:1
keybind = ctrl+minus=decrease_font_size:1
keybind = ctrl+0=reset_font_size

# === SEARCH ===
keybind = ctrl+shift+f=search_forward
keybind = ctrl+shift+g=search_backward

# === WINDOW CONTROLS ===
keybind = f11=toggle_fullscreen
keybind = ctrl+shift+m=toggle_maximize

# === CONFIGURATION & TOOLS ===
keybind = ctrl+comma=open_config
keybind = ctrl+shift+r=reload_config
keybind = ctrl+shift+i=inspector:toggle
keybind = ctrl+q=quit
```

## Quick Reference Summary

### Conflict-Free Navigation
- **Tabs**: `Ctrl+Tab` / `Ctrl+Shift+Tab` (next/previous)
- **Splits**: `Ctrl+Shift+H/J/K/L` (vim-style navigation)
- **No Alt+Tab conflicts**: We avoid Alt modifier for main navigation
- **No Ctrl+Alt+Arrow conflicts**: We use Ctrl+Shift instead

### Most Used Shortcuts
- `Ctrl+Shift+T` - New tab
- `Ctrl+Shift+\` - Split right
- `Ctrl+Shift+-` - Split down
- `Ctrl+Shift+C/V` - Copy/Paste
- `Ctrl+Shift+Z` - Zoom split
- `F11` - Fullscreen

## Tips for Linux Users

1. **Avoid System Conflicts**: Our config uses Ctrl+Shift as primary modifier to avoid workspace switching (Ctrl+Alt) and window management (Alt) shortcuts
2. **Vim-style Navigation**: H/J/K/L keys with Ctrl+Shift for split navigation matches vim muscle memory
3. **Tab vs Split**: Use tabs for different projects, splits for same project (e.g., editor + logs)
4. **Font Size**: Ctrl+Plus/Minus/0 works everywhere (browser-like)
5. **Reload After Config Changes**: Use `Ctrl+Shift+R` to apply config changes without restart