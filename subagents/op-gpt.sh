#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/openai/gpt-5.6-sol' "$@"
