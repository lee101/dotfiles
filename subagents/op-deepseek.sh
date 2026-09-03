#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/deepseek/deepseek-v4-flash' "$@"
