#!/usr/bin/env bash
# di subagent pinned to deepseek/deepseek-v4-flash-vision-exp via OpenPaths.
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
FX_PROVIDER=openpaths FX_MODEL="${DI_DEEP_MODEL:-deepseek-v4-flash}" exec "$DI" "$@"
