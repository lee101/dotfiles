# ... existing code ...
# Fix for the "bind command not found" error (around line 655)
if [ -n "$BASH_VERSION" ] && [ -n "$PS1" ]; then
    # Only run bind in interactive bash shells
    bind '"\e[A": history-search-backward' 2>/dev/null
    bind '"\e[B": history-search-forward' 2>/dev/null
fi
# ... existing code ... 