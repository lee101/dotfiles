#!/usr/bin/env bash
# Direct RunAnywhere (Wally Cloud) GLM-5.3-Flash via RUNANYWHERE_API_KEY, not OpenRouter.
# Usage: op-runanywhere.sh "prompt"   (add -p for print mode, --auto-approve to skip prompts)
# OPANY_MODEL overrides the model (qwen3.8-27b is also hosted on the same key).
# The provider-qualified id keeps the route pinned to Wally: without the key the
# run fails loudly instead of silently falling back to another glm-5.3-flash lane.
set -euo pipefail
model=${OPANY_MODEL:-glm-5.3-flash}
exec op --provider runanywhere --model "runanywhere/$model" "$@"
