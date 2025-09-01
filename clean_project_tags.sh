#!/bin/bash

# Script to remove tags files from project directories
# (since we now use centralized cache)

echo "🧹 Cleaning up project tags files"
echo "================================="
echo ""

# Find all tags files in code directories
echo "Looking for tags files in ~/code..."
TAGS_FILES=$(find ~/code -name "tags" -type f 2>/dev/null | grep -v node_modules | grep -v .git)

if [ -z "$TAGS_FILES" ]; then
    echo "✅ No tags files found in project directories"
else
    echo "Found tags files:"
    echo "$TAGS_FILES" | while read -r file; do
        echo "  📄 $file"
    done
    
    echo ""
    read -p "Remove these tags files? (y/N) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$TAGS_FILES" | while read -r file; do
            rm -f "$file"
            echo "  ✓ Removed: $file"
        done
        echo ""
        echo "✅ Cleanup complete!"
    else
        echo "❌ Cleanup cancelled"
    fi
fi

echo ""
echo "💡 Tags are now stored in: ~/.cache/nvim/ctags/"
echo "   Run 'ls -la ~/.cache/nvim/ctags/' to see cached tags"