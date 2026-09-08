#!/usr/bin/env bash
# di subagent pinned to gpt-6-astra via OpenPaths.
set -euo pipefail
DI=${DI:-/vfast/data/code/fx/zig-out/bin/di}
FX_MODEL='gpt-6-astra' exec "$DI" "$@"
