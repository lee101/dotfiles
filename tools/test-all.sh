#!/usr/bin/env bash
# Full suite, parallelised. test-fast.sh covers the quick checks; this adds
# tmux, per-file python tests (one process each, run concurrently) and nvim.
set -uo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$repo_dir/tools/test-lib.sh"
jobs=${TEST_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}

run_par fast "$repo_dir/tools/test-fast.sh"
if is_windows; then echo "SKIP tmux (not supported on Windows)"; else run_par tmux "$repo_dir/tools/test-tmux.sh"; fi

if "$PY" -m pytest --version >/dev/null 2>&1; then
    px=(); "$PY" -c 'import xdist' 2>/dev/null && px=(-n "$jobs")
    run_par python "$PY" -m pytest -q "${px[@]}" "$repo_dir/tools/tests" "$repo_dir/profiling/tests"
else
    run_par python bash -c '
        cd "$0/tools/tests" || exit 1; pids=(); fail=0
        for f in test_*.py; do
            "$PY" -m unittest "${f%.py}" >"/tmp/unit-$$-$f.log" 2>&1 & pids+=($!)
            while [ "$(jobs -r | wc -l)" -ge "$1" ]; do sleep 0.1; done
        done
        for p in "${pids[@]}"; do wait "$p" || fail=1; done
        for f in test_*.py; do tail -3 "/tmp/unit-$$-$f.log" | grep -q "^OK" || { echo "FAILED $f"; fail=1; }; rm -f "/tmp/unit-$$-$f.log"; done
        exit $fail' "$repo_dir" "$jobs"
fi

if command -v nvim >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
    run_par nvim "$repo_dir/test_nvim_config.sh"
fi
wait_par && echo "PASS: all available repository tests"
