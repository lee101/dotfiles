#!/usr/bin/env bash
# di subagent pinned to Kimi K3.1 Pro via OpenPaths (OPENPATHS_API_KEY).
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
: "${OPENPATHS_API_KEY:?OPENPATHS_API_KEY not set}"
unset OPENROUTER_API_KEY
FX_PROVIDER=openpaths FX_MODEL=${DI_KIMI_MODEL:-kimi-k3.1-pro} exec "$DI" "$@"
