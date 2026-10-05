#!/usr/bin/env bash
# di subagent pinned to gpt-6-astra via OpenPaths.
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
FX_MODEL='gpt-6-astra' exec "$DI" "$@"
