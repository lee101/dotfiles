#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
FX_PROVIDER=openpaths FX_MODEL="${DI_EMBER_MODEL:-ember-1}" exec "$DI" "$@"
