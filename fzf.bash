# Helper: Build find command based on type (f: files, d: directories, else: all)
__fzf_find__() {
  local mode="${1:-all}"
  local base="command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune"
  case "$mode" in
    f) echo "$base -o -type f -print 2> /dev/null | cut -b3-";;
    d) echo "$base -o -type d -print 2> /dev/null | cut -b3-";;
    *) echo "$base -o -type f -print -o -type d -print -o -type l -print 2> /dev/null | cut -b3-";;
  esac
}

# Enable fuzzy auto-completion with fzf-completion widget on TAB
fzf-completion-widget() {
  # When the trigger is detected at the end of the line, remove it and invoke fzf selection.
  if [[ "$LBUFFER" == *"$FZF_COMPLETION_TRIGGER" ]]; then
    local prefix=${LBUFFER%"$FZF_COMPLETION_TRIGGER"}
    local selection
    selection=$(__fzf_select__ --bind 'tab:accept,enter:accept,right:accept')
    if [[ -n $selection ]]; then
      LBUFFER="${prefix}${selection}"
    fi
  else
    # Otherwise, fall back to the normal expand-or-complete behavior.
    zle expand-or-complete
  fi
}
zle -N hstr
bindkey '^I' hstr

# Auto-completion functions
# Generate path completions using fd command
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Generate directory completions using fd command
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# Enhanced history search function (fixed duplicate and multi-line handling)
__fzf_history__() {
  hstr
}

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

# Enhanced fzf widgets for better shell integration
__fzf_select__() {
  local find_cmd="${FZF_CTRL_T_COMMAND:-$(__fzf_find__ all)}"
  local fzf_opts="--height ${FZF_TMUX_HEIGHT:-40%} --reverse ${FZF_DEFAULT_OPTS} ${FZF_CTRL_T_OPTS}"
  eval "$find_cmd" | fzf $fzf_opts -m "$@" | while read -r item; do
    printf '%q ' "$item"
  done
  echo
}

__fzf_cd__() {
  local find_cmd="${FZF_ALT_C_COMMAND:-$(__fzf_find__ d)}"
  local fzf_opts="--height ${FZF_TMUX_HEIGHT:-40%} --reverse ${FZF_DEFAULT_OPTS} ${FZF_ALT_C_OPTS}"
  local dir
  dir=$(eval "$find_cmd" | fzf $fzf_opts +m) && printf 'cd %q' "$dir"
}

# Fix for fzf file selection widget
__fzf_select_file__() {
  local find_cmd="${FZF_CTRL_T_COMMAND:-$(__fzf_find__ f)}"
  local fzf_opts="--height ${FZF_TMUX_HEIGHT:-40%} --reverse ${FZF_DEFAULT_OPTS} ${FZF_CTRL_T_OPTS}"
  eval "$find_cmd" | fzf $fzf_opts -m "$@"
}

# Fix for fzf directory selection widget 
__fzf_select_dir__() {
  local find_cmd="${FZF_ALT_C_COMMAND:-$(__fzf_find__ d)}"
  local fzf_opts="--height ${FZF_TMUX_HEIGHT:-40%} --reverse ${FZF_DEFAULT_OPTS} ${FZF_ALT_C_OPTS}"
  eval "$find_cmd" | fzf $fzf_opts +m
}

# Fix for fzf process selection widget
__fzf_ps__() {
  ps -ef | sed 1d | fzf --height ${FZF_TMUX_HEIGHT:-50%} --reverse ${FZF_DEFAULT_OPTS} -m | awk '{print $2}'
}


# Migrated to hstr for history search in bash; all fzf widgets and related functions removed.

__hstr_history__() {
  hstr
}

# Bind Ctrl-R to invoke hstr history search (replacing fzf history widget)
if command -v hstr >/dev/null 2>&1; then
  bind -x '"\C-r":__hstr_history__'
fi
