#!/usr/bin/env bash
# di subagent pinned to glm-5.3 via OpenPaths.
set -euo pipefail
DI=${DI:-/vfast/data/code/fx/zig-out/bin/di}
FX_MODEL='glm-5.3' exec "$DI" "$@"
