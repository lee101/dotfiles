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

# ============================================================
# Interactive bash options (distro defaults are gone once we own ~/.bashrc)
# ============================================================
shopt -s histappend checkwinsize 2>/dev/null
shopt -s cmdhist 2>/dev/null
shopt -s globstar 2>/dev/null   # bash 4+ only
shopt -s autocd 2>/dev/null     # bash 4+ only
HISTCONTROL=ignoreboth

# ============================================================
# Bash completion (Linux, macOS/Homebrew; Git Bash ships its own)
# ============================================================
if ! shopt -oq posix; then
    for _bc in \
        /usr/share/bash-completion/bash_completion \
        /etc/bash_completion \
        /usr/local/etc/profile.d/bash_completion.sh \
        /opt/homebrew/etc/profile.d/bash_completion.sh ; do
        if [ -r "$_bc" ]; then
            # shellcheck disable=SC1090
            . "$_bc"
            break
        fi
    done
    unset _bc
fi

## =============    AI Coding Agents    =================
# Pi Infinity (our fork of pi-mono with --auto-next-steps/--auto-next-idea)
# pinf runs from /vfast/data/code/pi/pi-mono/packages/coding-agent/dist/cli.js
# Original pi (upstream @mariozechner/pi-coding-agent) installed via bun
# Run alongside each other: pinf uses .pinf/ config, pi uses .pi/ config

# Export Claude Code OAuth token as ANTHROPIC_API_KEY (for tools that support it)
export_claude_auth() {
    local creds="${CLAUDE_HOME:-$HOME/.claude}/.credentials.json"
    if [ -f "$creds" ]; then
        local token
        token=$(python3 -c "
import json, sys
try:
    d = json.load(open('$creds'))
    print(d.get('claudeAiOauth', {}).get('accessToken', ''))
except Exception as e:
    sys.exit(0)
" 2>/dev/null)
        if [ -n "$token" ]; then
            export ANTHROPIC_API_KEY="$token"
            echo "Claude auth loaded (${token:0:15}...)"
        else
            echo "No Claude OAuth token found at $creds"
        fi
    else
        echo "No Claude credentials found at $creds"
    fi
}

# Quick aliases for the two coding agents
alias pinf-update='cd /vfast/data/code/pi/pi-mono && git pull origin main && git fetch upstream && git merge upstream/main && NODE_OPTIONS=--experimental-strip-types npm run build:offline'
alias pi-update='bun add -g @mariozechner/pi-coding-agent'
alias pinf='/vfast/data/code/pi/pi-mono/packages/coding-agent/dist/cli.js'
alias pinfn='/vfast/data/code/pi/pi-mono/packages/coding-agent/dist/cli.js --auto-next-steps'
alias pinfni='/vfast/data/code/pi/pi-mono/packages/coding-agent/dist/cli.js --auto-next-idea'
# di (lee101/di, fork of vercel-labs/fx). Model-pinned subagents live in
# ~/code/dotfiles/subagents/di-*.sh; FX_MODEL selects the OpenPaths model.
alias di='/vfast/data/code/fx/zig-out/bin/di'
alias din='di --auto-next-steps'
alias dini='di --auto-next-steps --auto-next-idea'
alias dimuse="$HOME/code/dotfiles/subagents/di-muse.sh"
alias digpt="$HOME/code/dotfiles/subagents/di-gpt.sh"
alias diglm="$HOME/code/dotfiles/subagents/di-glm.sh"
alias dideep="$HOME/code/dotfiles/subagents/di-deep.sh"
alias diself='/vfast/data/code/fx/scripts/self-improve.sh'
alias diup='/vfast/data/code/fx/scripts/self-improve.sh --merge-upstream'
alias fx='di'
## =====================================================

# ============================================================
# Prompt - mirrors the zsh PROMPT in zshrc: cyan cwd, magenta git branch
# ============================================================
_df_git_branch() {
    command -v git >/dev/null 2>&1 || return 0
    local _b
    _b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
    [ -n "$_b" ] && printf ' %s' "$_b"
    return 0
}

# Modern terminals, including Kitty, Ghostty, Terminal.app, and Git Bash,
# understand ANSI colour even when their terminfo entry is missing locally.
# Only disable colour when the terminal explicitly identifies as dumb.
_df_colors=1
case "${TERM:-dumb}" in
    dumb|'') _df_colors=0 ;;
esac

# Show user@host over SSH so remote sessions are obvious.
_df_host_prefix=''
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
    _df_host_prefix='\u@\h '
fi

if [ "$_df_colors" -eq 1 ]; then
    PS1="\[\e[32m\]${_df_host_prefix}\[\e[36m\]\w\[\e[35m\]\$(_df_git_branch)\[\e[0m\] \$ "
else
    PS1="${_df_host_prefix}\w\$(_df_git_branch) \$ "
fi
unset _df_colors _df_host_prefix

# Terminal title (skipped on dumb terminals)
case "$TERM" in
    xterm*|rxvt*|screen*|tmux*|alacritty|foot|*kitty*)
        PS1="\[\e]0;\w\a\]$PS1"
        ;;
esac

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

# user-local builds (ffmpeg n9 + NVENC)
export PATH="$HOME/.local/bin:$PATH"
