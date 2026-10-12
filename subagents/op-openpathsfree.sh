#!/usr/bin/env bash
set -euo pipefail
model=${OP_FREE_MODEL:-nous/poolside/laguna-s-2.1:free}
[[ "$model" == *:free ]] || { printf 'Only :free models are allowed\n' >&2; exit 2; }
[[ -n "${OPENPATHS_API_KEY:-}" ]] || { printf 'OPENPATHS_API_KEY is required\n' >&2; exit 2; }
for arg in "$@"; do
  case "$arg" in
    --model|--model=*|--provider|--provider=*|--api-key|--api-key=*|--smol|--smol=*|--slow|--slow=*|--plan|--plan=*|--prewalk|--prewalk-into*|--plan-yolo*|--profile*|--config*|--extension*|-e|--hook*)
      printf 'Model routing overrides are disabled in this free-only wrapper\n' >&2; exit 2 ;;
  esac
done
export OP_FREE_MODEL="$model"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
export PI_CODING_AGENT_DIR="$temp" OP_PROFILE= PI_PROFILE=
python3 - "$temp" <<'PY'
import json, os, pathlib, sys
p = pathlib.Path(sys.argv[1])
m = os.environ['OP_FREE_MODEL']
provider = dict(baseUrl='https://openpaths.io/v1', apiKey='OPENPATHS_API_KEY', api='openai-completions', authHeader=True,
    models=[dict(id=m,name=m,reasoning=False,input=['text'],contextWindow=32768,maxTokens=4096,
    cost=dict(input=0,output=0,cacheRead=0,cacheWrite=0))])
(p/'models.yml').write_text(json.dumps({'providers':{'openpaths-free':provider}}))
roles = {r: 'openpaths-free/'+m for r in ['default','smol','slow','vision','plan','designer','commit','tiny','task','advisor']}
(p/'free.yml').write_text(json.dumps({'enabledModels':['openpaths-free/'+m], 'modelRoles':roles,
    'retry':{'fallbackChains':{}}, 'disabledProviders':['native','claude','codex','gemini','opencode','github','agents','agents-md']}))
PY
"${OP:-op}" --config "$temp/free.yml" --no-extensions --no-title \
  --model "openpaths-free/$model" \
  --smol "openpaths-free/$model" --slow "openpaths-free/$model" \
  --plan "openpaths-free/$model" --no-prewalk "$@"
