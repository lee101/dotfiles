#!/usr/bin/env bash
# op (oh-my-pi) pinned to Meta Muse Spark 1.3 via OpenPaths. Cheap fixer for tests/small edits.
# Usage: op-muse.sh "prompt"  (add -p for print mode, --auto-approve to skip prompts)
set -euo pipefail
model=${OP_MUSE_MODEL:-muse-spark-1.3}
exec op --model "$model" "$@"
