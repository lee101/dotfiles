#!/usr/bin/env bash
# Direct DeepSeek (DEEPSEEK_API_KEY), not via OpenRouter.
set -euo pipefail
exec op --provider deepseek --model 'deepseek-v4-flash-vision-exp' "$@"
