#!/usr/bin/env bash
# Build all Go tools under tools/cmd/* into tools/ (which is on PATH).
set -euo pipefail
cd "$(dirname "$0")"
out="$(cd .. && pwd)"
for d in */; do
  [ -f "$d/go.mod" ] || continue
  name="${d%/}"
  (cd "$d" && go build -o "$out/$name" .)
  echo "built $out/$name"
done
