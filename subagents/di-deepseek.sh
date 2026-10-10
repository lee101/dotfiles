#!/usr/bin/env bash
# di subagent pinned to OpenRouter stealth/space-bunny-alpha, token-frugal.
# Everything goes to files; stdout is only a short digest. Read the digest, then
# tail the files you care about. Usage:
#   di-bunny.sh [-C dir] [-t secs] [-e effort] [-R] [-n name] [-f promptfile] [--] "task"
#   -R  second turn: bunny reviews + fixes its own diff (same session)
set -euo pipefail
DI=${DI:-di}
dir=$PWD; tmo=${DI_BUNNY_TIMEOUT:-1500}; effort=${DI_BUNNY_EFFORT:-}; review=0; name=; pf=
while [ $# -gt 0 ]; do case $1 in
  -C) dir=$2; shift 2;; -t) tmo=$2; shift 2;; -e) effort=$2; shift 2;;
  -R) review=1; shift;; -n) name=$2; shift 2;; -f) pf=$2; shift 2;; --) shift; break;; *) break;;
esac; done
if [ -n "$pf" ]; then task=$(<"$pf"); elif [ $# -gt 0 ]; then task="$*"; else task=$(cat); fi
[ -n "$task" ] || { echo "no task" >&2; exit 2; }
dir=$(cd "$dir" && pwd)
slug=${name:-$(printf %s "$task" | tr -cs 'a-zA-Z0-9' '-' | cut -c1-32)}
out=${DI_BUNNY_OUT:-/tmp/di-bunny}/$(date +%m%d-%H%M%S)-$slug
mkdir -p "$out"; cd "$dir"

snap() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    { git ls-files -m -o --exclude-standard -z 2>/dev/null | xargs -0 -r sha1sum 2>/dev/null; } | sort -k2 || true
  else
    find . -type f -not -path '*/.git/*' -printf '%T@-%s  %p\n' 2>/dev/null | sort -k2 || true
  fi
}
snap > "$out/before.sha"

read -r -d '' rules <<'EOF' || true
Rules (token budget is tight; input and output tokens cost real money):
- Search with rg, read only the line ranges you need (sed -n 'a,bp'), never cat whole large files.
- Pipe noisy commands through tail -40 / head -40 / rg. Never dump long logs or full test output.
- Do not paste file contents back in your replies. Make edits directly, keep prose minimal.
- The working tree is dirty with unrelated uncommitted work by others: thats fine just work as much as we can well, never revert or reformat files you were not asked to change.
- Verify with the narrowest check (bun run build, bunx tsc --noEmit, go test ./server -run X, single playwright spec). Run in background where slow; show only the last 30 lines.
- Finish with a final message of at most 15 lines: files changed, what you verified and how, what is unverified/risky, anything needing a human (payments).
EOF

args=(ask --yolo --json --model ${DI_BUNNY_MODEL:-deepseek/deepseek-v4-flash-vision-exp})
[ -n "$effort" ] && args+=(--effort "$effort")

run() {
  local tag=$1 prompt=$2; shift 2
  env -u OPENPATHS_API_KEY FX_PROVIDER=openrouter timeout "$tmo" "$DI" "${args[@]}" "$@" -- "$prompt" \
    > "$out/$tag.json" 2> "$out/$tag.err" || echo "exit=$?" >> "$out/$tag.err"
}

printf '%s\n' "$task" > "$out/task.md"
SECONDS=0
run run "$rules

Task:
$task"
sid=$(rg -o '"session_id":"[^"]*"' "$out/run.json" 2>/dev/null | tail -1 | cut -d'"' -f4 || true)

if [ "$review" = 1 ] && [ -n "$sid" ]; then
  run review "Review your own changes: run git diff on the files you touched (stat first, then only the hunks that matter). Find bugs, scope creep, broken imports/types, unverified claims. Fix real issues, re-verify narrowly, then give a final message of at most 10 lines." --resume-id "$sid"
fi

snap > "$out/after.sha"
diff "$out/before.sha" "$out/after.sha" | sed -n 's/^> [^ ]*  //p' | sort -u > "$out/changed.txt" || true

{
  echo "out=$out secs=$SECONDS session=${sid:-none}"
  for t in run review; do
    [ -f "$out/$t.json" ] || continue
    printf '[%s] ' "$t"
    bun -e 'const f=process.argv[1];try{const j=JSON.parse(require("fs").readFileSync(f,"utf8"));console.log(`exit=${j.exit_code} steps=${j.steps} tools=${j.tool_calls?.length??0} in=${j.usage?.input_tokens} out=${j.usage?.output_tokens}`);console.log((j.final_output||j.output||"").slice(-1800))}catch(e){console.log("unparsable json: "+e.message)}' "$out/$t.json"
  done
  echo "changed: $(wc -l < "$out/changed.txt")"; head -30 "$out/changed.txt"
  echo "--- stderr tail"; tail -100 "$out/run.err" | tail -15
} | tee "$out/digest.txt"
