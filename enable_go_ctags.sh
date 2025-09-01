#!/bin/bash

# Script to enable and test ctags for Go projects (using centralized cache)

echo "🏷️  Go Ctags Setup Helper (Centralized Cache)"
echo "============================================"
echo ""

# Cache directory for tags
CACHE_DIR="$HOME/.cache/nvim/ctags"
mkdir -p "$CACHE_DIR"

# Find current Go project root
if [ -f "go.mod" ]; then
    PROJECT_ROOT="$(pwd)"
elif GO_MOD=$(find . -name "go.mod" -maxdepth 3 2>/dev/null | head -1); then
    PROJECT_ROOT="$(cd $(dirname "$GO_MOD") && pwd)"
else
    echo "❌ No Go project found (no go.mod file)"
    echo "   Please run this from a Go project directory"
    exit 1
fi

PROJECT_NAME=$(basename "$PROJECT_ROOT")
PROJECT_HASH=$(echo -n "$PROJECT_ROOT" | sha256sum | cut -d' ' -f1)
TAG_FILE="$CACHE_DIR/${PROJECT_NAME}-${PROJECT_HASH:0:8}.tags"

echo "📁 Found Go project: $PROJECT_ROOT"
echo "🏷️  Tags will be stored in cache: $TAG_FILE"
echo ""

# Generate tags
echo "🔨 Generating tags..."
cd "$PROJECT_ROOT"
ctags -R --languages=go --Go-kinds=+p+f+v+t+c --extras=+q -f "$TAG_FILE" . 2>/dev/null

if [ -f "$TAG_FILE" ]; then
    TAG_COUNT=$(wc -l "$TAG_FILE" | awk '{print $1}')
    echo "✅ Tags generated successfully!"
    echo "   Total tags: $TAG_COUNT"
    echo ""
    echo "📝 How to use in Neovim:"
    echo "   1. Open a Go file: nvim *.go"
    echo "   2. Jump to definition: Ctrl+] or gd"
    echo "   3. Go back: Ctrl+t"
    echo "   4. Search tags: <leader>ft (current buffer) or <leader>fT (all)"
    echo ""
    echo "🔄 To enable automatic tag updates in Neovim:"
    echo "   :GutentagsToggleEnabled"
    echo ""
    echo "💡 Benefits of centralized cache:"
    echo "   • No 'tags' files cluttering your projects"
    echo "   • Tags persist across git operations"
    echo "   • Shared cache for all projects"
    echo ""
    echo "🗑️  To clean tags cache: rm -rf $CACHE_DIR"
else
    echo "❌ Failed to generate tags"
    echo "   Make sure ctags is installed: sudo apt-get install universal-ctags"
fi