#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cache/dotfiles-tools"
"$root/profiling/mojo/build.sh" "$tmp/cache/dotfiles-tools/profile-md-mojo"
XDG_CACHE_HOME="$tmp/cache" "$root/tools/profile-md" \
  "$root/profiling/tests/fixtures/trtexec.log" \
  --out "$tmp/report.md" --top 1 --max-chars 2000
grep -q 'TensorRT trtexec Report' "$tmp/report.md"
grep -q 'attention_block' "$tmp/report.md"
if grep -q 'conv1' "$tmp/report.md"; then
  echo "native --top 1 retained more than one layer" >&2
  exit 1
fi
test "$(grep -c '^| `' "$tmp/report.md")" -eq 1

# The same bounded CLI must work where Mojo is unavailable (including Windows).
PATH="/usr/bin:/bin" XDG_CACHE_HOME="$tmp/fallback" PROFILE_MD_DISABLE_NATIVE=1 \
  "$root/tools/profile-md" "$root/profiling/tests/fixtures/trtexec.log" \
  --out "$tmp/fallback.md" --top 1 --max-chars 2000
grep -q 'TensorRT trtexec Report' "$tmp/fallback.md"
grep -q 'attention_block' "$tmp/fallback.md"
if grep -q 'conv1' "$tmp/fallback.md"; then
  echo "fallback --top 1 retained more than one layer" >&2
  exit 1
fi
test "$(grep -c '^| attention_block |' "$tmp/fallback.md")" -eq 1
