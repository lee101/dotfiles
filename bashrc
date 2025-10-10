#!/bin/bash
# Startup timing - set DEBUG_STARTUP=1 to enable
[ -n "$DEBUG_STARTUP" ] && echo "Bashrc start: $(date +%s.%N)"

alias uva='source .venv/bin/activate'
alias sni='sudo snap install --classic'
alias bi='bun install'
alias ba='bun add'
alias pip='uv pip'
alias grmtr='git remote remove'
alias cru="cd /media/lee/crucial/code/"
# ~/.bashrc: executed by bash(1) for non-login shells.

export DOCKER_BUILDKIT=1
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
if [ -n "$BASH_VERSION" ]; then
  shopt -s histappend
fi

# Eternal bash history.
# Undocumented feature which sets the size to "unlimited".
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
export HISTFILESIZE=99999999
export HISTSIZE=9999999
export HISTTIMEFORMAT="[%F %T] "
# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_eternal_history
# Force prompt to write history after every command.
# http://superuser.com/questions/20900/bash-history-loss
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# Chrome profile path for js-error-checker
export CHROME_PROFILE_PATH="$HOME/.config/google-chrome/Default"

# SSH Agent auto-start
# SSH agent setup moved to end of file to avoid duplicates

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
if [ -n "$BASH_VERSION" ]; then

  shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
  [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

  # set variable identifying the chroot you work in (used in the prompt below)
  if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
      debian_chroot=$(cat /etc/debian_chroot)
  fi

  # Bash-specific prompt configuration
  if [ -n "$BASH_VERSION" ]; then
    # set a fancy prompt (non-color, unless we know we "want" color)
    case "$TERM" in
        xterm-color|*-256color|xterm|screen|vt100) color_prompt=yes;;
    esac

    # uncomment for a colored prompt, if the terminal has the capability; turned
    # off by default to not distract the user: the focus in a terminal window
    # should be on the output of commands, not on the prompt
    # Enable colored prompt
    force_color_prompt=yes

    if [ -n "$force_color_prompt" ]; then
        if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
      # We have color support; assume it's compliant with Ecma-48
      # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
      # a case would tend to support setf rather than setaf.)
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
  fi
fi
# If this is an xterm set the title to user@host:dir (bash only)
if [ -n "$BASH_VERSION" ]; then
    case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *)
        ;;
    esac
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# Always use colors for common commands
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias sve='source .venv/bin/activate'
# Easy extract
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
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    MSYS_NT*)   machine=Git;;
    *)          machine="UNKNOWN:${unameOut}"
esac

# Creates an archive from given directory
mktar() { tar cvf  "${1%%/}.tar"     "${1%%/}/"; }
mktgz() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }
mktbz() { tar cvjf "${1%%/}.tar.bz2" "${1%%/}/"; }

# Color prompt
force_color_prompt=yes

alias refresh='source ~/.bashrc'
alias reload='source ~/.bashrc'
alias r='rm -rf'

# Safe trash alias - moves files to trash instead of permanent deletion
alias rr='trash-put'

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
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Source git aliases from dotfiles
if [ -f ~/code/dotfiles/lib/git_aliases ]; then
    . ~/code/dotfiles/lib/git_aliases
elif [ -f ~/.git_aliases ]; then
    . ~/.git_aliases
fi

# Source cross-platform utilities
if [ -f ~/code/dotfiles/lib/cross_platform_utils ]; then
    . ~/code/dotfiles/lib/cross_platform_utils
fi


if [ -n "$BASH_VERSION" ]; then

  # enable programmable completion features (you don't need to enable
  # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
  # sources /etc/bash.bashrc).
  if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
      . /usr/share/bash-completion/bash_completion
    fi
  fi

  # You may want to put all your additions into a separate file like
  # ~/.bash_aliases, instead of adding them here directly.
  # See /usr/share/doc/bash-doc/examples in the bash-doc package.

  if [ -f ~/.bash_aliases ]; then
      . ~/.bash_aliases
  fi
fi

alias u='cd ..'

alias hcl='hg clone'
alias hout='hg out'
alias hin='hg in'
alias hst='hg summary;hg st'
alias hdf='hg diff'
alias hrv='hg revert -r'
alias hrvd='hg revert -r default'
alias hco=hrvd
alias hrva='hg revert --all'
alias hup='hg update'
alias hbr='hg branch'
alias hbrs='hg branches'
alias hpsh='hg push'
alias hpl='hg pull'
alias hlg='hg log'
alias hlgg='hg log --graph'
alias hcp='hg graft -r '
alias hds='hg heads'
alias hcmamd='hg commit --amend'
alias hcm='hg commit -m'
alias hcmt='hg commit -m'
alias hds='hg log -r . --template "{latesttag}-{latesttagdistance}-{node|short}\n"'
alias hrmt='hg paths'
alias had='hg add'

function hcmep { hg commit -m "$@" ; hg push; }
function findn { find . -name "$@"; }

# Append arguments to .gitignore
function gi {
    for arg in "$@"; do
        echo "$arg" >> .gitignore
    done
}

alias gpr='hub pull-request'
alias hpr='gpr'
alias hprs='hub pr show'
alias gprs='hub pr show'

alias brb='bun run build'
alias brl='bun run lint'
alias brf='bun run format'
alias brt='bun run typecheck'
alias brt='bun run test'

alias gst='git status' 
alias gstt='git status -uno'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcom='git checkout master'
alias gcl='git clone --recurse-submodules'
alias gclo='git clone'
alias gcm='git commit -m'
alias gcmn='git commit --no-verify -m'
alias gcmt='git commit'
alias gcmtn='git commit --no-verify'
alias gcmts='git commit --no-edit'
alias gcma='git commit -a -m'
alias gcman='git commit -a --no-verify -m'
alias gcms='git commit -n -m'
alias gcmamd='git commit --amend -C HEAD'
alias gbr='git branch'
alias gdf='git diff'
alias gdfc='git diff --cached'
alias gdfx='git diff --cached'
alias gdfm='git diff --diff-filter=M --ignore-space-change'
alias gdfa='git --no-pager diff -p'
alias gdfac='git --no-pager diff -p --cached'
# Git untracked/new files - show content of new files
function gun {
    local path="${1:-.}"
    git ls-files --others --exclude-standard "$path" 2>/dev/null | while IFS= read -r file; do
        if [ -f "$file" ]; then
            echo -e "\033[1;32m+++ $file\033[0m"
            cat "$file" | command head -100
            echo
        fi
    done
}

# Git untracked files list only
function gunl {
    local path="${1:-.}"
    git ls-files --others --exclude-standard "$path" 2>/dev/null
}

# Git diff all (modified + untracked)
function guna {
    local path="${1:-.}"

    # Show modified files diff
    local has_modified=$(git diff HEAD --name-only "$path" 2>/dev/null)
    if [ -n "$has_modified" ]; then
        echo -e "\033[1;33m=== MODIFIED FILES ===\033[0m"
        git diff HEAD --color "$path" 2>/dev/null
    fi

    # Show new/untracked files
    local has_untracked=$(git ls-files --others --exclude-standard "$path" 2>/dev/null | command head -1)
    if [ -n "$has_untracked" ]; then
        echo -e "\n\033[1;32m=== NEW/UNTRACKED FILES ===\033[0m"
        git ls-files --others --exclude-standard "$path" 2>/dev/null | while IFS= read -r file; do
            if [ -f "$file" ]; then
                echo -e "\033[1;32m+++ $file\033[0m"
                cat "$file" | command head -50
                echo
            fi
        done
    fi
}

alias gdfaa='gunaa'
alias glg='git log'
alias glglee='git log --author=lee'
alias glgme='git log --author=lee'
alias gmg='git merge'
alias gmga='git merge --abort'
alias gmgm='git merge master'
alias gmm='git merge master'
alias gmgmn='git merge main'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbim='git rebase -i master'
alias grbm='git rebase master'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grl='git reflog'
alias gad='git add'
alias gadu='git add -u'
alias gadi='git add -i'
alias gada='git add -A'
alias gaa='git add -A'
alias gph='git push; git push --tags'
#alias gpsh='git push; git push --tags'
alias gphf='git push -f; git push -f --tags'
alias gpshf='git push -f; git push -f --tags'
alias gpl='git pull'
alias gplrb='git pull --rebase'
alias gpm='git checkout master;git pull;git checkout -;'
alias gplm='git checkout master;git pull;git checkout -;'
alias gpgr='git checkout green;git pull;git checkout -;'

alias gplh='git pull origin $(git rev-parse --abbrev-ref HEAD);'
alias gpshh='git push origin $(git rev-parse --abbrev-ref HEAD);'
alias gct='git checkout --track'
alias gexport='git archive --format zip --output'
alias gdel='git branch -D'
alias gmu='git fetch origin -v; git fetch upstream -v; git merge upstream/master'
alias gll='git log --graph --pretty=oneline --abbrev-commit'
alias gg="git log --graph --pretty=format:'%C(bold)%h%Creset%C(yellow)%d%Creset %s %C(yellow)%an %C(cyan)%cr%Creset' --abbrev-commit --date=relative"
alias ggs="gg --stat"

alias gpf='git push -f'
alias gsw='git show'
alias grs='git reset'
alias grsm='git reset master'
alias grsh='git reset --hard'
alias grshh='git reset --hard HEAD'
alias grshm='git reset --hard master'
alias grss='git reset --soft'
alias grssm='git reset --soft master'
alias gcp='git cherry-pick'
alias gcpc='git cherry-pick --continue'
alias gcpa='git cherry-pick --abort'
alias gus='git reset HEAD' # git unstage
alias gsm='git submodule'
alias gsmu='git submodule update --init'
alias grpo='git remote prune origin'
alias grmt='git remote -v'
alias grmte='git remote -v'
alias grmta='git remote add'
alias grmtau='git remote add upstream'
alias grmtao='git remote add origin'
alias grmts='git remote set-url'
alias grmtsu='git remote set-url upstream'
alias grmtes='git remote set-url'
alias grmtesu='git remote set-url upstream'
alias grmtso='git remote set-url origin'
alias grmtsuo='git remote set-url origin'
alias grmteso='git remote set-url origin'
alias grmtesuo='git remote set-url origin'
alias gdel='git clean -f'
alias gclf='git clean -f'
alias grv='git revert'
alias gds='git describe'
alias gw='git whatchanged'

# Modern Git tools
alias lg='lazygit'
alias gti='tig status'
alias tgi='tig status'  # Alternative alias for tig
alias tg='tig'          # Short tig alias
alias gdiff='git difftool --no-symlinks --dir-diff'
alias gmerge='git mergetool'

# Difftastic aliases
alias gdft='difft'
alias gdfts='difft --display side-by-side'

# Debug function for Git tools
git-tools-debug() {
    echo "=== Git Tools Debug ==="
    echo "Environment: $(uname -s) $(uname -r)"
    echo "Shell: $SHELL"
    echo "Bashrc loaded: $(test -f ~/.bashrc && echo 'Yes' || echo 'No')"
    echo ""
    echo "Tool availability:"
    for tool in git lazygit tig delta difft gh; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✓ $tool: $(command -v "$tool")"
        else
            echo "✗ $tool: not found"
        fi
    done
    echo ""
    echo "Git tool aliases:"
    alias | grep -E "(lg|tgi|gti|tg|gdiff|gmerge)=" || echo "No git tool aliases found"
    echo ""
    echo "Delta pager check:"
    git config --get core.pager || echo "No pager configured"
}
alias gdfb='git diff master...'
alias gdfbm='git diff main...'
alias gdfbd='git diff develop...'

# Quick git status variations
alias gsu='git status -uno'  # Hide untracked files
alias gss='git status -s'    # Short format
alias gsl='git status --long' # Long format (default)

# Git diff shortcuts for specific file states
alias gdfn='gun'  # Show new/untracked files content (alias to gun function)
alias gdfu='git ls-files --others --exclude-standard'  # List untracked files only

# Function to show all changes (tracked + untracked) in git diff format for LLMs
function gunaa() {
    echo "=== TRACKED FILE CHANGES ==="
    git --no-pager diff -p
    echo
    echo "=== STAGED FILE CHANGES ==="
    git --no-pager diff -p --cached
    echo
    echo "=== UNTRACKED FILES ==="
    git ls-files --others --exclude-standard | while IFS= read -r file; do
        echo "=== New file: $file ==="
        git diff --no-index /dev/null "$file" || true
        echo
    done
}
function gbsu {
    current_branch=`git rev-parse --abbrev-ref HEAD`
    git branch --set-upstream-to=origin/$current_branch $current_branch
}

function gpsh {
    current_branch=`git rev-parse --abbrev-ref HEAD`
    git push --set-upstream origin $current_branch
}

function gcof {
   branch_name=`gbr | fzf`
   git checkout $branch_name
}

function gusco { git reset HEAD "$@" ; git checkout -- "$@" ; }

function gss { git stash save "$@" ; }
function gssw { git stash show "$@" ; }
function gssw1 { git stash show -p stash@{0}; }
function gssw2 { git stash show -p stash@{1}; }
function gssw3 { git stash show -p stash@{2}; }
function gsp { git stash pop "$@" ; }
function gsp1 { git stash pop -p stash@{0}; }
function gsp2 { git stash pop -p stash@{1}; }
function gsp3 { git stash pop -p stash@{2}; }

function gcmp { git commit -m "$@" ; gpsh; }
function gcmpn { git commit --no-verify -m "$@" ; gpsh; }
function gcmps { git commit -n -m "$@" ; gpsh; }
function gcmpf { git commit -m "$@" ; git push -f; }
function gcmpfn { git commit --no-verify -m "$@" ; git push -f; }
function gcmap { git commit -a -m "$@" ; git push; }
function gcmapn { git commit -a --no-verify -m "$@" ; git push; }
function gcmapf { git commit -a -m "$@" ; git push -f; }
function gcmapfn { git commit -a --no-verify -m "$@" ; git push -f; }
function gcme { git add -A; git commit -a -m "$@" ; }
function gcmen { git add -A; git commit -a --no-verify -m "$@" ; }
function gcmep { git add -A; git commit -a -m "$@" ; gpsh; }
function gcmepn { git add -A; git commit -a --no-verify -m "$@" ; gpsh; }
function gcmeps { git add -A; git commit -a -n -m "$@" ; gpsh; }
function gcmepf { git add -A; git commit -a -m "$@" ; git push -f; }
function gcmepfn { git add -A; git commit -a --no-verify -m "$@" ; git push -f; }


function gswf {
  gsw "$@" | grep '\-\-\- a/' | cut -b 6-;
}

# Source Windows-specific configurations for Git Bash and similar environments
if [ "$machine" = "Git" ] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [ "$machine" = "Cygwin" ] || [ "$machine" = "MinGw" ]; then
  # Get the directory where this bashrc is located
  BASHRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Source the Windows-specific bashrc if it exists
  if [ -f "$BASHRC_DIR/lib/winbashrc" ]; then
    . "$BASHRC_DIR/lib/winbashrc"
  elif [ -f ~/code/dotfiles/lib/winbashrc ]; then
    . ~/code/dotfiles/lib/winbashrc
  fi

  export GOROOT="/c/Program Files/Go"
else
   export DOCKER_HOST=tcp://127.0.0.1:2376
   alias docker='sudo docker'

   # Set GOROOT from Homebrew Cellar only if present (macOS/Linux)
   # - Prefer `brew --prefix go` when available
   # - Fallback to common Cellar paths on macOS and Linuxbrew
   if [ -z "$GOROOT" ]; then
     if command -v brew >/dev/null 2>&1; then
       __brew_go_prefix="$(brew --prefix go 2>/dev/null || true)"
       if [ -n "$__brew_go_prefix" ] && [ -d "$__brew_go_prefix/libexec" ]; then
         export GOROOT="$__brew_go_prefix/libexec"
       fi
     fi
     if [ -z "$GOROOT" ]; then
       for __p in /opt/homebrew/Cellar/go/*/libexec \
                  /usr/local/Cellar/go/*/libexec \
                  /home/linuxbrew/.linuxbrew/Cellar/go/*/libexec; do
         if [ -d "$__p" ]; then
           export GOROOT="$__p"
           break
         fi
       done
     fi
     unset __brew_go_prefix __p
   fi

   # Add GOROOT/bin to PATH if it exists and isn't already included
   if [ -n "$GOROOT" ] && [ -d "$GOROOT/bin" ] && [[ ":$PATH:" != *":$GOROOT/bin:"* ]]; then
     export PATH="$GOROOT/bin:$PATH"
   fi
fi

# Clipboard setup with Git Bash detection
if [ "$machine" = "Git" ] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  # Windows Git Bash clipboard setup
  alias pbcopy="clip"
  alias pbpaste="powershell.exe -command 'Get-Clipboard'"
  # Cntrl+] to copy current command to clipboard for Git Bash
  # Only use bind in bash (not zsh)
  if [ -n "$BASH_VERSION" ]; then
    bind '"\C-]":"\C-e\C-u pbcopy <<"EOF"\n\C-y\nEOF\n"'
  fi

  # Windows Git Bash open setup
  alias open="explorer.exe"

  # Windows Git Bash nvim setup
  export EDITOR="nvim"
  export VISUAL="nvim"
  alias vi="nvim"
  alias vim="nvim"
  alias n="nvim"
  alias ni="nvim"

  # Add common Windows nvim paths to PATH
  if [ -d "/c/Program Files/Neovim/bin" ]; then
    export PATH="/c/Program Files/Neovim/bin:$PATH"
  fi
  if [ -d "/c/tools/neovim/Neovim/bin" ]; then
    export PATH="/c/tools/neovim/Neovim/bin:$PATH"
  fi
  if [ -d "/c/Users/$USER/AppData/Local/nvim-data" ]; then
    export NVIM_APPNAME="nvim"
  fi
  if [ -d "/c/Users/$USER/scoop/apps/neovim/current/bin" ]; then
    export PATH="/c/Users/$USER/scoop/apps/neovim/current/bin:$PATH"
  fi
  # Chocolatey installation path
  if [ -d "/c/ProgramData/chocolatey/lib/neovim/tools/Neovim/bin" ]; then
    export PATH="/c/ProgramData/chocolatey/lib/neovim/tools/Neovim/bin:$PATH"
  fi
  # Winget installation path
  if [ -d "/c/Users/$USER/AppData/Local/Microsoft/WinGet/Packages/Neovim.Neovim_Microsoft.Winget.Source_8wekyb3d8bbwe/bin" ]; then
    export PATH="/c/Users/$USER/AppData/Local/Microsoft/WinGet/Packages/Neovim.Neovim_Microsoft.Winget.Source_8wekyb3d8bbwe/bin:$PATH"
  fi

  # Debug function for nvim on Windows
  nvim-debug() {
    echo "Current environment: $machine / $OSTYPE"
    echo "EDITOR: $EDITOR"
    echo "VISUAL: $VISUAL"
    echo "nvim location: $(which nvim 2>/dev/null || echo 'nvim not found in PATH')"
    echo "PATH contains:"
    echo "$PATH" | tr ':' '\n' | grep -i nvim || echo "No nvim paths found in PATH"
  }
  # WSL2 integration for Git Bash
  alias wslhome='cd "//wsl$/Ubuntu/home/lee"'
  alias wslcode='cd "//wsl$/Ubuntu/home/lee/code"'
  alias w='wsl'
  alias wsl2='wsl'
  # Function to cd into WSL2 directory from Git Bash
  cdw() {
    if [ -z "$1" ]; then
      cd "//wsl$/Ubuntu/home/lee"
    else
      cd "//wsl$/Ubuntu/home/lee/$1"
    fi
  }

elif [[ ! $(uname -s) = "Darwin" ]]; then
  # Linux clipboard setup
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
  alias open='xdg-open'
  alias say='echo "$1" | espeak -s 120'

  # Cntrl+] to copy current command to clipboard for Linux
  # Only use bind in bash (not zsh)
  if [ -n "$BASH_VERSION" ]; then
    bind '"\C-]":"\C-e\C-u pbcopy <<"EOF"\n\C-y\nEOF\n"'
  fi

  # Linux nvim setup
  export EDITOR="nvim"
  export VISUAL="nvim"
  alias vi="nvim"
  alias vim="nvim"
  alias n="nvim"
  alias ni="nvim"
fi

# NVIDIA SMI aliases
alias smi='nvidia-smi'
alias wsmi='watch -n 1 nvidia-smi'

# GPU monitoring with detailed metrics
# sm: streaming multiprocessor utilization, mem: memory controller utilization
# enc: encoder utilization, dec: decoder utilization, jpg: JPEG engine utilization
# ofa: optical flow accelerator utilization, fb: framebuffer memory usage
# bar1: BAR1 memory usage, ccpm: compute capability memory usage
alias smidmon='nvidia-smi dmon -s um -d 1'

# Additional useful nvidia-smi aliases
alias smiq='nvidia-smi -q'                    # Query detailed GPU information
alias smil='nvidia-smi -L'                    # List all GPUs
alias smip='nvidia-smi pmon -i 0'             # Process monitoring for GPU 0
alias smipm='nvidia-smi pmon'                 # Process monitoring for all GPUs
alias smit='nvidia-smi -q -d TEMPERATURE'     # Temperature monitoring
alias smic='nvidia-smi -q -d CLOCK'           # Clock speeds
alias smim='nvidia-smi -q -d MEMORY'          # Memory details
alias smip='nvidia-smi -q -d POWER'           # Power consumption details

# nvtop aliases (if nvtop is installed)
alias nt='nvtop'
alias ntop='nvtop'


alias dps='docker ps'
alias dim='docker images'
alias dlg='docker logs'
alias drm='docker rm'
alias drmi='docker rmi'
alias dkl='docker kill'
alias dstt='docker start'
alias dstp='docker stop'
alias sdtpa='docker stop $(docker ps -q)'
alias dklall='docker stop $(docker ps -a -q); docker rm `docker ps --no-trunc -a -q`'
alias dkillall='docker stop $(docker ps -a -q);docker rm `docker ps --no-trunc -a -q`'
alias dkillunused='docker rm `docker ps --no-trunc -a -q`;docker rmi $(docker images -a -q)'
alias dkillallunused='dkillunused'
alias dklalli='dklall;docker rmi $(docker images -a -q)'
alias dkillalli='dklall;docker rmi $(docker images -a -q)'
alias dis='docker inspect'
alias drmiunused='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'

alias dprna='docker system prune -a --volumes'
alias dprn='docker system prune'
alias ddf='docker system df'

function dbash { docker run -i -t -u root --entrypoint=/bin/bash "$@" -c /bin/bash; }
function dbashg { docker run -i -t --entrypoint=/bin/bash --gpus all "$@" -c /bin/bash; }
function dbashu { docker run -i -t --entrypoint=/bin/bash "$@" -c /bin/bash; }
function dbashe { docker exec -it "$@" /bin/bash; }

function kbash() { k exec -it -n "$@" -- /bin/bash; }
function ksh() { k exec -it -n "$@" -- /bin/sh; }


function dbind { sudo mount --bind -o uid=1000,gid=1000 /var/lib/docker/aufs/mnt/`docker ps -l -q --no-trunc`/app/ .;cd .; }

alias dmount='dbind'

alias pfr='pip freeze'
alias ipy='ipython'
alias pfrr='pip freeze > requirements.txt'
alias pin='uv pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host download.pytorch.org'
alias pi='uv pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host download.pytorch.org'
alias pinu='uv pip install -U --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host download.pytorch.org'
# alias pi='pip install --cache-dir /media/lee/pipcache'


pins() {
    package_name=$1
    requirements_file=$2
    if [[ -z $requirements_file ]]
    then
        requirements_file='./requirements.txt'
    fi
    uv pip install $package_name --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host download.pytorch.org && pip freeze | grep -i $package_name >> $requirements_file
}

# Check if hub is installed before evaluating
if command -v hub >/dev/null 2>&1; then
  eval "$(hub alias -s)" 2>/dev/null || true
fi

# Codex aliases with dangerous mode for fast execution
alias cxd='codex --dangerously-bypass-approvals-and-sandbox'
alias cxda='codex --auto-edit --dangerously-bypass-approvals-and-sandbox'
alias cxdf='codex --full-auto --dangerously-bypass-approvals-and-sandbox'

alias cxm='codex --dangerously-bypass-approvals-and-sandbox --config model_reasoning_effort=high'
alias cx='codex --dangerously-bypass-approvals-and-sandbox --config model_reasoning_effort=high'
alias cxa='codex --dangerously-bypass-approvals-and-sandbox --config model_reasoning_effort=high --auto-edit'
alias cxf='codex --dangerously-bypass-approvals-and-sandbox --config model_reasoning_effort=high --full-auto'

function cld {
  ANTHROPIC_API_KEY="" 
  bun run "$(which claude)" --dangerously-skip-permissions "$@"
}

function codex_wrapper {
  command codex "$@"
}
alias codex='codex_wrapper'

alias usage='du -sh .[!.]* * | sort -h'
alias usager='du -sh * *  | sort -h'
alias pn=pnpm
alias webserver='python -m SimpleHTTPServer 9090'

alias mailserver='sudo python -m smtpd -n -c DebuggingServer localhost:25'

alias findn='find . -name '

if [[ ! $(uname -s) = "Darwin" ]]; then
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
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


# Creates an archive from given directory
mktar() { tar cvf  "${1%%/}.tar"     "${1%%/}/"; }
mktgz() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }
mktbz() { tar cvjf "${1%%/}.tar.bz2" "${1%%/}/"; }
mkgz() { gzip -v -c $1 > $1.gz; }

alias compress='mktgz'

# Color prompt
force_color_prompt=yes

## Sudo fixes
alias install='sudo apt-get install'
alias pinstall='sudo pip install'
alias ninstall='sudo npm install'
alias pip='uv pip'
export NODE_OPTIONS="--max-old-space-size=8192"


alias cla='ANTHROPIC_API_KEY="" claude'
alias cldc='cld --continue'

alias cr='claude-review'
alias creview='claude-review'
alias claude-rev='claude-review'
alias crc='claude-review --staged'  # review cached/staged changes
alias crw='claude-review'           # review working directory (default)

alias ca='cursor-agent-bun -f'
alias cap='cursor-agent-bun -f -p'

# Claude Git workflow tools
alias cldcmt='cldcmt'               # Claude commit with cleanup
alias cldgcmep='cldgcmep'           # Claude add+commit+push workflow
alias cldfix='cldfix'               # Claude fix issues in changes
alias cldpr='cldpr'                 # Claude pull request generator

# Additional Claude Git aliases
alias ccmt='cldcmt'                 # Short alias for cldcmt
alias cgcmep='cldgcmep'             # Short alias for cldgcmep
alias cfix='cldfix'                 # Short alias for cldfix
alias cpr='cldpr'                   # Short alias for cldpr

# Codex CLI aliases
alias cdx='codex'
alias cdxd='codex --dangerously-bypass-approvals-and-sandbox'
alias cdxf='codex --full-auto'                              # Convenience for sandboxed auto (-a on-failure, --sandbox workspace-write)
alias cdxr='codex --sandbox read-only'                      # Read-only sandbox mode
alias cdxw='codex --sandbox workspace-write'                # Workspace write sandbox mode
alias cdxa='codex apply'                                    # Apply latest diff as git apply
alias cdxe='codex exec'                                     # Run non-interactively
alias cdxs='codex --search'                                 # Enable web search
alias cdxo='codex --oss'                                    # Use local OSS model (Ollama)
alias cdxed='codex exec --dangerously-bypass-approvals-and-sandbox'  # Exec with no sandbox

# Function to run multiple codex prompts in sequence
function cdxm() {
    # Run multiple codex exec commands in sequence
    # Usage: cdxm "first prompt" "second prompt" "third prompt"
    
    local dangerous_mode=""
    if [[ "$1" == "-d" ]]; then
        dangerous_mode="--dangerously-bypass-approvals-and-sandbox"
        shift
    fi
    
    for prompt in "$@"; do
        echo -e "\n\033[1;36m=== Executing: $prompt ===\033[0m"
        codex exec $dangerous_mode "$prompt"
        if [ $? -ne 0 ]; then
            echo -e "\033[1;31mCommand failed, stopping sequence\033[0m"
            return 1
        fi
        echo -e "\033[1;32m=== Completed ===\033[0m\n"
    done
}

# Function to pipe prompts to codex interactively (experimental)
function cdxi() {
    # Interactive codex with initial prompt
    # Usage: cdxi "initial prompt"
    # Then type additional prompts interactively
    
    local dangerous_mode=""
    if [[ "$1" == "-d" ]]; then
        dangerous_mode="--dangerously-bypass-approvals-and-sandbox"
        shift
    fi
    
    if [ -n "$1" ]; then
        codex $dangerous_mode "$1"
    else
        codex $dangerous_mode
    fi
}

# Claude + Git diff functions
function cldgdfaa() {
    if [ -z "$1" ]; then
        echo "Usage: cldgdfaa 'your prompt text'"
        echo "Example: cldgdfaa 'fix these changes and improve the code'"
        return 1
    fi
    {
        echo "$1"
        echo ""
        echo "Here are all the changes in the repository:"
        echo ""
        gunaa
    } | claude
}

function cldgdf() {
    if [ -z "$1" ]; then
        echo "Usage: cldgdf 'your prompt text'"
        echo "Example: cldgdf 'review these changes'"
        return 1
    fi
    {
        echo "$1"
        echo ""
        echo "Here are the git changes:"
        echo ""
        git --no-pager diff -p
    } | claude
}

alias refresh='source ~/.bashrc'
alias reload='source ~/.bashrc'
alias r='rm -rf'

function my_ipe() # Get IP adress on ethernet.
{
    MY_IP=$(/sbin/ifconfig eth0 | awk '/inet/ { print $2 } ' |
      sed -e s/addr://)
    echo ${MY_IP:-"Not connected"}
}

function my_ip() # Get local IP address (any interface)
{
    MY_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
    echo ${MY_IP:-"Not connected"}
}

function my_ip_all() # Get all IP addresses
{
    ip addr show | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1
}

function public_ip() # Get public/external IP address
{
    curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipecho.net/plain
}



################ fzf stuff

# fe [FUZZY PATTERN] - Open the selected file with the default editor
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
fe() {
  local files
  IFS=$'\n' files=($(fzf-tmux --query="$1" --multi --select-1 --exit-0))
  [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# Modified version where you can press
#   - CTRL-O to open with `open` command,
#   - CTRL-E or Enter key to open with the $EDITOR
fo() {
  local out file key
  IFS=$'\n' out=("$(fzf-tmux --query="$1" --exit-0 --expect=ctrl-o,ctrl-e)")
  key=$(head -1 <<< "$out")
  file=$(head -2 <<< "$out" | tail -1)
  if [ -n "$file" ]; then
    [ "$key" = ctrl-o ] && open "$file" || ${EDITOR:-vim} "$file"
  fi
}
# vf - fuzzy open with vim from anywhere
# ex: vf word1 word2 ... (even part of a file name)
# zsh autoload function
vf() {
  local files

  files=(${(f)"$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf --read0 -0 -1 -m)"})

  if [[ -n $files ]]
  then
     vim -- $files
     print -l $files[1]
  fi
}
# fuzzy grep open via ag
vg() {
  local file

  file="$(ag --nobreak --noheading $@ | fzf -0 -1 | awk -F: '{print $1}')"

  if [[ -n $file ]]
  then
     vim $file
  fi
}

# fuzzy grep open via ag with line number
vg() {
  local file
  local line

  read -r file line <<<"$(ag --nobreak --noheading $@ | fzf -0 -1 | awk -F: '{print $1, $2}')"

  if [[ -n $file ]]
  then
     vim $file +$line
  fi
}
# fd - cd to selected directory
fd() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
                  -o -type d -print 2> /dev/null | fzf +m) &&
  cd "$dir"
}
# Another fd - cd into the selected directory
# This one differs from the above, by only showing the sub directories and not
#  showing the directories within those.
fd() {
  DIR=`find * -maxdepth 0 -type d -print 2> /dev/null | fzf-tmux` \
    && cd "$DIR"
}
# fda - including hidden directories
fda() {
  local dir
  dir=$(find ${1:-.} -type d 2> /dev/null | fzf +m) && cd "$dir"
}
# fdr - cd to selected parent directory
fdr() {
  local declare dirs=()
  get_parent_dirs() {
    if [[ -d "${1}" ]]; then dirs+=("$1"); else return; fi
    if [[ "${1}" == '/' ]]; then
      for _dir in "${dirs[@]}"; do echo $_dir; done
    else
      get_parent_dirs $(dirname "$1")
    fi
  }
  local DIR=$(get_parent_dirs $(realpath "${1:-$PWD}") | fzf-tmux --tac)
  cd "$DIR"
}
# cf - fuzzy cd from anywhere
# ex: cf word1 word2 ... (even part of a file name)
# zsh autoload function
cf() {
  local file

  file="$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf --read0 -0 -1)"

  if [[ -n $file ]]
  then
     if [[ -d $file ]]
     then
        cd -- $file
     else
        cd -- ${file:h}
     fi
  fi
}
############# end fzf stuff


export GIT_EDITOR=nvim
# EDITOR and VISUAL now set in conditional platform setup above

#export HISTSIZE=9999
#export HISTFILESIZE=999999

# Java configuration with proper error handling
if [[ "$(uname)" == "Darwin" ]] && command -v /usr/libexec/java_home >/dev/null 2>&1; then
    # macOS - use java_home if available
    JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null) || true
    if [ -n "$JAVA_HOME" ]; then
        export JAVA_HOME
    fi
elif [ -d "/home/lee/.jdks/openjdk-23.0.2" ]; then
    # Linux - use specific JDK if available
    export JAVA_HOME=/home/lee/.jdks/openjdk-23.0.2
fi

# Only add to PATH if JAVA_HOME is set
if [ -n "$JAVA_HOME" ]; then
    export PATH=${PATH}:${JAVA_HOME}/bin
fi
export PATH=${PATH}:$HOME/programs

# Only use bind if we're in bash
if [ -n "$BASH_VERSION" ]; then
  # Cntrl+] to copy current command to clipboard
  # Only use bind in bash (not zsh)
  if [ -n "$BASH_VERSION" ]; then
    bind '"\C-]":"\C-e\C-u pbcopy <<"EOF"\n\C-y\nEOF\n"'
  fi 2>/dev/null || true
fi

alias pbcopy='DISPLAY=:0 xclip -selection clipboard'

alias pbpaste='xclip -selection clipboard -o'
alias goo='go mod tidy && go run .'
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
alias pc='uv pip compile requirements.in -o requirements.txt && uv pip install -r requirements.txt  --python .venv/bin/python'
alias pcw='uv pip compile requirements.in -o requirements.txt && uv pip install -r requirements.txt  --python .venv/Scripts/python.exe'



alias dlg='echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin'


command_exists () {
    type "$1" &> /dev/null ;
}


export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export PATH="$PATH:$HOME/.local/bin" # Add stuff like glances to path

# Set architecture flags
# if mac
if [[ "$OSTYPE" == "darwin"* ]]; then
    export ARCHFLAGS="-arch x86_64"
    chflags nohidden ~/Library/
fi

# virtualenv
export WORKON_HOME=$HOME/.virtualenvs
# Source virtualenvwrapper if available
if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
    source /usr/local/bin/virtualenvwrapper.sh
elif command -v virtualenvwrapper.sh >/dev/null 2>&1; then
    source $(which virtualenvwrapper.sh)
fi

export LESS="-eirMX"

# The next line enables bash completion for gcloud (bash only)
if [ -n "$BASH_VERSION" ]; then
    [ -f '/Users/lee/google-cloud-sdk/completion.bash.inc' ] && source '/Users/lee/google-cloud-sdk/completion.bash.inc'
fi

export RAILS_ENV=development

#export PYTHONPATH=$PYTHONPATH:~/google-cloud-sdk/platform/google_appengine/

## Get rid of the default anaconda install
#export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

export SCALA_HOME="$HOME/programs/scala-2.11.2"
export PATH="$PATH:$SCALA_HOME/bin"
export PATH="$PATH:$HOME/programs/activator-1.2.10-minimal"

export M2_HOME="$HOME/programs/apache-maven-3.2.3"
export M2="$M2_HOME/bin"
export PATH=$M2:$PATH

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

### Set ASDF variable but don't reload to avoid infinite recursion
if [ -z "$ASDF" ]; then
    export ASDF="asdf"
    # Don't source ~/.bashrc again to prevent infinite recursion
fi

export AWS_REGION=us-east-1
#ap-southeast-2


# export PATH="$HOME/programs/go_appengine:$PATH"
# export GOPATH="$HOME/programs/go_appengine/gopath"
# export GOROOT="$HOME/programs/go_appengine/goroot"
# export PATH="$GOROOT/bin:$PATH"
# export PATH=$PATH:$GOPATH/bin

#export GOROOT=/usr/local/go
#export GOPATH=$HOME/go
#export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

source ~/.secretbashrc

# export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
#source ~/.bash_profile
# Lazy load direnv for faster startup
direnv() {
    eval "$(command direnv hook bash 2>/dev/null)"
    command direnv "$@"
}

# Pyenv configuration - optimized for speed
# Set PYENV_ROOT first to avoid the warning message
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# Only initialize pyenv if it exists and we're in an interactive shell
if [ -d "$PYENV_ROOT" ] && [[ $- == *i* ]]; then
    # Use lazy loading for pyenv to speed up startup
    # Only init --path is needed for basic functionality
    if command -v pyenv >/dev/null 2>&1; then
        eval "$(pyenv init --path)"
        # Defer full init to avoid slowing down startup
        # eval "$(pyenv init -)" # Commented out for speed - uncomment if you need shims
    fi
fi

# Guard kubectl completion
# if command -v kubectl >/dev/null 2>&1; then
#     alias k=kubectl
#     source <(kubectl completion bash)
# fi

alias idea='~/programs/idea-IU-211.7442.40/bin/idea.sh'


# Source WSL-specific configuration if running in WSL
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] && [ -f ~/wslbashrc ]; then
    . ~/wslbashrc 2>/dev/null || true
fi

alias kscore="docker run -v $(pwd):/project zegl/kube-score:v1.10.0"

# NVM lazy loading for much faster startup
export NVM_DIR="$HOME/.nvm"
# Don't load NVM immediately - use lazy loading
lazy_load_nvm() {
    unset -f nvm node npm npx 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}
# Stub functions that trigger NVM loading on first use
nvm() { lazy_load_nvm; nvm "$@"; }
node() { lazy_load_nvm; node "$@"; }
npm() { lazy_load_nvm; npm "$@"; }
npx() { lazy_load_nvm; npx "$@"; }



alias charm='/home/lee/programs/pycharm-2022.1.3/bin/pycharm.sh'

alias k='kubectl'

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/lee/programs/google-cloud-sdk/path.bash.inc' ]; then . '/home/lee/programs/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud (bash only)
if [ -n "$BASH_VERSION" ]; then
    [ -f '/home/lee/programs/google-cloud-sdk/completion.bash.inc' ] && . '/home/lee/programs/google-cloud-sdk/completion.bash.inc'
fi

#export PATH="/usr/local/cuda-12.2/$PATH"
export PATH="/usr/local/cuda-12/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda-12.2/lib64:$LD_LIBRARY_PATH"
export PATH="/usr/local/cuda-12.0/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda-12.0/lib64:$LD_LIBRARY_PATH"

export PATH="/usr/local/cuda-11.4/bin:$PATH"

export LD_LIBRARY_PATH="/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH"



export PATH="/home/lee/.pixi/bin:$PATH"

alias unr="cd /mnt/fast/programs/unreal/Engine/Binaries/Linux"

# SDKMAN lazy loading for faster startup
export SDKMAN_DIR="$HOME/.sdkman"
# Don't load SDKMAN immediately - use lazy loading
lazy_load_sdkman() {
    unset -f sdk java gradle maven 2>/dev/null
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
}
sdk() { lazy_load_sdkman; sdk "$@"; }
# Lazy load Rust/Cargo
cargo() {
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    unset -f cargo rustc rustup 2>/dev/null
    cargo "$@"
}
rustc() {
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    unset -f cargo rustc rustup 2>/dev/null
    rustc "$@"
}

# Source WSL-specific configuration if running in WSL
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    if [ -f ~/wslbashrc ]; then
        . ~/wslbashrc 2>/dev/null || true
    fi
fi

alias y="yarn"

function ali { echo "alias $@" >> $HOME/.bashrc; source $HOME/.bashrc; }
function alis { echo "alias $@" >> $HOME/.secretbashrc; source $HOME/.secretbashrc; }

# Function to add aliases to bashrc
function gali {
    if [ $# -eq 0 ]; then
        echo "Usage: gali alias_name='command'"
        echo "Example: gali bb='bun run build'"
        return 1
    fi

    # Add the alias to bashrc
    echo "alias $@" >> $HOME/.bashrc

    # Source bashrc to make it immediately available
    source $HOME/.bashrc

    echo "Alias added: $@"
}

alias reswap='sudo swapoff -a && sudo swapon -a'


alias yi="yarn install"
alias smi="nvidia-smi"
export MODULAR_HOME="$HOME/.modular"
export PATH="$MODULAR_HOME/pkg/packages.modular.com_mojo/bin:$PATH"
alias monoff='sleep 1; xset dpms force off'
alias explorer="explorer.exe ."


# fzf configuration for better shell experience
# [ -f ~/.fzf.bash ] && source ~/.fzf.bash
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --preview 'bat --style=numbers --color=always --line-range :500 {}'"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# Interactive history search with fzf
fh() {
  local cmd
  cmd=$( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac --no-sort --query "$*" | sed 's/ *[0-9]* *//' | sed 's/\[[^]]*\] //')
  if [ -n "$cmd" ]; then
    echo "$cmd"
    # Copy to clipboard if xclip is available
    if command -v xclip &> /dev/null; then
      echo -n "$cmd" | xclip -selection clipboard
      echo "(Copied to clipboard)"
    fi
  fi
}

# pnpm
export PNPM_HOME="/home/lee/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
alias ni=nvim
alias v=nvim


# Find the existing 'o' alias and replace/add this instead
if [[ "$machine" = "Cygwin" || "$machine" = "MinGw" || "$OSTYPE" = "msys" || "$OSTYPE" = "win32" || -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    alias o='explore'
    alias oo='explore'
    # Keep the old direct aliases as alternatives
    alias ox='explorer.exe .'
    alias oox='explorer.exe'
else
    alias o='xdg-open .'
    alias oo='xdg-open'
fi


export PATH="$PATH:/opt/nvim-linux64/bin"
alias ains='sudo apt install'
alias ainst='sudo apt install'

alias qx='at -q X now'
alias qy='at -q Y now'
alias qz='at -q Z now'
export PATH="$PATH:/opt/nvim-linux64/bin:/home/lee/.modular/bin"

#if [ -t 1 ]; then
#  exec zsh
#fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

eep() { "$@"; local status=$?; espeak "${1:0:10}"; return $status; }
# Add dotfiles tools to PATH
export PATH="$PATH:$HOME/code/dotfiles/tools"
export aideg='aider --model gemini/gemini-2.5-pro-preview-06-05 --thinking-tokens 32k'
export aided='aider --model deepseek/deepseek-reasoner'
alias pip='uv pip'
export DATABASE_URL="postgresql://postgres:password@localhost:5432/textgen"
# Chrome profile environment variable

# JavaScript Error Checker alias
alias jscheck='/home/lee/code/dotfiles/tools/jscheck'
alias jserrors='/home/lee/code/dotfiles/tools/jscheck'

# Shell fixup function - refreshes shell configuration
function fixup() {
    echo "Reloading shell configuration..."
    if [ -n "$ZSH_VERSION" ]; then
        source ~/.zshrc
        echo "✓ Zsh configuration reloaded"
    elif [ -n "$BASH_VERSION" ]; then
        source ~/.bashrc
        echo "✓ Bash configuration reloaded"
    fi
    echo "Shell environment refreshed!"
}
# Add tools directory to PATH if not already there
if [[ ":$PATH:" != *":/home/lee/code/dotfiles/tools:"* ]]; then
    export PATH="$PATH:/home/lee/code/dotfiles/tools"
fi
export CHROME_PROFILE_PATH="/home/lee/code/dotfiles/tools/chrome_profiles_export"

# Claude timeout configurations - Never timeout
export BASH_DEFAULT_TIMEOUT_MS=1800000  # 30 minutes default
export BASH_MAX_TIMEOUT_MS=1800000      # 30 minutes max (highest allowed)
export MCP_TIMEOUT=1800000              # 30 minutes for MCP server startup
export MCP_TOOL_TIMEOUT=1800000         # 30 minutes for MCP tool execution
export MAX_MCP_OUTPUT_TOKENS=100000     # Increase MCP output token limit

# Additional Claude configurations to prevent interruptions
export DISABLE_COST_WARNINGS=1          # Disable cost warnings that might interrupt
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=0  # Keep terminal title updates

export PATH="$HOME/.local/bin:$PATH"
# Optimized SSH Agent setup
# Try gnome-keyring first (fastest)
if [ -S "/run/user/$UID/keyring/ssh" ]; then
    export SSH_AUTH_SOCK="/run/user/$UID/keyring/ssh"
elif [ -z "$SSH_AUTH_SOCK" ]; then
    # Only start agent if really needed
    if ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1
    fi
fi

alias br='bun run'
alias v=nvim

# Don't auto-select node version on startup (slow)
# Run 'nvm use node' manually when needed
# Source local environment if it exists (fast check)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
export PATH="/home/lee/.pixi/bin:$PATH"

# Defer SSH key loading - only when needed
# Run 'ssh-add ~/.ssh/id_ed25519' manually if you need the key loaded

alias gdfs='git diff --ext-diff'

# Lynx browser with auto-accept cookies
alias lynx='lynx -accept_all_cookies -cookie_file=~/.lynx/cookies -cookie_save_file=~/.lynx/cookies'
export PATH=/usr/local/go/bin:$PATH

# Git push aliases with test skipping
alias gpsh='SKIP_TESTS=1 git push --no-verify'
alias gpsho='SKIP_TESTS=1 git push --no-verify origin'
alias gpshom='SKIP_TESTS=1 git push --no-verify origin main'

# Pull and push combos
alias gpp='git pull --rebase=false && git push'
alias gpps='git pull --rebase=false && SKIP_TESTS=1 git push --no-verify'

# The "just get it done" alias
alias gityolo='git add -A && git commit -m "sync" --no-verify && git pull --rebase=false --strategy=ours --no-edit && SKIP_TESTS=1 git push --no-verify'

# Smart sync that handles conflicts gracefully
alias gitsync='git stash && git pull --rebase=false && git stash pop && SKIP_TESTS=1 git push --no-verify'

# Enhanced Git status in prompt
parse_git_branch() {
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check if upstream exists
        upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            # Has upstream, check ahead/behind
            ahead=$(git rev-list --count @{u}.. 2>/dev/null)
            behind=$(git rev-list --count ..@{u} 2>/dev/null)
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
            # No upstream
            commits=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
            if [ "$commits" -gt 0 ]; then
                echo " ($branch ⚡$commits)"
            else
                echo " ($branch ⚠️)"
            fi
        fi
    fi
}

function gsp {
    # Git smart push - handles upstream automatically
    branch=$(git branch --show-current)
    if git rev-parse --abbrev-ref "$branch@{upstream}" >/dev/null 2>&1; then
        # Has upstream
        SKIP_TESTS=1 git push --no-verify "$@"
    else
        # No upstream
        echo "Setting upstream to origin/$branch and pushing..."
        SKIP_TESTS=1 git push -u origin "$branch" --no-verify "$@"
    fi
}

function gsync {
    # Super smart sync
    branch=$(git branch --show-current)
    echo "Syncing $branch..."
    
    # Stash if needed
    if ! git diff-index --quiet HEAD --; then
        echo "Stashing changes..."
        git stash
        stashed=1
    fi
    
    # Pull if upstream exists
    if git rev-parse --abbrev-ref "$branch@{upstream}" >/dev/null 2>&1; then
        git pull --rebase=false
    else
        echo "No upstream set, will create on push"
    fi
    
    # Pop stash if we stashed
    if [ "$stashed" = "1" ]; then
        echo "Restoring changes..."
        git stash pop
    fi
    
    # Push (sets upstream if needed)
    gsp
}

function gcheck {
    echo "=== Branch Info ==="
    git branch -vv | grep "^*"
    echo ""
    echo "=== Unpushed Commits ==="
    git log @{u}.. --oneline 2>/dev/null || git log origin/main..HEAD --oneline 2>/dev/null || echo "No unpushed commits (or no upstream)"
    echo ""
    echo "=== Status ==="
    git status -sb
}

# Auto-setup upstream on first push
alias gpu='gsp'
alias gpuf='SKIP_TESTS=1 git push -u origin $(git branch --show-current) --no-verify --force-with-lease'

function gstm {
    
    # Branch and upstream info
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            ahead=$(git rev-list --count @{u}.. 2>/dev/null || echo 0)
            behind=$(git rev-list --count ..@{u} 2>/dev/null || echo 0)
            echo -e "Branch: \033[1;32m$branch\033[0m → $upstream"
            [ "$ahead" -gt 0 ] && echo -e "  \033[1;33m↑ $ahead commit(s) to push\033[0m"
            [ "$behind" -gt 0 ] && echo -e "  \033[1;36m↓ $behind commit(s) to pull\033[0m"
        else
            echo -e "Branch: \033[1;32m$branch\033[0m \033[1;31m(no upstream!)\033[0m"
            commits=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
            [ "$commits" -gt 0 ] && echo -e "  \033[1;33m$commits commit(s) not on origin/main\033[0m"
            echo -e "  \033[0;33mFirst push: git push -u origin $branch\033[0m"
        fi
    fi
    
    git status -sb
}

# Alias to set upstream quickly
alias gsu='git push -u origin $(git branch --show-current)'
alias gsuf='SKIP_TESTS=1 git push -u origin $(git branch --show-current) --no-verify'

# Git helpers
[ -f ~/.git-helpers.sh ] && source ~/.git-helpers.sh

# Trace toolkit for system debugging
if [ -f ~/code/dotfiles/tools/trace-toolkit.sh ]; then
    source ~/code/dotfiles/tools/trace-toolkit.sh
fi

# File watcher management utilities
if [ -f ~/code/dotfiles/tools/watcher-utils.sh ]; then
    source ~/code/dotfiles/tools/watcher-utils.sh >/dev/null 2>&1
fi
export PATH="/usr/local/opt/openjdk/bin:$PATH"
export PATH="/usr/local/opt/trash/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
unset DOCKER_HOST

# Startup timing end
[ -n "$DEBUG_STARTUP" ] && echo "Bashrc end: $(date +%s.%N)"
