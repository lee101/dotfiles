# tmux Quick Reference Guide

## Getting Started

### Basic Commands
- **Start tmux**: `tmux` or `tmux new -s session-name`
- **Attach to session**: `tmux attach` or `tmux a -t session-name`
- **List sessions**: `tmux ls`
- **Kill session**: `tmux kill-session -t session-name`
- **Detach from session**: `Ctrl+b d`

## Key Bindings (Default Prefix: Ctrl+b)

### Session Management
- `Ctrl+b d` - Detach from current session
- `Ctrl+b $` - Rename current session
- `Ctrl+b s` - List and switch sessions
- `Ctrl+b (` - Switch to previous session
- `Ctrl+b )` - Switch to next session

### Window Management
- `Ctrl+b c` - Create new window
- `Ctrl+b n` - Next window
- `Ctrl+b p` - Previous window
- `Ctrl+b 0-9` - Switch to window by number
- `Ctrl+b l` - Toggle last active window
- `Ctrl+b w` - List windows
- `Ctrl+b ,` - Rename current window
- `Ctrl+b &` - Kill current window

### Pane Management

#### Creating Panes
- `Ctrl+b %` - Split vertically (left/right)
- `Ctrl+b "` - Split horizontally (top/bottom)

#### Navigating Panes
- `Ctrl+b arrow-keys` - Move between panes
- `Ctrl+b o` - Cycle through panes
- `Ctrl+b q` - Show pane numbers (press number to switch)
- `Ctrl+b ;` - Toggle last active pane

#### Resizing Panes
- `Ctrl+b Ctrl+arrow` - Resize pane in direction
- `Ctrl+b Alt+arrow` - Resize pane in larger steps
- `Ctrl+b z` - Toggle pane zoom (fullscreen)

#### Pane Operations
- `Ctrl+b x` - Kill current pane
- `Ctrl+b !` - Convert pane to window
- `Ctrl+b space` - Toggle between pane layouts
- `Ctrl+b {` - Move pane left
- `Ctrl+b }` - Move pane right

### Copy Mode
- `Ctrl+b [` - Enter copy mode (scroll/copy text)
- `Ctrl+b ]` - Paste buffer
- In copy mode (vi-style):
  - `Space` - Start selection
  - `Enter` - Copy selection
  - `q` - Exit copy mode
  - `g` - Go to top
  - `G` - Go to bottom
  - `/` - Search forward
  - `?` - Search backward

### Other Useful Commands
- `Ctrl+b ?` - List all key bindings
- `Ctrl+b :` - Command prompt
- `Ctrl+b t` - Show time

## Command Line Operations

### Session Management
```bash
# Create named session
tmux new -s dev

# Create detached session
tmux new -s background -d

# Attach to specific session
tmux attach -t dev

# Kill all sessions
tmux kill-server

# Rename session
tmux rename-session -t old-name new-name
```

### Window & Pane Commands
```bash
# Create new window with name
tmux new-window -n logs

# Split window from command line
tmux split-window -h  # vertical split
tmux split-window -v  # horizontal split

# Send commands to pane
tmux send-keys -t dev:0.0 'ls -la' Enter
```

## Common Workflows

### Development Setup
```bash
# Create dev session with multiple windows
tmux new -s dev -n editor
tmux new-window -n server
tmux new-window -n logs
tmux select-window -t 0
```

### Monitoring Setup
```bash
# Create monitoring dashboard
tmux new -s monitor
tmux split-window -h
tmux split-window -v
tmux select-pane -t 0
tmux split-window -v
# Now you have 4 panes for different monitors
```

## Configuration Tips (~/.tmux.conf)

### Essential Settings
```bash
# Change prefix to Ctrl+a (easier to reach)
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Enable mouse support
set -g mouse on

# Vi mode for copy
setw -g mode-keys vi

# Faster key repetition
set -s escape-time 0

# More history
set -g history-limit 10000
```

### Better Splits
```bash
# More intuitive split commands
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Easy pane resizing
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5
```

### Navigation Improvements
```bash
# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Quick window switching
bind -r C-h select-window -t :-
bind -r C-l select-window -t :+

# Synchronize panes toggle
bind y setw synchronize-panes
```

### Status Bar Customization
```bash
# Status bar colors
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]#(date +"%H:%M")'

# Active window highlighting
setw -g window-status-current-style bg=red,fg=white,bold
```

## Pro Tips

1. **Persistent Sessions**: tmux sessions survive SSH disconnects
2. **Pair Programming**: Share tmux sessions with `tmux -S /tmp/shared attach`
3. **Scripting**: Automate layouts with tmux scripts
4. **Plugins**: Use TPM (Tmux Plugin Manager) for enhanced features
5. **Resurrect**: Save/restore sessions with tmux-resurrect plugin

## Quick Comparison: tmux vs Screen

| Feature | tmux | Screen |
|---------|------|---------|
| Split panes | Native support | Limited |
| Scripting | Excellent | Good |
| Status bar | Customizable | Basic |
| Copy mode | Vi/Emacs | Limited |
| Performance | Better | Good |
| Learning curve | Moderate | Easier |

## Emergency Commands

- **Stuck pane**: `Ctrl+b x` then `y` to kill
- **Frozen tmux**: `tmux kill-server` from another terminal
- **Lost session**: `tmux ls` to find, `tmux attach` to reconnect
- **Reset pane**: `Ctrl+b :` then type `respawn-pane -k`