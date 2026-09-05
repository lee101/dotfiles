#!/usr/bin/env bash
# di subagent pinned to Meta Muse Spark 1.3 (contributor alias) via OpenPaths.
# Falls back to muse-spark-1.3 while the contributor alias is not yet deployed.
set -euo pipefail
DI=${DI:-/vfast/data/code/fx/zig-out/bin/di}
model=${DI_MUSE_MODEL:-muse-spark-1.3-contributor}
if [ -n "${OPENPATHS_API_KEY:-}" ]; then
  ids=$(curl -sf -m 10 "${OPENPATHS_BASE_URL:-https://openpaths.io}/v1/models" \
    -H "Authorization: Bearer $OPENPATHS_API_KEY" 2>/dev/null | tr ',' '\n' | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' || true)
  if [ -n "$ids" ] && ! grep -qx -- "$model" <<<"$ids" && grep -qx -- "${model%-contributor}" <<<"$ids"; then
    model=${model%-contributor}
  fi
fi
FX_MODEL="$model" exec "$DI" "$@"
