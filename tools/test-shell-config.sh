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

if command -v zsh >/dev/null 2>&1; then
	zsh -n "$repo_dir/lib/common_shell"
	printf 'OK zsh syntax lib/common_shell\n'
fi

# Catch reload-only failures caused by aliases expanding function declarations.
bash --noprofile --norc -i -c '
  alias clinst="broken-alias"
  source "$1"
  declare -F clinst >/dev/null
' bash "$repo_dir/lib/common_shell"
printf 'OK reload-safe function declarations\n'

# Verify that Muse wrappers preserve argument boundaries and inject only their
# documented defaults. MUSE_COMMAND=echo keeps this probe offline and cheap.
bash --noprofile --norc -i -c '
  source "$1"
  MUSE_COMMAND=echo
  test "$(mu "hello world")" = "--yolo hello world"
  test "$(mu-medium task)" = "--yolo --reasoning-effort medium task"
  test "$(muh task)" = "--yolo --reasoning-effort high task"
  test "$(mux task)" = "--yolo --reasoning-effort xhigh task"
  test "$(mum task)" = "--yolo --reasoning-effort ultra task"
  test "$(mue task)" = "--yolo exec task"
  test "$(mup prompt.md)" = "--yolo exec --prompt-file prompt.md"
  test "$(muw task)" = "--yolo --worktree create task"
  test "$(mu-safe task)" = "task"
' bash "$repo_dir/lib/common_shell"
printf 'OK Muse wrapper forwarding\n'
