#!/usr/bin/env bash
# di subagent pinned to DeepSeek V4 Flash (vision, experimental) via OpenPaths,
# with di-bunny's bounded step count and hard timeout. Needs OPENPATHS_API_KEY.
set -euo pipefail

. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
runner=${DI_AGENT_RUNNER:-$(di_find monitoring/run_agent.py || true)}
seconds=${DI_DEEPSEEK_TIMEOUT_SECONDS:-${DI_BUNNY_TIMEOUT_SECONDS:-21600}}
steps=${FX_MAX_AGENT_STEPS:-80}
if [[ ! $steps =~ ^[0-9]{1,4}$ ]] || (( 10#$steps < 1 || 10#$steps > 1000 )); then
  printf '%s\n' 'FX_MAX_AGENT_STEPS must be between 1 and 1000 for di-deepseek.' >&2
  exit 2
fi
if [[ ! $seconds =~ ^[0-9]{1,5}$ ]] || (( 10#$seconds < 1 || 10#$seconds > 21600 )); then
  printf '%s\n' 'DI_DEEPSEEK_TIMEOUT_SECONDS must be between 1 and 21600.' >&2
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
if [[ -z ${OPENPATHS_API_KEY:-} ]]; then
  printf '%s\n' 'OPENPATHS_API_KEY is required for di-deepseek.' >&2
  exit 2
fi

exec env FX_MODEL='deepseek/deepseek-v4-flash-vision-exp' FX_MAX_AGENT_STEPS="$steps" \
  ${runner:+"$(di_python)" "$runner"} timeout --signal=TERM --kill-after=30s "${seconds}s" "$DI" "$@"
