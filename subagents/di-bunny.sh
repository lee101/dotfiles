#!/usr/bin/env bash
set -euo pipefail

DI=${DI:-/nvme0n1-disk/code/di/zig-out/bin/fx}
runner=${DI_AGENT_RUNNER:-/nvme0n1-disk/code/monitoring/run_agent.py}
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
if [[ ! -x $DI || ! -f $runner ]]; then
  printf '%s\n' 'Build di first and provide an existing bounded agent runner.' >&2
  exit 2
fi
if [[ -z ${OPENROUTER_API_KEY:-} ]]; then
  printf '%s\n' 'OPENROUTER_API_KEY is required for di-bunny.' >&2
  exit 2
fi

# OpenPaths otherwise wins when both API keys are present.
exec env -u OPENPATHS_API_KEY FX_PROVIDER=openrouter \
  FX_MODEL=stealth/space-bunny-alpha FX_PROVIDER_STRICT=1 FX_MAX_AGENT_STEPS="$steps" \
  python3 "$runner" timeout --signal=TERM --kill-after=30s "${seconds}s" "$DI" "$@"
