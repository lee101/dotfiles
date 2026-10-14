#!/usr/bin/env bash
set -euo pipefail
model=${OP_OPENPATHSFREE_MODEL:-openpaths/free}
exec op --model "$model" "$@"
