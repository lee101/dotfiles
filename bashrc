 # ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# Eternal bash history.
# ---------------------
# Undocumented feature which sets the size to "unlimited".
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "
# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_eternal_history
# Force prompt to write history after every command.
# http://superuser.com/questions/20900/bash-history-loss
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"


# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
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

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

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

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

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

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

## =============           My things        =================
## =============           My things        =================
## =============           My things        =================
## =============           My things        =================

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

alias gpr='hub pull-request'


alias gst='git status'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcom='git checkout master'
alias gcl='git clone --recurse-submodules'
alias gclo='git clone'
alias gcm='git commit -m'
alias gcmt='git commit'
alias gcma='git commit -a -m'
alias gcmamd='git commit --amend -C HEAD'
alias gbr='git branch'
alias gdf='git diff'
alias gdfc='git diff --cached'
alias gdfx='git diff --cached'
alias gdfm='git diff --diff-filter=M --ignore-space-change'
alias glg='git log'
alias glglee='git log --author=lee'
alias glgme='git log --author=lee'
alias gmg='git merge'
alias gmga='git merge --abort'
alias gmgm='git merge master'
alias gmm='git merge master'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbim='git rebase -i master'
alias grbm='git rebase master'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grl='git reflog'
alias gad='git add'
alias gadi='git add -i'
alias gada='git add -A'
alias gaa='git add -A'
alias gph='git push; git push --tags'
alias gpsh='git push; git push --tags'
alias gphf='git push -f; git push -f --tags'
alias gpshf='git push -f; git push -f --tags'
alias gpl='git pull'
alias gplrb='git pull --rebase'
alias gpm='git checkout master;git pull;git checkout -;'
alias gplm='git checkout master;git pull;git checkout -;'

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


function gbsu {
    current_branch=`git rev-parse --abbrev-ref HEAD`
    git branch --set-upstream-to=origin/$current_branch $current_branch
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

function gcmp { git commit -m "$@" ; git push; }
function gcmpf { git commit -m "$@" ; git push -f; }
function gcmap { git commit -a -m "$@" ; git push; }
function gcmapf { git commit -a -m "$@" ; git push -f; }
function gcme { git add -A; git commit -a -m "$@" ; }
function gcmep { git add -A; git commit -a -m "$@" ; git push; }
function gcmepf { git add -A; git commit -a -m "$@" ; git push -f; }


function gswf {
  gsw "$@" | grep '\-\-\- a/' | cut -b 6-;
}


alias dps='docker ps'
alias dlg='docker logs'
alias drm='docker rm'
alias drmi='docker rmi'
alias dkl='docker kill'
alias dstt='docker start'
alias dstp='docker stop'
alias dklall='docker stop $(docker ps -a -q); docker rm `docker ps --no-trunc -a -q`'
alias dkillall='docker stop $(docker ps -a -q);docker rm `docker ps --no-trunc -a -q`'
alias dkillunused='docker rm `docker ps --no-trunc -a -q`;docker rmi $(docker images -a -q)'
alias dkillallunused='dkillunused'
alias dklalli='dklall;docker rmi $(docker images -a -q)'
alias dkillalli='dklall;docker rmi $(docker images -a -q)'
alias dis='docker inspect'

function dbash { sudo docker run -i -t -u root --entrypoint=/bin/bash "$@" -c /bin/bash; }
function dbashu { docker run -i -t --entrypoint=/bin/bash "$@" -c /bin/bash; }
function dbind { sudo mount --bind -o uid=1000,gid=1000 /var/lib/docker/aufs/mnt/`docker ps -l -q --no-trunc`/app/ .;cd .; }

alias dmount='dbind'

alias pfr='pip freeze'
alias ipy='ipython'
alias pfrr='pip freeze > requirements.txt'
alias pin='pip install'
alias pinu='pip install -U'

pins() {
    package_name=$1
    requirements_file=$2
    if [[ -z $requirements_file ]]
    then
        requirements_file='./requirements.txt'
    fi
    pip install $package_name && pip freeze | grep -i $package_name >> $requirements_file
}

eval "$(hub alias -s)"

alias usage='du -sh .[!.]* * | sort -h'

alias webserver='python -m SimpleHTTPServer 9090'

alias mailserver='sudo python -m smtpd -n -c DebuggingServer localhost:25'

alias findn='find . -name '

alias o='xdg-open'


if [ ! $(uname -s) = "Darwin" ]; then
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
  alias open='xdg-open'
fi
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

# Creates an archive from given directory
mktar() { tar cvf  "${1%%/}.tar"     "${1%%/}/"; }
mktgz() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }
mktbz() { tar cvjf "${1%%/}.tar.bz2" "${1%%/}/"; }

alias compress='mktgz'

# Color prompt
force_color_prompt=yes

## Sudo fixes
alias install='sudo apt-get install'
alias pinstall='sudo pip install'
alias ninstall='sudo npm install'

alias refresh='source ~/.bashrc'
alias reload='source ~/.bashrc'
alias r='rm -rf'

function my_ipe() # Get IP adress on ethernet.
{
    MY_IP=$(/sbin/ifconfig eth0 | awk '/inet/ { print $2 } ' |
      sed -e s/addr://)
    echo ${MY_IP:-"Not connected"}
}

function my_ip() # Get IP adress on wireless.
{
    MY_IP=$(/sbin/ifconfig wlan | awk '/inet/ { print $2 } ' |
      sed -e s/addr://)
    echo ${MY_IP:-"Not connected"}
}

################# AWS stuff
# Retrieves the acc id for the target profile
# Arguments:
# $1: profile
function acc() {
  local profile=$1
  local acc_id=$(aws sts get-caller-identity --profile "${profile}" --query "Account" --output text)
  echo "The account id for ${profile} is: ${acc_id} -- this value is now on the clipboard"
  echo "${acc_id}" | pbcopy
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





export GIT_EDITOR=vim
export VISUAL=vim
export EDITOR=vim

export HISTSIZE=9999
export HISTFILESIZE=999999

export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
export PATH=${PATH}:${JAVA_HOME}/bin:$HOME/programs

# Cntrl+] to copy current command to clipboard
bind '"\C-]":"\C-e\C-u pbcopy <<"EOF"\n\C-y\nEOF\n"'

command_exists () {
    type "$1" &> /dev/null ;
}


export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

# Set architecture flags
export ARCHFLAGS="-arch x86_64"
chflags nohidden ~/Library/

# virtualenv
export WORKON_HOME=$HOME/.virtualenvs
source /usr/local/bin/virtualenvwrapper.sh

export LESS="-eirMX"

# The next line enables bash completion for gcloud.
source '/Users/lee/google-cloud-sdk/completion.bash.inc'

export RAILS_ENV=development

export PYTHONPATH=$PYTHONPATH:~/google-cloud-sdk/platform/google_appengine/

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



### reload because colors are weird otherwise?
if [ -z "$ASDF" ]; then
    export ASDF="asdf"
    reload
fi

export AWS_REGION=ap-southeast-2


#export PATH="$HOME/programs/go_appengine:$PATH"
#export GOPATH="$HOME/programs/go_appengine/gopath"
#export GOROOT="$HOME/programs/go_appengine/goroot"
#export PATH="$GOROOT/bin:$PATH"
#export PATH=$PATH:$GOPATH/bin

source ~/.secretbashrc

# The next line updates PATH for the Google Cloud SDK.
source '/usr/home/lpenkman/google-cloud-sdk/path.bash.inc'

# The next line enables shell command completion for gcloud.
source '/usr/home/lpenkman/google-cloud-sdk/completion.bash.inc'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

eval "$(pyenv init -)"

alias awsecrlogin="aws ecr get-login --no-include-email --region ap-southeast-2 | sh"
export IS_LOCAL_DEV=true
##export PYTHONPATH="$PYTHONPATH:/Users/lee.penkman/Downloads/google-cloud-sdk/lib:/Users/lee.penkman/Downloads/google-cloud-sdk/platform/google_appengine:/Users/lee.penkman/Downloads/google-cloud-sdk/platform/google_appengine/lib/yaml/lib"

export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"


export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
