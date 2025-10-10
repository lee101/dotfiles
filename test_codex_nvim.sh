#!/bin/bash

# Test script for codex multi-prompt workflow for nvim config analysis

echo "Testing codex with nvim config analysis..."

# Option 1: Using cdxm function for sequential prompts
echo -e "\n=== Option 1: Sequential execution with cdxm ===\n"
echo 'cdxm -d "look over the nvim config files in lua/user/" "identify areas where we can add intellij/vscode-like shortcuts" "suggest specific keybindings for format document, multi-selection, delete line (ctrl+d), duplicate line (shift+ctrl+d)"'

# Option 2: Single combined prompt
echo -e "\n=== Option 2: Single combined prompt ===\n"
echo 'cdxed "look over the nvim config in lua/user/ and figure out some ways we can get even nicer config and intellij idea or vscode like shortcuts utils like format document (auto finds formatter like prettier/ruff), or other keyboard tricks like multi selection, ctrl d for delete line or shift ctrl d for duplicate line etc"'

# Option 3: Interactive mode with initial prompt
echo -e "\n=== Option 3: Interactive mode (allows follow-up questions) ===\n"
echo 'cdxi -d "look over the nvim config and analyze it"'
echo '# Then you can type follow-up prompts like:'
echo '# "add vscode-like keybindings for formatting"'
echo '# "implement multi-cursor support"'
echo '# etc.'

# Option 4: Using heredoc for complex multi-line prompt
echo -e "\n=== Option 4: Heredoc for detailed instructions ===\n"
cat << 'EOF'
cdxed << 'PROMPT'
Please analyze the nvim configuration in lua/user/ and:
1. Review the current keymaps and identify missing IDE-like features
2. Suggest implementations for:
   - Format document (auto-detect formatter like prettier/ruff)
   - Multi-selection/multi-cursor
   - Ctrl+D for delete line
   - Shift+Ctrl+D for duplicate line
   - Other useful IDE shortcuts
3. Check if any existing plugins can be better configured
4. Provide the actual code changes needed
PROMPT
EOF