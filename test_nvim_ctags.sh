#!/bin/bash

# Test script for Neovim ctags setup

GO_PROJECT="/home/lee/code/gobed"

echo "Testing ctags setup for Go project..."
cd "$GO_PROJECT"

# Generate tags manually first
echo "Generating tags for $GO_PROJECT..."
ctags -R --languages=go --kinds-go=+p+f+v+t+c --fields=+ailmnS --extras=+q -f tags .

if [ -f "tags" ]; then
    echo "✓ Tags file generated successfully"
    echo "  Tags file size: $(wc -l tags | awk '{print $1}') lines"
    echo ""
    echo "Sample tags (first 10 non-comment lines):"
    grep -v "^!" tags | head -10
else
    echo "✗ Failed to generate tags file"
    exit 1
fi

echo ""
echo "Now you can:"
echo "1. Open Neovim: nvim $GO_PROJECT/*.go"
echo "2. Place cursor on a function/type name"
echo "3. Press Ctrl+] or gd to jump to definition"
echo "4. Press Ctrl+t to go back"
echo "5. Use <leader>ft to search tags in current buffer"
echo "6. Use <leader>fT to search all tags"
echo ""
echo "To enable automatic tag generation:"
echo "  Run :GutentagsToggleEnabled in Neovim"
echo "  Or :let g:gutentags_enabled = 1"