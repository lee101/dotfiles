# Skip the global compinit in /etc/zsh/zshrc (Ubuntu)
# Oh-my-zsh runs its own compinit with ZSH_DISABLE_COMPFIX
skip_global_compinit=1

# Go - needed for GUI apps (Zed, etc.) that don't source interactive shell config
export GOPATH=$HOME/go
[ -d "/usr/local/go/bin" ] && export GOROOT=/usr/local/go
[ -n "$GOROOT" ] && [[ ":$PATH:" != *":$GOROOT/bin:"* ]] && export PATH="$GOROOT/bin:$PATH"
[[ ":$PATH:" != *":$GOPATH/bin:"* ]] && export PATH="$PATH:$GOPATH/bin"
