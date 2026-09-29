#!/usr/bin/env bash
# di subagent pinned to deepseek/deepseek-v4-flash-vision-exp via OpenPaths.
set -euo pipefail
DI=${DI:-/nvme0n1-disk/code/di/zig-out/bin/di}
FX_MODEL='deepseek/deepseek-v4-flash-vision-exp' exec "$DI" "$@"
