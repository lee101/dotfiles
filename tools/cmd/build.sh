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

# Mojo tools are optional on unsupported hosts. The wrapper keeps a Python
# fallback, while Linux builders use the pinned Pixi environment.
mojo_root="$(cd ../.. && pwd)/profiling/mojo"
if command -v mojo >/dev/null 2>&1; then
  "$mojo_root/build.sh"
elif command -v pixi >/dev/null 2>&1 && [[ "$(uname -s)" == Linux* ]]; then
  pixi run --manifest-path "$mojo_root/pixi.toml" build
else
  echo "skipped Mojo tools (compiler unavailable; profile-md uses Python fallback)"
fi
