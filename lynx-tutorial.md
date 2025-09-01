# Lynx Browser Tutorial - Terminal Web Browsing Like a Pro

## Overview
Lynx is a powerful text-based web browser that runs entirely in your terminal. With our custom configuration, you get vi-like keybindings, mouse support, and a smooth browsing experience without ever leaving the command line.

## Quick Start

### Basic Usage
```bash
# Open a website
lynx https://google.com

# Open a local HTML file
lynx file:///path/to/file.html

# Start at the bookmarks page
lynx -book
```

## Essential Navigation Keys

### Vi-Mode Navigation (Enabled in our config)
- `j` / `↓` - Move down one line
- `k` / `↑` - Move up one line
- `h` / `←` - Move left / Go back in history
- `l` / `→` - Move right / Follow selected link
- `Space` / `Page Down` - Next page
- `b` / `Page Up` - Previous page
- `g` - Go to first page (top)
- `G` - Go to last page (bottom)
- `Ctrl+A` - Jump to beginning of line
- `Ctrl+E` - Jump to end of line

### Link Navigation
- `Tab` - Jump to next link
- `Shift+Tab` - Jump to previous link
- `Enter` - Follow the selected link
- Numbers (1-9) - Jump directly to numbered link (we enabled NUMBER_LINKS)
- `L` - List all links on current page

### Page Actions
- `g` then type URL - Go to a specific URL
- `Backspace` - Go back to previous page (history back)
- `\` - View HTML source of current page
- `=` - Show info about current page and link
- `Ctrl+R` - Reload current page
- `/` - Search forward in page
- `?` - Search backward in page
- `n` - Find next search match
- `N` - Find previous search match

## Advanced Features

### Bookmarks
- `a` - Add current page to bookmarks
- `v` - View bookmarks
- `r` - Remove a bookmark (when viewing bookmarks)

### Downloads & Files
- `d` - Download the current link
- `p` - Print page to a file
- `Ctrl+G` - Cancel current download/transfer

### Forms & Text Input
- In text fields: Type normally
- `Tab` - Move to next form field
- `Enter` - Submit form (when in submit button)
- `Ctrl+V` - Insert text from clipboard (if supported)
- `Ctrl+U` - Clear current line in text field
- `Ctrl+K` - Delete from cursor to end of line

### Cookie Management
Our config enables cookies with:
- Persistent cookies saved to `~/.lynx/cookies`
- Auto-accept cookies (can be changed with `o` options)

### Display Options
- `o` - Open options menu to customize settings
- `@` - Toggle raw/rendered HTML mode
- `*` - Toggle image links (show/hide)
- `[` - Toggle pseudo-inline images
- `]` - Send a HEAD request for current document

## Useful Commands

### Quick Commands
- `?` or `h` - Show help screen
- `q` - Quit lynx
- `Q` - Quit without confirmation
- `!` - Spawn a shell
- `Ctrl+T` - Toggle trace log
- `Ctrl+V` - Switch to literal next keystroke

### History & Session
- `Backspace` or `Delete` - History back
- `Ctrl+H` - Show history list
- `x` - Force no-cache reload

## Pro Tips

### 1. Quick Search with DuckDuckGo
```bash
# Create an alias in your .bashrc or .zshrc
alias ddg='lynx https://duckduckgo.com/lite'
```

### 2. Reading Documentation
```bash
# Perfect for reading man pages in HTML format
man -H lynx
```

### 3. Quick File Downloads
```bash
# Download file directly without browsing
lynx -dump https://example.com/file.txt > file.txt
```

### 4. Text-Only Output
```bash
# Get text-only version of a webpage
lynx -dump https://example.com

# With links listed at the bottom
lynx -dump -listonly https://example.com
```

### 5. Using with Pipes
```bash
# Browse HTML from command output
echo "<h1>Test</h1>" | lynx -stdin

# Read markdown as HTML
pandoc README.md -t html | lynx -stdin
```

### 6. Custom User Agent
Our config sets a standard user agent, but you can override:
```bash
lynx -useragent="Mozilla/5.0" https://example.com
```

### 7. Batch Mode Operations
```bash
# Download all links from a page
lynx -dump -listonly https://example.com | grep -E '^[ ]*[0-9]+\.' | awk '{print $2}' | wget -i -
```

## Configuration Highlights

Our `.lynxrc` configuration provides:
- **Vi keybindings** - Navigate like in vim
- **Mouse support** - Click on links (if terminal supports it)
- **Numbered links** - Jump to links by number
- **UTF-8 support** - Proper character encoding
- **Cookie persistence** - Maintains sessions
- **Color display** - Easier to read
- **Image link display** - Shows ALT text for images
- **SSL/TLS support** - Secure browsing

## Troubleshooting

### SSL Certificate Issues
If you get SSL errors:
```bash
# Update certificates
sudo update-ca-certificates
```

### Slow Loading
- Press `z` to interrupt slow loading
- Use `Ctrl+G` to cancel current operation

### Cookie Problems
- Check cookie file: `~/.lynx/cookies`
- Clear cookies: `rm ~/.lynx/cookies`
- Toggle cookie acceptance: Press `o` then navigate to cookie options

### Display Issues
- Try different terminal emulator
- Adjust terminal size for better rendering
- Toggle color with `o` options if colors look wrong

## Common Use Cases

### 1. Reading News/Blogs
```bash
lynx https://news.ycombinator.com
lynx https://reddit.com/.mobile  # Mobile sites often work better
```

### 2. Checking Weather
```bash
lynx https://wttr.in/your_city
```

### 3. API Testing
```bash
# View JSON responses
lynx -dump https://api.github.com/users/username
```

### 4. Downloading Files from CLI
```bash
# When wget/curl aren't available
lynx -dump https://example.com/file.zip > file.zip
```

### 5. Reading Documentation
```bash
# Many projects have text-friendly docs
lynx https://docs.python.org/3/
```

## Keyboard Reference Card

```
NAVIGATION          LINKS              ACTIONS
----------          -----              -------
j/k     up/down     Tab    next link   g    goto URL
h/l     left/right  Enter  follow      /    search
Space   page down   L      list all    a    add bookmark
b       page up     [0-9]  numbered    d    download
g/G     top/bottom                     p    print
                                       q    quit

HISTORY            DISPLAY            ADVANCED
-------            -------            --------
Backspace  back    *    toggle imgs   o    options
Ctrl+H     list    @    raw HTML      !    shell
                   =    page info     v    bookmarks
```

## Conclusion

Lynx is incredibly powerful for:
- Quick web browsing without leaving terminal
- Accessing sites on slow connections
- Web scraping and automation
- Privacy-focused browsing (no JavaScript tracking)
- Reading documentation and text-heavy sites

With our vi-enabled configuration, you can browse the web as efficiently as you edit code!

## Additional Resources
- Official Lynx Documentation: `man lynx`
- Lynx Users Guide: Press `h` or `?` while in lynx
- Configuration Options: Press `o` in lynx to see all options