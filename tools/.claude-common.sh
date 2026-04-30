#!/bin/bash
# Common functions for Claude tools

# Find Claude CLI command
claude_cmd_works() {
    local cmd="$1"
    local rc

    [[ -n "$cmd" && -x "$cmd" ]] || return 1

    if command -v timeout >/dev/null 2>&1; then
        timeout 5 "$cmd" --version >/dev/null 2>&1
        rc=$?
        [[ "$rc" -eq 0 || "$rc" -eq 124 ]]
        return
    fi

    "$cmd" --version >/dev/null 2>&1
}

find_claude_cmd() {
    local resolved=""

    if resolved=$(type -P claude 2>/dev/null); then
        if claude_cmd_works "$resolved"; then
            echo "$resolved"
            return 0
        fi
    fi

    # Check common installation paths
    for path in "$HOME/.local/bin/claude" "/usr/local/bin/claude" "/usr/bin/claude" "/bin/claude"; do
        if claude_cmd_works "$path"; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Get Claude command or exit with error
get_claude_cmd() {
    local cmd=$(find_claude_cmd)
    if [[ -z "$cmd" ]]; then
        echo "Error: Claude CLI not found." >&2
        echo "Please install or repair Claude Code:" >&2
        echo "  curl -fsSL https://claude.ai/install.sh | bash" >&2
        exit 1
    fi
    echo "$cmd"
}

# Export for use in scripts
export CLAUDE_CMD=$(find_claude_cmd || echo "")
