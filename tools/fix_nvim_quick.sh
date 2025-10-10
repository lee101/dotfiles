#!/bin/bash

# fix_nvim_quick.sh - Quick Neovim fixer for common issues
# Runs the most important fixes in sequence

echo "🚀 Quick Neovim Fix"
echo "==================="
echo ""
echo "This will run a series of codex commands to fix common nvim issues."
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Run all fixes in one comprehensive command
codex exec --dangerously-bypass-approvals-and-sandbox << 'EOF'
Please fix the following Neovim configuration issues in order:

1. First, check if nvim can start by running: nvim --headless -c 'echo "test"' -c 'qa!'
   If it fails, examine the error and fix init.lua syntax issues.

2. Fix the broken keymaps in lua/user/keymaps.lua:
   - The Home/End mappings that incorrectly end with 'r' should map to 'I' and 'A'
   - The Treesitter incremental selection uses wrong require path with hyphen

3. Fix problematic autocommands in lua/user/autocommands.lua:
   - Remove or fix the global vim.notify override that suppresses errors
   - Fix the BufEnter chdir to use lcd instead of cd
   - Fix the Go tags generation guard to check vim.g.gutentags_enabled properly

4. Run plugin sync: nvim --headless +":Lazy sync" +qa
   Fix any plugin errors that appear.

5. Test checkhealth: nvim --headless +":checkhealth" +qa 2>&1 | head -100
   Address any critical errors shown.

6. Verify the new Conform and vim-visual-multi plugins work:
   - Test that require('conform') loads without error
   - Check VM_maps are set correctly

Please make all necessary fixes to get nvim working properly.
EOF

echo ""
echo "✅ Quick fix complete!"
echo ""
echo "Now test nvim by running: nvim"