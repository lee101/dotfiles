#source $HOME/.bashrc

#[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

##
##

# MacPorts Installer addition on 2014-08-20_at_10:38:55: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.

# added by Anaconda 2.0.1 installer
#export PATH="/Users/lee/anaconda/bin:$PATH"

export PATH="$HOME/.poetry/bin:$PATH"

# The next line enables shell command completion for gcloud.
#if [ -f '/Users/leepenkman/Downloads/google-cloud-sdk2/completion.bash.inc' ]; then . '/Users/leepenkman/Downloads/google-cloud-sdk2/completion.bash.inc'; fi

#if [ -e /home/lee/.nix-profile/etc/profile.d/nix.sh ]; then . /home/lee/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

#if [ -n "$BASH_VERSION" ] && [ -f $HOME/.bashrc ];then
if [ -n "$BASH_VERSION" ] && [ -f $HOME/.bashrc ]; then
    . $HOME/.bashrc
fi


# !! Contents within this block are managed by 'conda init' !!
#if [ -f '/d/condar/Scripts/conda.exe' ]; then
#    eval "$('/d/condar/Scripts/conda.exe' 'shell.bash' 'hook')"
#fi

export MODULAR_HOME="/home/lee/.modular"
export PATH="/home/lee/.modular/pkg/packages.modular.com_mojo/bin:$PATH"


