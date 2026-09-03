#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in install.sh neural-voice-enhance obs-neural obs-wrapper; do
    bash -n "$script_dir/$script"
done
"$script_dir/install.sh" --help >/dev/null

if rg -n '/home/lee|Soundprese|HD_USB' "$script_dir" --glob '!README.md' --glob '!test.sh'; then
    printf 'Machine-specific path or device leaked into portable files.\n' >&2
    exit 1
fi
if ! rg -q '7994ccd41d113d3f97fa1ab7cf4742af56c1b1e88f31d8a86395bd07eb019583' "$script_dir/install.sh"; then
    printf 'Pinned DeepFilterNet checksum is missing.\n' >&2
    exit 1
fi
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck \
        "$script_dir/install.sh" \
        "$script_dir/neural-voice-enhance" \
        "$script_dir/obs-neural" \
        "$script_dir/obs-wrapper"
fi

printf 'Neural voice enhancer static tests passed.\n'
