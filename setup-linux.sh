#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_ai_cli_notes() {
  cat <<'EOF'
AI CLI install notes:
  Claude Code (npm-only in this repo):
    npm install -g @anthropic-ai/claude-code

  OpenCode:
    curl -fsSL https://opencode.ai/install | bash

  OpenClaw:
    curl -fsSL https://openclaw.ai/install.sh | bash
EOF
}

if [[ "${1:-}" == "--ai-notes" ]]; then
  print_ai_cli_notes
  exit 0
fi

if [[ ! -x "${SCRIPT_DIR}/setup-developer.sh" ]]; then
  echo "Missing executable setup-developer.sh at ${SCRIPT_DIR}/setup-developer.sh" >&2
  exit 1
fi

"${SCRIPT_DIR}/setup-developer.sh" "$@"

echo
print_ai_cli_notes
