#!/usr/bin/env bash
# pi-infinity (pinf) pinned to deepseek/deepseek-v4-flash via OpenRouter.
set -euo pipefail
[[ -n ${OPENROUTER_API_KEY:-} ]] || { printf '%s\n' 'OPENROUTER_API_KEY is required for pi-crouton.' >&2; exit 2; }
PINF=${PINF:-/nvme0n1-disk/code/pi-infinity/packages/coding-agent/dist/cli.js}
exec node "$PINF" --provider openrouter --model deepseek/deepseek-v4-flash "$@"
