# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
[[ -e ~/.bashrc ]] && emulate sh -c 'source ~/.bashrc'
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="dallas"
# ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_THEME="robbyrussell"  # Use default theme until powerlevel10k is installed
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  #bundler
  #dotenv
 # osx
 # rake
  #rbenv
 # ruby
#  grunt
#  gulp
#  golang
  python
  node
  pyenv
  redis-cli
#  rustup
  terraform
  yarn
  aws
#  brew
  cp
  # direnv  # commented out - not installed
  docker
  # fd  # commented out - plugin doesn't exist
  gcloud
  nmap
 # heroku
)

[[ -f $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# if [ -e /Users/leepenkman/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/leepenkman/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
# . /Users/leepenkman/.nix-profile/etc/profile.d/nix.sh

 # ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Eternal bash history.
# ---------------------
# Undocumented feature which sets the size to "unlimited".
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
export HISTFILESIZE=9999999
export HISTSIZE=9999999
export SAVEHIST=9999999
export HISTTIMEFORMAT="[%F %T] "
# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.zsh_eternal_history

# Better history sharing: local priority with global sharing
# INC_APPEND_HISTORY appends commands as they are entered
# EXTENDED_HISTORY saves timestamp information
# HIST_IGNORE_DUPS ignores duplicate commands in succession
# HIST_FIND_NO_DUPS doesn't show duplicates when searching
# HIST_REDUCE_BLANKS removes extra whitespace from commands
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Don't use SHARE_HISTORY - this causes immediate sharing which overrides local history
# unsetopt SHARE_HISTORY

# Function to merge history from other sessions when desired
merge_history() {
    fc -R
}

# Alias for easy history merging
alias mh='merge_history'

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias lt='ls -lttra'
alias la='ls -A'
alias l='ls -CF'

alias d='cd'
alias c='cd ~/code'

alias tli='terraform console'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.

# Load kubectl completion only if kubectl is available
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion zsh 2>/dev/null) || true
fi
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias gpr='hub pull-request' #'gh pr create'
alias gcm='git commit -m'
alias gcmtm='git commit --no-edit'
alias gcmtmp='git commit --no-edit && git push'
alias gsw='git show'
alias gpl='git pull'
alias gd='git diff'

# Modern Git tools
alias lg='lazygit'
alias gti='tig status'
alias tgi='tig status'  # Alternative alias for tig
alias tg='tig'          # Short tig alias
alias gdiff='git difftool --no-symlinks --dir-diff'
alias gmerge='git mergetool'
# aliases again
alias k=kubectl
alias refresh='source ~/.zshrc'
alias reload='source ~/.zshrc'
source ~/.secretbashrc
alias klg='k logs -n'
alias kdlp='k delete pod -n'
alias kdsp='k describe pod -n'
alias kdsn='k describe node '

alias kdlpn='k delete pod --all -n'
alias kdlap='kdlpn'


alias gss='git stash'
alias reswap='sudo swapoff -a && sudo swapon -a'
export NODE_OPTIONS="--experimental-repl-await"


export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1  # This loads nvm silently
# Skip bash_completion in zsh - it's not compatible
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" >/dev/null 2>&1


alias usag='du -sh * * | sort -h'




alias o='xdg-open'



if [[ ! $(uname -s) = "Darwin" ]]; then
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
  alias open='xdg-open'
  alias say='echo "$1" | espeak -s 120'

  extract () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1    ;;
            *.tar.gz)    tar xvzf $1    ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       rar x $1       ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xvf $1     ;;
            *.tbz2)      tar xvjf $1    ;;
            *.tgz)       tar xvzf $1    ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "don't know how to extract '$1'..." ;;
        esac
    else
        echo "'$1' is not a valid file!"
    fi
  }
else
  # Easy extract mac
  extract () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1    ;;
            *.tar.gz)    tar xvzf $1    ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       rar x $1       ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xvf $1     ;;
            *.tbz2)      tar xvjf $1    ;;
            *.tgz)       tar xvzf $1    ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7za x $1        ;;
            *)           echo "don't know how to extract '$1'..." ;;
        esac
    else
        echo "'$1' is not a valid file!"
    fi
  }
fi

aa () {
	local alias_name
	local alias_command
	local new_alias
	[[ $1 == "alias" ]] && shift
	if (($# == 1))
	then
		IFS='=' read -r alias_name alias_command <<< $1
	else
		alias_name=$1
		alias_command="$@[2, -1]"
	fi
	local cmd=alias
	eval "$cmd $alias_name='$alias_command'"
	local alias_line="$cmd $alias_name='$alias_command'"
	echo $alias_line >> ~/.dotfiles/zsh/aliases.zsh
	echo "Added $alias_line to ~/.dotfiles/zsh/aliases.zsh"
}
alias charm='/home/lee/programs/pycharm-2023.1.3/bin/pycharm.sh'

alias k='kubectl'

export PATH="/usr/local/cuda-12.0/bin:$PATH"
#export LD_LIBRARY_PATH="/usr/local/cuda-12.0/lib64:$LD_LIBRARY_PATH"
export CUDA_HOME='/usr/local/cuda-12.0'


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/lee/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/lee/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/lee/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/lee/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/lee/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
unsetopt correct_all
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/lee/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/lee/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/lee/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/lee/programs/google-cloud-sdk/path.zsh.inc' ]; then . '/home/lee/programs/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/lee/programs/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/lee/programs/google-cloud-sdk/completion.zsh.inc'; fi

alias monoff='sleep 1; xset dpms force off'

# source ~/powerlevel10k/powerlevel10k.zsh-theme

[[ -s "/home/lee/.gvm/scripts/gvm" ]] && source "/home/lee/.gvm/scripts/gvm"

# bun completions
[ -s "/home/lee/.bun/_bun" ] && source "/home/lee/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# Chrome profile environment variable
export CHROME_PROFILE_PATH="/home/lee/code/dotfiles/tools/chrome_profiles_export"

# Source local environment if it exists
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# Custom aliases (placed at end to avoid overrides)
alias reload='source ~/.zshrc'
alias refresh='source ~/.zshrc'
# Remove any existing aliases/functions before redefining
unalias cld 2>/dev/null || true
unset -f cld 2>/dev/null || true
unalias codex 2>/dev/null || true
unset -f codex 2>/dev/null || true

# Ensure CHOKIDAR polling for Claude CLI
cld() {
  #CHOKIDAR_USEPOLLING=1 CHOKIDAR_INTERVAL=3000 \
  bun run "$(which claude)" --dangerously-skip-permissions "$@"
}

# Ensure CHOKIDAR polling for Codex CLI commands too
codex() {
  #CHOKIDAR_USEPOLLING=1 CHOKIDAR_INTERVAL=3000 \
  command codex "$@"
}
alias gd='git diff'
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Lynx browser with auto-accept cookies
alias lynx='lynx -accept_all_cookies -cookie_file=~/.lynx/cookies -cookie_save_file=~/.lynx/cookies'

# Go configuration for macOS
export GOROOT=/usr/local/Cellar/go/1.25.0/libexec
alias go="GOROOT=/usr/local/Cellar/go/1.25.0/libexec /usr/local/bin/go"
export PATH=$GOROOT/bin:$PATH

# Git diffs including untracked
# gdfa: show diff of all changes (tracked vs HEAD + untracked files)
# gdfu: show diff of untracked files only
gdfa() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a git repository" >&2
    return 1
  fi

  # Tracked changes (staged + unstaged) vs HEAD
  git --no-pager diff --color=always -p HEAD --

  # Untracked files as diffs from /dev/null
  local cnt=0
  while IFS= read -r -d '' f; do
    if (( cnt == 0 )); then
      printf "\n# Untracked files\n"
    fi
    ((cnt++))
    git --no-pager diff --color=always --no-index -- /dev/null "$f"
  done < <(git ls-files --others --exclude-standard -z)

  # If nothing printed at all, hint no changes
  if [[ $(git status --porcelain) == "" ]]; then
    echo "(no changes)"
  fi
}

gdfu() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a git repository" >&2
    return 1
  fi

  local cnt=0
  while IFS= read -r -d '' f; do
    ((cnt++))
    git --no-pager diff --color=always --no-index -- /dev/null "$f"
  done < <(git ls-files --others --exclude-standard -z)

  if (( cnt == 0 )); then
    echo "(no untracked files)"
  fi
}
