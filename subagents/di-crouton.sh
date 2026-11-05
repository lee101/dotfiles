#!/usr/bin/env bash
# di subagent pinned to free stealth/crouton-alpha (1M ctx) via OpenRouter.
set -euo pipefail
. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin fx)}
[[ -n ${OPENROUTER_API_KEY:-} ]] || { printf '%s\n' 'OPENROUTER_API_KEY is required for di-crouton.' >&2; exit 2; }
exec env -u OPENPATHS_API_KEY FX_MAX_AGENT_STEPS="${FX_MAX_AGENT_STEPS:-80}" FX_PROVIDER=openpaths FX_MODEL="${DI_CROUTON_MODEL:-stealth/crouton-alpha}" FX_PROVIDER_STRICT=1 "$DI" "$@"
