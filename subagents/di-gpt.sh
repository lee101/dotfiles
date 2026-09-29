#!/usr/bin/env bash
# di subagent pinned to gpt-6-astra via OpenPaths.
set -euo pipefail
DI=${DI:-/nvme0n1-disk/code/di/zig-out/bin/di}
FX_MODEL='gpt-6-astra' exec "$DI" "$@"
