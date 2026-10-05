#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$repo_dir/setup-nvim.sh" "$@"
