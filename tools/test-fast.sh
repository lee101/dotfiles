#!/usr/bin/env bash
# Fast checks (a few seconds, run in parallel): used by the pre-push hook.
set -uo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$repo_dir/tools/test-lib.sh"

run_par shell-config "$repo_dir/tools/test-shell-config.sh"
run_par syntax bash -c 'for f in "$0"/lib/common_shell "$0"/bashrc "$0"/bash_profile "$0"/lib/ssh-unlock.sh; do bash -n "$f" || exit 1; done' "$repo_dir"
if command -v shellcheck >/dev/null 2>&1; then
    run_par shellcheck shellcheck --shell=bash --severity=error \
        "$repo_dir/lib/common_shell" "$repo_dir/bashrc" "$repo_dir/bash_profile" \
        "$repo_dir"/tools/test-*.sh "$repo_dir"/tools/githooks/*
fi
wait_par
