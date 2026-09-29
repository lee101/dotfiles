#!/usr/bin/env bash
set -euo pipefail
exec op --model 'deepseek-v4-flash' "$@"
