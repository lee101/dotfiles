#!/bin/bash
# ~/.bashrc - Dotfiles entrypoint (thin wrapper)
# This file lives in the dotfiles repo and is symlinked/copied to ~/.bashrc
# It safely locates and sources the main shared config: lib/common_shell
#
# Works for: Linux, macOS, Git Bash (MINGW/MSYS), WSL, Cygwin
# The real configuration (aliases, functions, PATH, cross-platform utils) lives in:
#   lib/common_shell  (sourced by both bash and zsh)

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Resolve the directory containing this bashrc (works when symlinked)
if [ -n "${BASH_SOURCE[0]}" ]; then
    _df_bashrc_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
else
    _df_bashrc_dir="$HOME/code/dotfiles"
fi

# Try to source the main common_shell from several likely locations
_sourced_common=0

_candidates=(
    "$_df_bashrc_dir/lib/common_shell"
    "$HOME/code/dotfiles/lib/common_shell"
    "$HOME/.dotfiles/lib/common_shell"
    "$HOME/dotfiles/lib/common_shell"
    "$HOME/.config/dotfiles/lib/common_shell"
    "$HOME/lib/common_shell"
)

for _cand in "${_candidates[@]}"; do
    if [ -f "$_cand" ]; then
        # shellcheck disable=SC1090
        if . "$_cand"; then
            _sourced_common=1
            export DOTFILES_DIR="$(dirname "$(dirname "$_cand")")"
            break
        fi
    fi
done

unset _cand _candidates

if [ "$_sourced_common" -eq 0 ]; then
    # Fallback: minimal useful aliases if common_shell missing
    export EDITOR="${EDITOR:-nvim}"
    export VISUAL="${VISUAL:-nvim}"
    alias v='nvim'
    alias vi='nvim'
    alias vim='nvim'
    alias c='cd ~/code'
    alias u='cd ..'
    alias o='explorer.exe . 2>/dev/null || open . 2>/dev/null || xdg-open . 2>/dev/null || echo "o: no file manager found"'
    echo "WARNING: dotfiles lib/common_shell not found. Using minimal fallback." >&2
fi

unset _sourced_common

# WSL-specific extras (in addition to what common_shell + cross_platform provide)
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    # Prefer repo wslbashrc if present (adds explorer aliases + X11 + completions)
    for _wsl in \
        "$HOME/code/dotfiles/wslbashrc" \
        "$HOME/.dotfiles/wslbashrc" \
        "$HOME/wslbashrc" \
        "$_df_bashrc_dir/wslbashrc" ; do
        if [ -f "$_wsl" ]; then
            # shellcheck disable=SC1090
            . "$_wsl" 2>/dev/null || true
            break
        fi
    done
    unset _wsl
fi

# Local user overrides (not tracked in dotfiles)
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local" 2>/dev/null || true

# Git Bash / MSYS specific tweaks (non-interactive safe)
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -o 2>/dev/null)" == Msys ]]; then
    # Ensure explorer is callable for 'o'
    if ! command -v explorer.exe >/dev/null 2>&1; then
        if [ -x "/c/Windows/explorer.exe" ]; then
            alias explorer.exe='/c/Windows/explorer.exe'
        fi
    fi

    # Make vi/vim/nvim reliably use the full Windows Neovim (with our linked config)
    # even if some other vim sneaks into PATH.
    if [ -x "/c/Program Files/Neovim/bin/nvim.exe" ]; then
        alias nvim='/c/Program\ Files/Neovim/bin/nvim.exe'
        alias vim='/c/Program\ Files/Neovim/bin/nvim.exe'
        alias vi='/c/Program\ Files/Neovim/bin/nvim.exe'
        export EDITOR="/c/Program Files/Neovim/bin/nvim.exe"
        export VISUAL="$EDITOR"
    fi
fi

unset _df_bashrc_dir

# Handy one-liner reload for interactive use
# Usage: reload
if ! command -v reload >/dev/null 2>&1; then
    # `function name` is immune to a stale same-named alias during parsing.
    function reload {
        echo "Reloading ~/.bashrc ..."
        # shellcheck disable=SC1090
        . "$HOME/.bashrc"
        echo "Done."
    }
fi
