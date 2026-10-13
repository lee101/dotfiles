#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v tmux >/dev/null 2>&1; then
    echo 'WARN: tmux is not installed; skipping pane startup tests' >&2
    exit 0
fi
work_dir="$(mktemp -d)"
socket="$work_dir/socket"
cleanup() {
    tmux -S "$socket" kill-server 2>/dev/null || true
    rm -rf "$work_dir"
}
trap cleanup EXIT
mkdir "$work_dir/home"
ln -s "$repo_dir" "$work_dir/home/code-dotfiles"
printf 'source "%s/bashrc"\n' "$repo_dir" > "$work_dir/home/.bashrc"
printf 'source "$HOME/.bashrc"\n' > "$work_dir/home/.bash_profile"
printf 'source "%s/lib/common_shell"\n' "$repo_dir" > "$work_dir/home/.zshrc"
# The Bash wrapper also supports a copied rc through this fallback location.
ln -s "$repo_dir/lib" "$work_dir/home/lib"

for shell in "$(command -v bash)" /bin/sh "$(command -v zsh || true)"; do
    [ -n "$shell" ] || continue
    socket="$work_dir/socket-$(basename "$shell")"
    expected="$shell"
    [ "$shell" != /bin/sh ] || expected=/bin/bash
    HOME="$work_dir/home" SHELL="$shell" tmux -S "$socket" -f "$repo_dir/tmux.conf" new-session -d -s probe
    # Wait for if-shell configuration commands before creating more panes.
    for ((i=0; i<100; i++)); do
        [ "$(tmux -S "$socket" show-options -gv default-shell)" = "$expected" ] && break
        sleep 0.1
    done
    test "$(tmux -S "$socket" show-options -gv default-shell)" = "$expected"
    test -z "$(tmux -S "$socket" show-options -gv default-command)"
    for action in initial-pane new-window split-window; do
        if [ "$action" = initial-pane ]; then
            pane="$(tmux -S "$socket" list-panes -F '#{pane_id}')"
        else
            pane="$(tmux -S "$socket" "$action" -d -P -F '#{pane_id}')"
        fi
        result="$work_dir/result"
        rm -f "$result"
        tmux -S "$socket" send-keys -t "$pane" "alias v >/dev/null && alias tx >/dev/null && alias ll >/dev/null && printf 'OK' > '$result'" Enter
        for ((i=0; i<100; i++)); do
            [ -f "$result" ] && break
            sleep 0.1
        done
        test "$(cat "$result" 2>/dev/null)" = OK
        printf 'OK tmux %s aliases (%s)\n' "$action" "$shell"
    done
    tmux -S "$socket" kill-server
done
