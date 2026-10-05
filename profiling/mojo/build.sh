#!/usr/bin/env bash
# Build the native Mojo profiler core.
#
# Usage: build.sh [DESTINATION]   (default: $root/tools/.bin/profile-md-mojo)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/../.." && pwd)"
destination="${1:-$root/tools/.bin/profile-md-mojo}"
source_file="$script_dir/profile_md.mojo"

die() {
  printf 'build.sh: %s\n' "$*" >&2
  exit 1
}

# Prefer the pinned pixi environment that ships this source file, so the
# compiler always matches the version in pixi.lock. MOJO_ENV overrides it.
env_dir=""
for candidate in "${MOJO_ENV:-}" "$script_dir/.pixi/envs/default"; do
  if [ -n "$candidate" ] && [ -x "$candidate/bin/mojo" ]; then
    env_dir="$candidate"
    break
  fi
done
if [ -z "$env_dir" ] && command -v mojo >/dev/null 2>&1; then
  env_dir="$(cd "$(dirname "$(command -v mojo)")/.." && pwd)"
fi
[ -n "$env_dir" ] || die \
"no 'mojo' compiler found.
Looked for \$MOJO_ENV, $script_dir/.pixi/envs/default/bin/mojo, and 'mojo' on PATH.
Provision the pinned toolchain with:
  pixi install --manifest-path $script_dir/pixi.toml"

mojo_bin="$env_dir/bin/mojo"
[ -x "$mojo_bin" ] || die "expected an executable compiler at $mojo_bin"

# The compiler loads its precompiled stdlib through MODULAR_HOME. Without it
# every build fails with "unable to locate module 'std'" followed by a cascade
# of bogus "unknown declaration 'Int'" / "failed to resolve parent package
# body" errors that look like broken source but are not. Check the stdlib is
# really here before blaming the compiler, and report a missing toolchain as a
# missing toolchain.
[ -f "$env_dir/lib/mojo/std.mojoc" ] || die \
"found $mojo_bin but no precompiled stdlib at $env_dir/lib/mojo/std.mojoc.
Reinstall the pinned toolchain with:
  pixi install --manifest-path $script_dir/pixi.toml"

# MODULAR_HOME is $env_dir/share/max, NOT $env_dir: the compiler reads
# lib/mojo/std.mojoc from the environment root while the module path comes
# from MODULAR_HOME. Setting it to the environment root resolves to the same
# directory that has no share/max and still fails to locate the stdlib.
if [ -z "${MODULAR_HOME:-}" ]; then
  MODULAR_HOME="$env_dir/share/max"
  export MODULAR_HOME
fi
PATH="$env_dir/bin:$PATH"
export PATH

[ -f "$source_file" ] || die "source file not found: $source_file"

mkdir -p "$(dirname "$destination")"
temporary="${destination}.tmp.$$"
trap 'rm -f "$temporary"' EXIT

"$mojo_bin" build "$source_file" -o "$temporary"
chmod +x "$temporary"
mv -f "$temporary" "$destination"
trap - EXIT
echo "built $destination"