#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/google/gemini-3.7-flash' "$@"
