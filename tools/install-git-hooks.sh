#!/usr/bin/env bash
# Point dotfiles, secretdotfiles and tradinginfra at the shared gitleaks hooks
# and sync the shared gitleaks config. Safe to re-run.
set -euo pipefail
export PATH="$HOME/go/bin:$PATH"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks="$here/tools/githooks"
for repo in "$here" "$HOME/code/secretdotfiles" "$HOME/code/tradinginfra"; do
    [ -d "$repo/.git" ] || { echo "skip (not cloned): $repo"; continue; }
    git -C "$repo" config core.hooksPath "$hooks"
    if [ "$repo" != "$here" ]; then
        cp "$here/.gitleaks.toml" "$repo/.gitleaks.toml"
    fi
    echo "hooks installed: $repo"
done
command -v gitleaks >/dev/null 2>&1 || echo "WARN: gitleaks not installed (go install github.com/zricethezav/gitleaks/v8@latest)" >&2
