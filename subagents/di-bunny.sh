#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin fx)}
# The bounded runner is optional: machines without the monitoring checkout
# still get the hard timeout below.
runner=${DI_AGENT_RUNNER:-$(di_find monitoring/run_agent.py || true)}
seconds=${DI_BUNNY_TIMEOUT_SECONDS:-21600}
steps=${FX_MAX_AGENT_STEPS:-80}
if [[ ! $steps =~ ^[0-9]{1,4}$ ]] || (( 10#$steps < 1 || 10#$steps > 1000 )); then
  printf '%s\n' 'FX_MAX_AGENT_STEPS must be between 1 and 1000 for di-bunny.' >&2
  exit 2
fi
if [[ ! $seconds =~ ^[0-9]{1,5}$ ]] || (( 10#$seconds < 1 || 10#$seconds > 21600 )); then
  printf '%s\n' 'DI_BUNNY_TIMEOUT_SECONDS must be between 1 and 21600.' >&2
  exit 2
fi
seconds=$((10#$seconds))
steps=$((10#$steps))
if [[ ! -x $DI ]]; then
  printf 'Build di first: no runnable binary at %s (set DI or CODE_DIR).\n' "$DI" >&2
  exit 2
fi
if [[ -n $runner && ! -f $runner ]]; then
  printf 'DI_AGENT_RUNNER does not exist: %s\n' "$runner" >&2
  exit 2
fi
if [[ -z ${OPENROUTER_API_KEY:-} ]]; then
  printf '%s\n' 'OPENROUTER_API_KEY is required for di-bunny.' >&2
  exit 2
fi

# The built-in transport uses OpenRouter when only its key is present.
exec env -u OPENPATHS_API_KEY FX_PROVIDER="${DI_BUNNY_PROVIDER:-openpaths}" \
  FX_MODEL=stealth/space-bunny-alpha FX_PROVIDER_STRICT=1 FX_MAX_AGENT_STEPS="$steps" \
  ${runner:+"$(di_python)" "$runner"} timeout --signal=TERM --kill-after=30s "${seconds}s" "$DI" "$@"
