#!/usr/bin/env bash
# di subagent pinned to DeepSeek V4 Flash, direct to api.deepseek.com
# (DEEPSEEK_API_KEY) rather than the OpenPaths or OpenRouter routes, with
# di-bunny's bounded step count and hard timeout.
#
# di has no built-in DeepSeek provider: direct access is the named `deepseek`
# connection in ~/.fx/settings.json. A connection that cannot bind is only a
# diagnostic — di falls back to its default route — so this launcher fails fast
# instead of quietly running on another model.
set -euo pipefail

. "$(dirname "$0")/di-locate.sh"
DI=${DI:-$(di_bin di)}
provider=${DI_DEEPSEEK_PROVIDER:-deepseek}
model=${DI_DEEPSEEK_MODEL:-deepseek-v4-flash-vision-exp}
settings=$HOME/.fx/settings.json
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
if [[ -z ${DEEPSEEK_API_KEY:-} ]]; then
  printf '%s\n' 'DEEPSEEK_API_KEY is required for di-deepseek.' >&2
  exit 2
fi

# di silently falls back to the default route when FX_PROVIDER names a
# connection this profile does not define, so check before spending a run.
has_connection() {
  "$(di_python)" - "$settings" "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as handle:
        providers = json.load(handle).get("providers") or {}
except (OSError, ValueError):
    providers = {}
sys.exit(0 if sys.argv[2] in providers else 1)
PY
}
if ! has_connection "$provider"; then
  printf 'di-deepseek.sh: no "%s" connection in %s.\n' "$provider" "$settings" >&2
  cat >&2 <<EOF
Add:
  "providers": {
   "$provider": {
    "protocol": "openai-chat-completions",
    "base_url": "https://api.deepseek.com/v1",
    "auth": { "type": "bearer", "env": "DEEPSEEK_API_KEY" }
   }
  }
EOF
  exit 2
fi

exec env FX_PROVIDER="$provider" FX_MODEL="$model" FX_MAX_AGENT_STEPS="$steps" \
  ${runner:+"$(di_python)" "$runner"} timeout --signal=TERM --kill-after=30s "${seconds}s" "$DI" "$@"
