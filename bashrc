#!/bin/bash
# ============================================================
# Bash Configuration - Lee's dotfiles
# ============================================================
# This file contains bash-specific config. Shared aliases, functions,
# and environment variables live in lib/common_shell.

# Startup timing - set DEBUG_STARTUP=1 to enable
[ -n "$DEBUG_STARTUP" ] && echo "Bashrc start: $(date +%s.%N)"

# Ensure ~/.local/bin is in PATH (for uv, claude, etc.)
export PATH="$HOME/.local/bin:$PATH"

export DOCKER_BUILDKIT=1

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================================
# Bash-specific options
# ============================================================
# Don't put duplicate lines or lines starting with space in history
HISTCONTROL=ignoreboth

# Append to history, don't overwrite
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# History file for bash
export HISTFILE=~/.bash_eternal_history

# Force prompt to write history after every command
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================================
# Bash prompt
# ============================================================
# Set variable identifying the chroot you work in
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Set a fancy prompt
case "$TERM" in
    xterm-color|*-256color|xterm|screen|vt100) color_prompt=yes;;
esac

force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# Set terminal title
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
esac

# ============================================================
# Bash-specific aliases
# ============================================================
alias reload='source ~/.bashrc'
alias refresh='source ~/.bashrc'

# Bash-specific dir/vdir with color
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'

# ============================================================
# Bash-specific completion
# ============================================================
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    fi
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ============================================================
# Bash-specific keybindings
# ============================================================
# Ctrl+] to copy current command to clipboard
bind '"\C-]":"\C-e\C-u pbcopy <<"EOF"\n\C-y\nEOF\n"' 2>/dev/null || true

# ============================================================
# Platform-specific bash config
# ============================================================
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    MSYS_NT*)   machine=Git;;
    *)          machine="UNKNOWN:${unameOut}"
esac

# Windows Git Bash specific
if [ "$machine" = "Git" ] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [ "$machine" = "Cygwin" ] || [ "$machine" = "MinGw" ]; then
    # Source Windows-specific config
    [ -f ~/code/dotfiles/lib/winbashrc ] && . ~/code/dotfiles/lib/winbashrc

    export GOROOT="/c/Program Files/Go"
    alias pbcopy="clip"
    alias pbpaste="powershell.exe -command 'Get-Clipboard'"
    alias open="explorer.exe"
    bind '"\C-]":"\C-e\C-u pbcopy <<"EOF"\n\C-y\nEOF\n"' 2>/dev/null || true

    # Neovim paths for Windows
    for nvim_path in \
        "/c/Program Files/Neovim/bin" \
        "/c/tools/neovim/Neovim/bin" \
        "/c/Users/$USER/scoop/apps/neovim/current/bin" \
        "/c/ProgramData/chocolatey/lib/neovim/tools/Neovim/bin"; do
        [ -d "$nvim_path" ] && export PATH="$nvim_path:$PATH"
    done

    # WSL2 integration
    alias wslhome='cd "//wsl$/Ubuntu/home/lee"'
    alias wslcode='cd "//wsl$/Ubuntu/home/lee/code"'
    alias w='wsl'
    cdw() { cd "${1:+//wsl$/Ubuntu/home/lee/$1}" "${1:-//wsl$/Ubuntu/home/lee}"; }
fi

# macOS specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    export ARCHFLAGS="-arch x86_64"
    chflags nohidden ~/Library/ 2>/dev/null
fi

# ============================================================
# Bash-specific lazy loading: direnv
# ============================================================
direnv() {
    eval "$(command direnv hook bash 2>/dev/null)"
    command direnv "$@"
}

# ============================================================
# Bash-specific function aliases
# ============================================================
ali()  { echo "alias $@" >> $HOME/.bashrc; source $HOME/.bashrc; }
alis() { echo "alias $@" >> $HOME/.secretbashrc; source $HOME/.secretbashrc; }

gali() {
    [ $# -eq 0 ] && { echo "Usage: gali alias_name='command'"; return 1; }
    echo "alias $@" >> $HOME/.bashrc
    source $HOME/.bashrc
    echo "Alias added: $@"
}

eep() { "$@"; local status=$?; espeak "${1:0:10}"; return $status; }

# Enhanced Git status in prompt
parse_git_branch() {
    local branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        local upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            local ahead=$(git rev-list --count @{u}.. 2>/dev/null || echo 0)
            local behind=$(git rev-list --count ..@{u} 2>/dev/null || echo 0)
            if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
                echo " ($branch ↑$ahead↓$behind)"
            elif [ "$ahead" -gt 0 ]; then
                echo " ($branch ↑$ahead)"
            elif [ "$behind" -gt 0 ]; then
                echo " ($branch ↓$behind)"
            else
                echo " ($branch ✓)"
            fi
        else
            echo " ($branch ⚠️)"
        fi
    fi
}

# ============================================================
# Source shared shell configuration (MUST come after bash-specific setup)
# ============================================================
if [ -f ~/code/dotfiles/lib/common_shell ]; then
    . ~/code/dotfiles/lib/common_shell
elif [ -f ~/.common_shell ]; then
    . ~/.common_shell
fi

# ============================================================
# Bash-specific FZF
# ============================================================
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# ============================================================
# WSL-specific config
# ============================================================
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    [ -f ~/wslbashrc ] && . ~/wslbashrc 2>/dev/null
    alias o='explore'
    alias oo='explore'
fi

# ============================================================
# Open file/dir aliases (platform-aware, set after common_shell)
# ============================================================
if [ "$machine" = "Git" ] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    alias o='explorer.exe .'
    alias oo='explorer.exe'
fi

# virtualenv
export WORKON_HOME=$HOME/.virtualenvs
if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
    source /usr/local/bin/virtualenvwrapper.sh
elif command -v virtualenvwrapper.sh >/dev/null 2>&1; then
    source $(which virtualenvwrapper.sh)
fi

unset DOCKER_HOST

# Startup timing end
[ -n "$DEBUG_STARTUP" ] && echo "Bashrc end: $(date +%s.%N)"

# ZVM
export ZVM_INSTALL="$HOME/.zvm/self"
export PATH="$PATH:$HOME/.zvm/bin"
export PATH="$PATH:$ZVM_INSTALL/"
export PATH="/home/administrator/.pixi/bin:$PATH"

# SSH agent setup - platform-specific
if [ "$machine" = "Git" ] || [ "$machine" = "MinGw" ] || [ "$machine" = "Cygwin" ]; then
    unset SSH_AUTH_SOCK
    unset SSH_AGENT_PID
    export PATH="/c/Windows/System32/OpenSSH:$PATH"
    if ! ssh-add -l &>/dev/null; then
        ssh-add ~/.ssh/id_ed25519 2>/dev/null
    fi
else
    SSH_ENV="$HOME/.ssh/agent-environment"
    function start_ssh_agent {
        ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
        chmod 600 "${SSH_ENV}"
        . "${SSH_ENV}" > /dev/null
    }
    if [ -f "${SSH_ENV}" ]; then
        . "${SSH_ENV}" > /dev/null
        ps -p ${SSH_AGENT_PID} > /dev/null 2>&1 || start_ssh_agent
    else
        start_ssh_agent
    fi
fi

alias tx='tmux attach'
alias tls='tmux ls'
alias tn='tmux new -s'
alias cldd='claude --dangerously-skip-permissions'

# Search aliases and functions by pattern
algrp() {
    local pattern="$1"
    [ -z "$pattern" ] && { echo "Usage: algrp <pattern>"; return 1; }
    echo "=== Aliases ==="
    alias | grep -i "$pattern"
    echo -e "\n=== Functions ==="
    declare -F | awk '{print $3}' | grep -i "$pattern" | while read fn; do
        echo -n "$fn: "
        type "$fn" | head -3 | tail -2 | tr '\n' ' '
        echo
    done
}

# opencode
export PATH=/home/lee/.opencode/bin:$PATH
