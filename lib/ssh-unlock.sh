#!/bin/sh
# ssh-unlock.sh - load passphrase-protected keys into the ssh agent, unattended.
#
# Sourced from lib/common_shell on every platform:
#   Windows (Git Bash/MSYS/Cygwin): native Windows OpenSSH agent.
#   macOS: the launchd agent (shared by all terminals + GUI apps). The passphrase
#          is also saved to the login Keychain, so later loads need no env var.
#   Linux: whatever agent SSH_AUTH_SOCK points at.
# The passphrase comes from SSH_KEY_PW (or GIT_SSH_KEY_PASSPHRASE), normally
# exported by the gitignored ~/.secretbashrc. Nothing secret is stored in this file.

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

# ── macOS / Linux ────────────────────────────────────────────────────
_df_ssh_unix_add_bin() {
    # Apple's ssh-add understands --apple-use-keychain; Homebrew's openssh does not.
    if [ "$(uname -s)" = Darwin ] && [ -x /usr/bin/ssh-add ]; then
        printf '%s\n' /usr/bin/ssh-add
    else
        command -v ssh-add
    fi
}

_df_ssh_unix_loaded() {
    local fp
    [ -f "${1}.pub" ] || return 1
    fp=$(ssh-keygen -lf "${1}.pub" 2>/dev/null | awk '{print $2; exit}')
    [ -n "$fp" ] && ssh-add -l 2>/dev/null | grep -Fq -- "$fp"
}

_df_ssh_unix_unlock() {
    [ -n "${SSH_AUTH_SOCK:-}" ] || return 0
    local sa key darwin=0
    sa=$(_df_ssh_unix_add_bin) || return 0
    [ "$(uname -s)" = Darwin ] && darwin=1
    for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
        [ -f "$key" ] || continue
        _df_ssh_unix_loaded "$key" && continue
        # macOS: passphrase already in Keychain? Load it from there (no prompt).
        if [ "$darwin" = 1 ]; then
            "$sa" --apple-load-keychain -q </dev/null >/dev/null 2>&1
            _df_ssh_unix_loaded "$key" && continue
        fi
        [ -n "${SSH_KEY_PW:-}" ] || continue
        # Verify first: with a wrong passphrase ssh-add re-runs SSH_ASKPASS forever.
        if ! ssh-keygen -y -P "$SSH_KEY_PW" -f "$key" >/dev/null 2>&1; then
            [ "${SSH_UNLOCK_VERBOSE:-0}" = 1 ] && echo "ssh-unlock: SSH_KEY_PW does not unlock $key" >&2
            continue
        fi
        if [ "$darwin" = 1 ]; then
            SSH_ASKPASS="$HOME/code/dotfiles/scripts/ssh-askpass.sh" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-x}" \
                "$sa" --apple-use-keychain "$key" </dev/null >/dev/null 2>&1
        else
            SSH_ASKPASS="$HOME/code/dotfiles/scripts/ssh-askpass.sh" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-x}" \
                "$sa" "$key" </dev/null >/dev/null 2>&1
        fi
        if ! _df_ssh_unix_loaded "$key" && [ "${SSH_UNLOCK_VERBOSE:-0}" = 1 ]; then
            echo "ssh-unlock: failed to load $key" >&2
        fi
    done
    return 0
}

_df_ssh_unlock_keys() {
    [ -n "${SSH_KEY_PW:-}" ] || SSH_KEY_PW="${GIT_SSH_KEY_PASSPHRASE:-}"
    export SSH_KEY_PW
    if ! _df_ssh_is_windows; then
        _df_ssh_unix_unlock
        return 0
    fi
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

alias ssh-reload='_df_ssh_unlock_keys; ssh-add -l'
alias ssh-list='ssh-add -l'
alias ssh-clear='ssh-add -D'
