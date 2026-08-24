#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for config in \
    "$repo_dir/lib/common_shell" \
    "$repo_dir/lib/winbashrc" \
    "$repo_dir/bashrc" \
    "$repo_dir/bash_profile"; do
    bash -n "$config"
    printf 'OK %s\n' "${config#"$repo_dir"/}"
done

# Catch reload-only failures caused by aliases expanding function declarations.
bash --noprofile --norc -i -c '
  alias clinst="broken-alias"
  source "$1"
  declare -F clinst >/dev/null
' bash "$repo_dir/lib/common_shell"
printf 'OK reload-safe function declarations\n'
