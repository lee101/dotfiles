#!/usr/bin/env bash
set -euo pipefail
exec op --model 'glm-5.3-flash' "$@"
