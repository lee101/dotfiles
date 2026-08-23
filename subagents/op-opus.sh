#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/anthropic/claude-opus-5' "$@"
