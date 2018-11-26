source $HOME/.bashrc


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

##
# Your previous /Users/lee/.bash_profile file was backed up as /Users/lee/.bash_profile.macports-saved_2014-08-20_at_10:38:55
##

# MacPorts Installer addition on 2014-08-20_at_10:38:55: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.


# added by Anaconda 2.0.1 installer
#export PATH="/Users/lee/anaconda/bin:$PATH"

# Setting PATH for Python 3.4
# The orginal version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.4/bin:${PATH}"
export PATH

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/lee.penkman/Downloads/google-cloud-sdk/path.bash.inc' ]; then source '/Users/lee.penkman/Downloads/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/lee.penkman/Downloads/google-cloud-sdk/completion.bash.inc' ]; then source '/Users/lee.penkman/Downloads/google-cloud-sdk/completion.bash.inc'; fi
