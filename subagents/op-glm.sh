#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/z-ai/glm-5.3' "$@"
