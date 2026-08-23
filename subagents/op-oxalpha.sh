#!/usr/bin/env bash
set -euo pipefail
exec op --model 'openrouter/stealth/ox-alpha' "$@"
