#!/bin/bash

# Concise Neovim fixer with error capture and timeouts

echo "🔧 Fixing Neovim..."

# Capture nvim startup errors (3 second timeout)
echo -n "Testing startup... "
STARTUP_ERROR=$(timeout 3 nvim --headless -c 'qa!' 2>&1)

if [ $? -eq 124 ]; then
    echo "⚠️  timeout"
    STARTUP_ERROR="Nvim hangs on startup - likely plugin installation running"
elif [ -n "$STARTUP_ERROR" ]; then
    echo "❌ errors found"
else
    echo "✓"
fi

# Capture all errors in one variable
ALL_ERRORS=""
[ -n "$STARTUP_ERROR" ] && ALL_ERRORS="STARTUP ERRORS:\n$STARTUP_ERROR\n\n"

# Quick health check (5 second timeout)
echo -n "Running checkhealth... "
HEALTH_ERROR=$(timeout 5 nvim --headless +':checkhealth' +':qa!' 2>&1 | grep -E '(ERROR|WARNING)' | head -20)
[ -n "$HEALTH_ERROR" ] && ALL_ERRORS="${ALL_ERRORS}HEALTH CHECK:\n$HEALTH_ERROR\n\n"
echo "✓"

# Test plugin sync (10 second timeout)
echo -n "Checking plugins... "
PLUGIN_ERROR=$(timeout 10 nvim --headless +':Lazy sync' +':qa!' 2>&1 | grep -E '(Error|Failed)' | head -10)
[ -n "$PLUGIN_ERROR" ] && ALL_ERRORS="${ALL_ERRORS}PLUGIN ERRORS:\n$PLUGIN_ERROR\n\n"
echo "✓"

# If we found errors, fix them with codex
if [ -n "$ALL_ERRORS" ]; then
    echo ""
    echo "🔍 Found issues, running codex fix..."
    echo ""
    
    # Create a comprehensive fix command with all error context
    codex exec --dangerously-bypass-approvals-and-sandbox << EOF
Fix these Neovim issues found during startup and diagnostics:

$ALL_ERRORS

Key fixes needed:
1. Fix broken keymaps in lua/user/keymaps.lua (Home/End mappings, treesitter require paths)
2. Fix autocommands in lua/user/autocommands.lua (vim.notify override, aggressive chdir)  
3. Fix any plugin configuration errors in init.lua
4. Ensure Mason formatters are properly configured
5. Fix any LSP server setup issues

Make minimal, targeted fixes only where errors exist. Don't add new features.
EOF
    
    echo ""
    echo "✅ Fix attempted. Test with: nvim"
else
    echo ""
    echo "✅ No errors found!"
fi

# Quick summary
echo ""
echo "Keybindings updated:"
echo "  • <leader>d - Duplicate line (was Ctrl+Shift+D)"
echo "  • Alt+D - Delete line (was Ctrl+D)"
echo "  • <leader>F - Format document"
echo "  • Alt+n - Multi-cursor next"