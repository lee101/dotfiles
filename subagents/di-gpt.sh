#!/usr/bin/env bash
# di subagent pinned to gpt-5.6 via OpenPaths.
set -euo pipefail
DI=${DI:-/vfast/data/code/fx/zig-out/bin/di}
FX_MODEL='gpt-5.6' exec "$DI" "$@"
