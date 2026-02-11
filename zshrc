# ============================================================
# ZSH Configuration - Lee's dotfiles
# ============================================================
# This file contains zsh-specific config. Shared aliases, functions,
# and environment variables live in lib/common_shell.

# Enable Powerlevel10k instant prompt (if installed)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================
# Oh-My-Zsh configuration
# ============================================================
export ZSH="$HOME/.oh-my-zsh"

# Fix insecure directory warnings (WSL/shared systems)
ZSH_DISABLE_COMPFIX="true"

# Theme
ZSH_THEME="robbyrussell"
# ZSH_THEME="powerlevel10k/powerlevel10k"  # Uncomment if p10k installed

# Disable auto-update (we manage our own updates)
DISABLE_AUTO_UPDATE="true"

# Enable autocorrection for commands (not arguments)
ENABLE_CORRECTION="true"

# Show dots while waiting for completion
COMPLETION_WAITING_DOTS="true"

# Plugins (keep minimal for speed)
plugins=(
    git
    python
    node
    pyenv
    terraform
    yarn
    aws
    cp
    docker
    gcloud
    nmap
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Load oh-my-zsh
[[ -f $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh

# ============================================================
# Zsh-specific options
# ============================================================

# History
export HISTFILE=~/.zsh_eternal_history
export SAVEHIST=9999999
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

# Autocorrect: correct commands but NOT arguments
# (prevents annoying corrections on filenames/args)
setopt CORRECT
unsetopt CORRECT_ALL

# Other useful zsh options
setopt AUTO_CD              # cd by typing directory name
setopt AUTO_PUSHD           # push directories onto stack
setopt PUSHD_IGNORE_DUPS    # no duplicate dirs in stack
setopt INTERACTIVE_COMMENTS # allow comments in interactive shell
setopt EXTENDED_GLOB        # extended globbing (#, ~, ^)
setopt NO_BEEP              # no beeping

# ============================================================
# Completion system enhancements
# ============================================================
# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# Colored completion menu
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Better grouping
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'

# Cache completions for speed
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path ~/.zsh/cache

# Kubectl completion
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion zsh 2>/dev/null) || true
fi

# ============================================================
# Key bindings
# ============================================================
# Use emacs-style keybindings (like bash defaults)
bindkey -e

# Better history search
bindkey '^[[A' history-beginning-search-backward  # Up arrow
bindkey '^[[B' history-beginning-search-forward   # Down arrow
bindkey '^R' history-incremental-search-backward   # Ctrl+R

# Word navigation (like bash)
bindkey '^[[1;5C' forward-word     # Ctrl+Right
bindkey '^[[1;5D' backward-word    # Ctrl+Left
bindkey '^[f' forward-word         # Alt+f
bindkey '^[b' backward-word        # Alt+b

# Delete word
bindkey '^[d' kill-word            # Alt+d
bindkey '^W' backward-kill-word    # Ctrl+W

# Home/End
bindkey '^[[H' beginning-of-line   # Home
bindkey '^[[F' end-of-line         # End
bindkey '^A' beginning-of-line     # Ctrl+A
bindkey '^E' end-of-line           # Ctrl+E

# ============================================================
# Zsh-specific aliases
# ============================================================
alias reload='source ~/.zshrc'
alias refresh='source ~/.zshrc'

# History merge from other sessions
merge_history() { fc -R; }
alias mh='merge_history'

# Add alias to zshrc
aa() {
    local alias_name alias_command
    [[ $1 == "alias" ]] && shift
    if (($# == 1)); then
        IFS='=' read -r alias_name alias_command <<< "$1"
    else
        alias_name=$1
        alias_command="${@[2,-1]}"
    fi
    eval "alias $alias_name='$alias_command'"
    echo "alias $alias_name='$alias_command'" >> ~/.zshrc
    echo "Added alias $alias_name"
}

ali()  { echo "alias $@" >> ~/.zshrc; source ~/.zshrc; }
alis() { echo "alias $@" >> ~/.secretbashrc; source ~/.secretbashrc; }

# ============================================================
# Zsh plugin configuration
# ============================================================

# zsh-autosuggestions config (if installed)
if [[ -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]] || [[ -d ~/.zsh/zsh-autosuggestions ]]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
    bindkey '^[[Z' autosuggest-accept  # Shift+Tab to accept suggestion
    bindkey '^ ' autosuggest-accept    # Ctrl+Space to accept suggestion
fi

# Load plugins from ~/.zsh if oh-my-zsh custom plugins aren't installed
[[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]] && \
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

[[ -f ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] && \
    [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]] && \
    source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

# ============================================================
# Source shared shell configuration
# ============================================================
if [[ -f ~/code/dotfiles/lib/common_shell ]]; then
    source ~/code/dotfiles/lib/common_shell
elif [[ -f ~/.common_shell ]]; then
    source ~/.common_shell
fi

# ============================================================
# FZF integration (zsh-specific)
# ============================================================
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ============================================================
# Powerlevel10k (if installed)
# ============================================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ============================================================
# WSL-specific overrides
# ============================================================
if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    alias o='explore'
    alias oo='explore'
    alias ox='explorer.exe .'
fi

# ============================================================
# Final PATH cleanup (remove duplicates while preserving order)
# ============================================================
typeset -U PATH
