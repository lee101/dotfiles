#source $HOME/.bashrc


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

##
# Your previous /Users/lee/.bash_profile file was backed up as /Users/lee/.bash_profile.macports-saved_2014-08-20_at_10:38:55
##

# MacPorts Installer addition on 2014-08-20_at_10:38:55: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.


# added by Anaconda 2.0.1 installer
#export PATH="/Users/lee/anaconda/bin:$PATH"


export PATH="$HOME/.poetry/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/leepenkman/Downloads/google-cloud-sdk2/path.bash.inc' ]; then . '/Users/leepenkman/Downloads/google-cloud-sdk2/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/leepenkman/Downloads/google-cloud-sdk2/completion.bash.inc' ]; then . '/Users/leepenkman/Downloads/google-cloud-sdk2/completion.bash.inc'; fi
#export PYENV_ROOT="$HOME/.pyenv"
#export PATH="$PYENV_ROOT/bin:$PATH"
#eval "$(pyenv init -)"
if [ -e /home/lee/.nix-profile/etc/profile.d/nix.sh ]; then . /home/lee/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

if [ -n "$BASH_VERSION" ] && [ -f $HOME/.bashrc ];then
    source $HOME/.bashrc
fi
. "$HOME/.cargo/env"
export MODULAR_HOME="/home/lee/.modular"
export PATH="/home/lee/.modular/pkg/packages.modular.com_mojo/bin:$PATH"
