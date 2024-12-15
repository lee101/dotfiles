# Enable fuzzy auto-completion with key bindings
# Ctrl-f: Open fuzzy file finder for selecting files
bind -x '"\C-f": "fzf-file-widget"'
# Ctrl-r: Search command history interactively
bind -x '"\C-r": "fdf"'
# Ctrl-j: Fuzzy directory navigation
bind -x '"\C-j": "fzf-cd-widget"'

# Auto-completion functions
# Generate path completions using fd command
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Generate directory completions using fd command
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# Enhanced history search function
__fzf_history__() {
  local output
  # Search command history with formatting and sorting options
  output=$(
    builtin fc -lnr -2147483648 |  # List history entries in reverse order
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS --tac -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m" fzf
  ) || return
  READLINE_LINE=${output#*$'\t'}  # Extract command from selected history entry
  if [ -z "$READLINE_POINT" ]; then
    echo "$READLINE_LINE"
  else
    READLINE_POINT=0x7fffffff  # Move cursor to end of line
  fi
}

# Key bindings for command line fuzzy finder (only in interactive shell)
if [[ $- =~ i ]]; then
  # \er: Redraw current line after command execution
  bind '"\er": redraw-current-line'
  # Ctrl-g Ctrl-f: Change directory using fuzzy finder
  bind '"\C-g\C-f": "$(__fzf_cd__)\e\C-e\er"'
  # Ctrl-g Ctrl-b: Search and execute command from history
  bind '"\C-g\C-b": "$(__fzf_history__)\e\C-e\er"'
  # Ctrl-g Ctrl-t: Select files/directories using fuzzy finder
  bind '"\C-g\C-t": " \$(__fzf_select__)\e\C-e\er"'
fi

# Use fd instead of find for better performance
# Trigger completion when typing ** followed by TAB
export FZF_COMPLETION_TRIGGER='**'
# Add border and inline info to completion window
export FZF_COMPLETION_OPTS='--border --info=inline'

# Preview window settings for different operations
# File selection preview using bat with line numbers
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
# History preview with toggle option using ? key
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
# Directory preview using tree command
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# Fix for fzf history widget to properly handle multi-line commands
__fzf_history__() {
  local output
  output=$(
    builtin fc -lnr -2147483648 |
    awk '!seen[$0]++' |  # Remove duplicates while preserving order
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS --tac --sync -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m" fzf
  ) || return
  READLINE_LINE=${output#*$'\t'}
  READLINE_POINT=${#READLINE_LINE}
}

# Enhanced fzf widgets for better shell integration
__fzf_select__() {
  local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m "$@" | while read -r item; do
    printf '%q ' "$item"
  done
  echo
}

__fzf_cd__() {
  local cmd dir
  cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"
  dir=$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" fzf +m) && printf 'cd %q' "$dir"
}

# Fix for fzf file selection widget
__fzf_select_file__() {
  local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" fzf -m "$@"
}

# Fix for fzf directory selection widget 
__fzf_select_dir__() {
  local cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"
  eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" fzf +m
}

# Fix for fzf process selection widget
__fzf_ps__() {
  ps -ef | sed 1d | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-50%} --reverse $FZF_DEFAULT_OPTS -m" fzf | awk '{print $2}'
}
