#!/bin/sh
# ssh-unlock.sh - load passphrase-protected keys into the Windows OpenSSH agent.
#
# Sourced from lib/common_shell on Git Bash / MSYS / Cygwin. A no-op elsewhere.
# The passphrase comes from SSH_KEY_PW, normally exported by the gitignored
# ~/.secretbashrc. Nothing secret is stored in this file.

_df_ssh_is_windows() {
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

_df_ssh_win_dir() {
    if [ -d /c/Windows/System32/OpenSSH ]; then
        printf '%s\n' /c/Windows/System32/OpenSSH
    elif [ -d /c/Windows/Sysnative/OpenSSH ]; then
        printf '%s\n' /c/Windows/Sysnative/OpenSSH
    else
        return 1
    fi
}

# Native Windows tools cannot read MSYS paths.
_df_ssh_win_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s\n' "$1"
    fi
}

_df_ssh_agent_sock() {
    printf '%s\n' '\\.\pipe\openssh-ssh-agent'
}

_df_ssh_key_loaded() {
    local key="$1" pub="${1}.pub" dir fp loaded
    [ -f "$pub" ] || return 1
    dir=$(_df_ssh_win_dir) || return 1
    fp=$("$dir/ssh-keygen.exe" -lf "$(_df_ssh_win_path "$pub")" 2>/dev/null |
        awk '{print $2; exit}')
    [ -n "$fp" ] || return 1
    loaded=$(SSH_AUTH_SOCK="$(_df_ssh_agent_sock)" \
        "$dir/ssh-add.exe" -l 2>/dev/null) || return 1
    printf '%s\n' "$loaded" | grep -Fq -- "$fp"
}

_df_ssh_add_key() {
    local key="$1" dir helper
    dir=$(_df_ssh_win_dir) || return 1
    helper="$HOME/code/dotfiles/windows/bin/ssh-askpass.cmd"
    [ -f "$helper" ] || return 1
    [ -n "${SSH_KEY_PW:-}" ] || return 1

    # Windows ssh-add launches SSH_ASKPASS through CreateProcess, so the helper
    # must be a native path to a .cmd/.exe. A shell script fails with error 193.
    SSH_AUTH_SOCK="$(_df_ssh_agent_sock)" \
    SSH_ASKPASS="$(_df_ssh_win_path "$helper")" \
    SSH_ASKPASS_REQUIRE=force \
    DISPLAY=x \
        "$dir/ssh-add.exe" "$(_df_ssh_win_path "$key")" </dev/null >/dev/null 2>&1
}

_df_ssh_unlock_keys() {
    _df_ssh_is_windows || return 0
    # The rotation/mesh tooling stores the passphrase as GIT_SSH_KEY_PASSPHRASE on
    # Linux hosts; accept either name so one ~/.secretbashrc works everywhere.
    [ -n "${SSH_KEY_PW:-}" ] || SSH_KEY_PW="${GIT_SSH_KEY_PASSPHRASE:-}"
    export SSH_KEY_PW
    [ -n "${SSH_KEY_PW:-}" ] || return 0

    local key
    for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
        [ -f "$key" ] || continue
        _df_ssh_key_loaded "$key" && continue
        if ! _df_ssh_add_key "$key"; then
            [ "${SSH_UNLOCK_VERBOSE:-0}" = 1 ] &&
                echo "ssh-unlock: failed to load $key" >&2
        fi
    done
    return 0
}

if _df_ssh_is_windows && _df_ssh_win_dir >/dev/null 2>&1; then
    alias ssh-reload='_df_ssh_unlock_keys; ssh-add -l'
    alias ssh-list='ssh-add -l'
    alias ssh-clear='ssh-add -D'
fi
