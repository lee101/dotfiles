function dir { ls "$@" ; }

function be { bundle exec "$@" ; }
function bec { RAILS_ENV=cucumber bundle exec cucumber "$@" ; }
function becoff { RAILS_ENV=cucumber bundle exec cucumber -pworks_offline "$@" ; }
function ber {
  bundle exec rake "$@" ;
}
function bes { RAILS_ENV=test bundle exec spec "$@" ; }
function berc { bundle exec rake clean_and_package && bundle exec cucumber "$@" ; }

function feeling-lucky { git pull --rebase && ber && gps "$@" ; }
alias wtf='uname -m -p -r -s && echo "You are `whoami`, logged into `hostname`" && pwd'
function ga { git add "$@" ; }
function gc { git commit "$@" ; }
function gco { git checkout "$@" ; }
function gd { git diff --word-diff "$@" ; }
function gl { git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative "$@" ; }
function gs { git status "$@" ; }
function gss { git stash save "$@" ; }
function gsp { git stash pop "$@" ; }
function rdoc { bundle exec gem list --local | sed "s/ .*//g" | xargs -P 30 -L 1 gem rdoc "$@" ; }

function tenTimes
{
for i in {1..10}; do $@; echo "Result was "$?; done
}

function ll { ls -al "$@" ; }

function gpl { git pull --rebase "$@" ; }
function gps { git push "$@" ; }

