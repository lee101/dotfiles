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
    find . \( -path ./.git -o -path ./node_modules -o -path ./dist -o -path ./.vite \
      -o -path ./visualbench/shots -o -path ./test-results -o -path ./coverage \) -prune \
      -o -type f -printf '%T@-%s  %p\n' 2>/dev/null | sort -k2 || true
  fi
}

# Text-only tree snapshot: bounded, and the review turn's diff source when the
# workdir is not a git repo (the game fleet is not).
snapshot_tree() {
  local dest=$1
  rm -rf "$dest"; mkdir -p "$dest"
  ( cd "$dir" && find . -type f \
      -not -path './node_modules/*' -not -path './.git/*' -not -path './dist/*' \
      -not -path './.vite/*' -not -path './visualbench/shots/*' \
      -not -path './test-results/*' -not -path './coverage/*' \
      -not -path './visualbench/report.json' -not -path './visualbench/report.html' \
      -not -path './selfplay/report.json' \
      \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' \
         -o -name '*.css' -o -name '*.html' -o -name '*.json' -o -name '*.md' \
         -o -name '*.yaml' -o -name '*.yml' -o -name '*.py' -o -name '*.go' \) \
      -size -2M -print0 2>/dev/null ) | while IFS= read -r -d '' f; do
      mkdir -p "$dest/$(dirname "$f")"; cp -p "$dir/$f" "$dest/$f" 2>/dev/null || true
  done
}

changed_since() {
  local a=$1 b=$2
  ( cd "$b" && find . -type f -print0 ) | while IFS= read -r -d '' f; do
    cmp -s "$b/$f" "$a/$f" || printf '%s\n' "${f#./}"
  done
  comm -13 <(cd "$a" && find . -type f | sort) <(cd "$b" && find . -type f | sort) | sed 's|^\./||'
  comm -23 <(cd "$a" && find . -type f | sort) <(cd "$b" && find . -type f | sort) | sed 's|^\./||'
}

snap > "$out/before.sha"
snapshot_tree "$out/before"

read -r -d '' rules <<'EOF' || true
Rules (token budget is tight; input and output tokens cost real money):
- Use grep_files/glob_files to search and read_file with start_line/line_count for ranges. Do not cat whole large files.
- Shell calls use {"request":{"action":"run","command":"..."}}. No node -e, python -c, heredocs, $() or multi-line shells.
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
  env -u OPENPATHS_API_KEY FX_PROVIDER=${DI_DEEPSEEK_PROVIDER:-openpaths} timeout "$tmo" "$DI" "${args[@]}" "$@" -- "$prompt" \
    > "$out/$tag.json" 2> "$out/$tag.err" || echo "exit=$?" >> "$out/$tag.err"
}

printf '%s\n' "$task" > "$out/task.md"
SECONDS=0
run run "$rules

Task:
$task"
sid=$(rg -o '"session_id":"[^"]*"' "$out/run.json" 2>/dev/null | tail -1 | cut -d'"' -f4 || true)

if [ "$review" = 1 ] && [ -n "$sid" ]; then
  snapshot_tree "$out/after-run"
  ( cd "$out" && diff -ruN before after-run > changes.diff 2>/dev/null || true )
  if [ -s "$out/changes.diff" ]; then
    run review "Review your own changes. The unified diff is $out/changes.diff (read it in chunks with sed -n; it may be large). The workdir is $dir and is NOT a git repo. Find bugs, scope creep, broken imports/types, unverified claims. Fix real issues, re-verify narrowly, then give a final message of at most 10 lines. Do not revert unrelated files." --resume-id "$sid"
  else
    : > "$out/review.skipped"
  fi
fi

snap > "$out/after.sha"
snapshot_tree "$out/after"
changed_since "$out/before" "$out/after" | sort -u > "$out/changed.txt" || true
( cd "$out" && diff -ruN before after > changes.final.diff 2>/dev/null || true )

{
  echo "out=$out secs=$SECONDS session=${sid:-none}"
  for t in run review; do
    [ -f "$out/$t.json" ] || continue
    printf '[%s] ' "$t"
    bun -e 'const f=process.argv[1];try{const j=JSON.parse(require("fs").readFileSync(f,"utf8"));console.log(`exit=${j.exit_code} steps=${j.steps} tools=${j.tool_calls?.length??0} in=${j.usage?.input_tokens} out=${j.usage?.output_tokens}`);console.log((j.final_output||j.output||"").slice(-1800))}catch(e){console.log("unparsable json: "+e.message)}' "$out/$t.json"
  done
  echo "changed: $(wc -l < "$out/changed.txt")"; head -30 "$out/changed.txt"
  [ -f "$out/changes.final.diff" ] && echo "diff: $(wc -l < "$out/changes.final.diff") lines"
  [ -f "$out/review.skipped" ] && echo "review: skipped (no text changes)"
  echo "--- stderr tail"; tail -100 "$out/run.err" | tail -15
} | tee "$out/digest.txt"
