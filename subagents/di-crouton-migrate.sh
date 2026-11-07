#!/usr/bin/env bash
# di-crouton-migrate.sh: drive a how.nz Crouton migration batch via dic.
# Usage:
#   di-crouton-migrate.sh <prompt-file> [out-dir]
# Runs dic ask --full-access --json --no-save with the prompt file,
# retries transient OpenPathsStreamFailed up to DI_CROUTON_ATTEMPTS (default 3),
# writes the full transcript to <out-dir>/dic-migrate-<ts>.log and prints tail.
set -euo pipefail

if (( $# < 1 )) || [[ ! -r $1 ]]; then
  printf '%s\n' 'Usage: di-crouton-migrate.sh READABLE_PROMPT_FILE [OUT_DIR]' >&2
  exit 2
fi
pf=$1
out_dir=${2:-${DI_RUN_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/di-runs}}
mkdir -p "$out_dir"
ts=$(date +%Y%m%d-%H%M%S)
log="$out_dir/dic-migrate-$ts.log"
prompt_copy="$out_dir/dic-migrate-$ts.prompt.txt"
cp "$pf" "$prompt_copy"

attempts=${DI_CROUTON_ATTEMPTS:-3}
if ! [[ $attempts =~ ^[0-9]{1,2}$ ]] || (( 10#$attempts < 1 )); then
  printf '%s\n' 'DI_CROUTON_ATTEMPTS must be between 1 and 99.' >&2
  exit 2
fi
access=${DI_CROUTON_ACCESS:---full-access}
code=0
attempt=0
while (( attempt < 10#$attempts )); do
  attempt=$((attempt + 1))
  code=0
  FX_MAX_AGENT_STEPS=${FX_MAX_AGENT_STEPS:-80} \
    timeout --signal=TERM --kill-after=30s "${DI_CROUTON_TIMEOUT_SECONDS:-1800}s" \
    "$HOME/code/dotfiles/subagents/di-crouton.sh" ask "$access" --json --no-save \
    < "$prompt_copy" > "$log" 2>&1 || code=$?
  grep -q '"error":"OpenPathsStreamFailed"' "$log" || break
  (( attempt < 10#$attempts )) || break
  mv -f "$log" "$log.attempt$attempt"
  printf 'attempt %s/%s died with a provider stream failure; retrying\n' \
    "$attempt" "$attempts" >&2
done

printf 'exit=%s attempt=%s/%s log=%s bytes=%s\n' \
  "$code" "$attempt" "$attempts" "$log" "$(wc -c < "$log" | tr -d ' ')"
tail -n 50 "$log"
exit "$code"
