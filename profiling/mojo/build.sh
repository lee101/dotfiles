#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
destination="${1:-$root/tools/.bin/profile-md-mojo}"
mkdir -p "$(dirname "$destination")"
temporary="${destination}.tmp.$$"
trap 'rm -f "$temporary"' EXIT
mojo build "$root/profiling/mojo/profile_md.mojo" -o "$temporary"
chmod +x "$temporary"
mv -f "$temporary" "$destination"
echo "built $destination"
