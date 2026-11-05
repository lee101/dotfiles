#!/usr/bin/env bash
# mojojojo-agent (mjj) pinned to free stealth/crouton-alpha via OpenRouter.
set -euo pipefail
[[ -n ${OPENROUTER_API_KEY:-} ]] || { printf '%s\n' 'OPENROUTER_API_KEY is required for mjj-crouton.' >&2; exit 2; }
MJJ=${MJJ:-$(command -v mjj || true)}
if [[ -z $MJJ ]]; then
  d=${MJJ_DIR:-/nvme0n1-disk/code/mojojojo-agent}
  [[ -d $d ]] || { printf 'mjj not found; set MJJ or MJJ_DIR\n' >&2; exit 2; }
  cd "$d"; exec uv run python -m mjj --provider openrouter --model stealth/crouton-alpha "$@"
fi
exec "$MJJ" --provider openrouter --model stealth/crouton-alpha "$@"
