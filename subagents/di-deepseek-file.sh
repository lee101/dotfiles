#!/usr/bin/env bash
# usage: di-deepseek-file.sh <name> <prompt-file>
set -euo pipefail
umask 077
if (( $# != 2 )) || [[ ! $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$ ]] || [[ ! -r $2 ]]; then
  printf '%s\n' 'Usage: di-deepseek-file.sh SAFE_NAME READABLE_PROMPT_FILE' >&2
  exit 2
fi
name=$1; pf=$2
. "$(dirname "$0")/di-locate.sh"
dir=${DI_RUN_DIR:-$(di_find visualbench/gamefleet/runs || printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/di-runs")}; mkdir -p "$dir"
log=$dir/$name.log
prompt=$dir/$name.prompt.txt
set -o noclobber
cat "$pf" > "$prompt"
set +o noclobber

attempts=${DI_BUNNY_ATTEMPTS:-3}
if ! [[ $attempts =~ ^[0-9]{1,2}$ ]] || (( 10#$attempts < 1 )); then
  printf '%s\n' 'DI_BUNNY_ATTEMPTS must be between 1 and 99.' >&2
  exit 2
fi

# The permission reviewer is unconfigured on this provider, so `ask --auto`
# holds every shell action. --full-access is the only mode that can actually
# build, test and benchmark. Override with DI_BUNNY_ACCESS when a caller wants
# the permission checks back. The value must carry its own leading dashes: a
# bare `full-access` is silently taken as the prompt text instead of a flag.
access=${DI_BUNNY_ACCESS:---full-access}

# A provider stream can die mid-run (OpenPathsStreamFailed) with no partial
# credit and, under --no-save, no session to resume, so a lost run costs every
# step it spent. Retry only that transient class; any other failure is a real
# result and is reported as one.
code=0
attempt=0
while (( attempt < 10#$attempts )); do
  attempt=$((attempt + 1))
  code=0
  DI_DEEPSEEK_TIMEOUT_SECONDS=${DI_DEEPSEEK_TIMEOUT_SECONDS:-${DI_BUNNY_TIMEOUT_SECONDS:-600}} \
  FX_MAX_AGENT_STEPS=${FX_MAX_AGENT_STEPS:-24} \
    "$(dirname "$0")/di-deepseek.sh" ask "$access" --json --no-save \
    < "$prompt" > "$log" 2>&1 || code=$?
  grep -q '"error":"OpenPathsStreamFailed"' "$log" || break
  (( attempt < 10#$attempts )) || break
  mv -f "$log" "$log.attempt$attempt"
  printf 'attempt %s/%s died with a provider stream failure; retrying\n' \
    "$attempt" "$attempts" >&2
done

printf 'exit=%s attempt=%s/%s log=%s bytes=%s\n' \
  "$code" "$attempt" "$attempts" "$log" "$(wc -c < "$log" | tr -d ' ')"
"$(di_python)" "$(dirname "$0")/bunny-report.py" "$log" --preview-only
exit "$code"