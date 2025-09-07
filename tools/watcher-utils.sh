#!/bin/bash

# File watcher utilities for managing inotify watches

# Check current watcher usage
watcher_status() {
    echo "=== File Watcher Status ==="
    echo ""
    echo "System limits:"
    echo "  Max user watches: $(cat /proc/sys/fs/inotify/max_user_watches)"
    echo "  Max instances: $(cat /proc/sys/fs/inotify/max_user_instances)"
    echo "  Max queued events: $(cat /proc/sys/fs/inotify/max_queued_events)"
    echo ""
    echo "Current usage:"
    local watch_count=$(find /proc/*/fd -lname anon_inode:inotify 2>/dev/null | cut -d/ -f3 | xargs -I '{}' -- ps --no-headers -o '%p %U %c' -p '{}' 2>/dev/null | wc -l)
    echo "  Active watchers: $watch_count"
    echo ""
    echo "Top processes using inotify:"
    find /proc/*/fd -lname anon_inode:inotify 2>/dev/null | cut -d/ -f3 | xargs -I '{}' -- ps --no-headers -o '%U %p %c' -p '{}' 2>/dev/null | sort | uniq -c | sort -rn | head -10
}

# Kill processes with too many watchers
watcher_cleanup() {
    echo "Cleaning up excessive file watchers..."
    
    # Kill common culprits
    pkill -f "node.*watch" 2>/dev/null || true
    pkill -f "webpack.*watch" 2>/dev/null || true
    pkill -f "chokidar" 2>/dev/null || true
    pkill -f "watchman" 2>/dev/null || true
    
    echo "Cleanup complete. Run 'watcher_status' to check current usage."
}

# Reset all watchers (aggressive)
watcher_reset() {
    echo "⚠️  This will kill ALL processes using file watchers!"
    read -p "Are you sure? (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "Resetting all file watchers..."
        
        # Find and kill all processes using inotify
        find /proc/*/fd -lname anon_inode:inotify 2>/dev/null | cut -d/ -f3 | while read pid; do
            local cmd=$(ps --no-headers -o '%c' -p "$pid" 2>/dev/null)
            if [ -n "$cmd" ]; then
                echo "  Killing $cmd (PID: $pid)"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
        
        echo "All watchers reset."
    else
        echo "Cancelled."
    fi
}

# Monitor watcher usage in real-time
watcher_monitor() {
    watch -n 2 'bash -c "source ~/code/dotfiles/tools/watcher-utils.sh && watcher_status"'
}

# Increase watcher limits (requires sudo)
watcher_increase() {
    echo "Increasing file watcher limits..."
    
    # Set higher limits
    sudo sysctl fs.inotify.max_user_watches=524288
    sudo sysctl fs.inotify.max_user_instances=1024
    sudo sysctl fs.inotify.max_queued_events=32768
    
    echo "Limits increased for this session."
    echo "To make permanent, run: ~/code/dotfiles/tools/fix-watchers.sh"
}

# Find which directories are being watched
watcher_dirs() {
    echo "=== Directories Being Watched ==="
    lsof 2>/dev/null | grep inotify | awk '{print $9}' | sort | uniq -c | sort -rn | head -20
}

# Aliases for convenience
alias ws='watcher_status'
alias wc='watcher_cleanup'
alias wr='watcher_reset'
alias wm='watcher_monitor'
alias wi='watcher_increase'
alias wd='watcher_dirs'

# Export functions
export -f watcher_status
export -f watcher_cleanup
export -f watcher_reset
export -f watcher_monitor
export -f watcher_increase
export -f watcher_dirs

echo "File watcher utilities loaded. Commands:"
echo "  ws / watcher_status   - Check current watcher usage"
echo "  wc / watcher_cleanup  - Clean up excessive watchers"
echo "  wr / watcher_reset    - Reset ALL watchers (aggressive)"
echo "  wm / watcher_monitor  - Monitor usage in real-time"
echo "  wi / watcher_increase - Increase limits (requires sudo)"
echo "  wd / watcher_dirs     - Show watched directories"