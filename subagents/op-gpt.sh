#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/openai/gpt-6-astra' "$@"
