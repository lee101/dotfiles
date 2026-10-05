#!/usr/bin/env bash
# di subagent pinned to deepseek/deepseek-v4-flash-vision-exp via OpenPaths.
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
FX_MODEL='deepseek/deepseek-v4-flash-vision-exp' exec "$DI" "$@"
