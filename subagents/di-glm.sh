#!/usr/bin/env bash
# di subagent pinned to glm-5.3 via OpenPaths.
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
FX_MODEL='glm-5.3' exec "$DI" "$@"
