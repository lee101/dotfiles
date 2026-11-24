#!/bin/sh
# SSH_ASKPASS helper for lib/ssh-unlock.sh (macOS/Linux): prints the key
# passphrase from the environment (set in the gitignored ~/.secretbashrc).
printf '%s\n' "${SSH_KEY_PW:-${GIT_SSH_KEY_PASSPHRASE:-}}"
