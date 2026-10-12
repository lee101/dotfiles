#!/usr/bin/env bash
# di subagent pinned to a free OpenPaths model (default poolside laguna-s-2.1:free).
set -euo pipefail
DI=${DI:-/nvme0n1-disk/code/di/zig-out/bin/di}
FX_MODEL="${DI_FREE_MODEL:-nous/poolside/laguna-s-2.1:free}" exec "$DI" "$@"
