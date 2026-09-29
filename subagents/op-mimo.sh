#!/usr/bin/env bash
# op (oh-my-pi) pinned to Xiaomi MiMo-V2.6-Pro via OpenPaths (1M context, agentic).
# Usage: op-mimo.sh "prompt"  (add -p for print mode, --auto-approve to skip prompts)
set -euo pipefail
model=${OP_MIMO_MODEL:-xiaomi/mimo-v2.6-pro}
exec op --model "$model" "$@"
