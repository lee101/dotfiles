#!/bin/bash
# Common functions for Claude tools

# Find Claude CLI command
find_claude_cmd() {
    # Check common command names (claude is the newer name)
    for cmd in claude cld; do
        if command -v "$cmd" &> /dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    
    # Check common installation paths
    for path in "$HOME/.local/bin/cld" "$HOME/.local/bin/claude" "/usr/local/bin/cld" "/usr/local/bin/claude"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Check if running in Claude Code environment
    if [[ -n "$CLAUDE_CODE" ]] && command -v claude &> /dev/null; then
        echo "claude"
        return 0
    fi
    
    return 1
}

# Get Claude command or exit with error
get_claude_cmd() {
    local cmd=$(find_claude_cmd)
    if [[ -z "$cmd" ]]; then
        echo "Error: Claude CLI not found." >&2
        echo "Please ensure 'cld' or 'claude' is installed and in your PATH." >&2
        echo "Install from: https://claude.ai/cli" >&2
        exit 1
    fi
    echo "$cmd"
}

# Export for use in scripts
export CLAUDE_CMD=$(find_claude_cmd || echo "")