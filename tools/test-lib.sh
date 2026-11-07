#!/usr/bin/env bash
# Tiny parallel job runner: run_par name cmd... ; wait_par prints a summary and returns non-zero on failure.
_PAR_DIR=$(mktemp -d)
trap 'rm -rf "$_PAR_DIR"' EXIT
_PAR_NAMES=()
run_par() {
    local name=$1; shift
    _PAR_NAMES+=("$name")
    ( "$@" >"$_PAR_DIR/$name.log" 2>&1; echo $? >"$_PAR_DIR/$name.rc" ) &
}
wait_par() {
    wait
    local n rc fail=0
    for n in "${_PAR_NAMES[@]}"; do
        rc=$(cat "$_PAR_DIR/$n.rc" 2>/dev/null || echo 1)
        if [ "$rc" = 0 ]; then echo "PASS $n"; else
            echo "FAIL $n (rc=$rc)"; grep -v -E 'job control|process group' "$_PAR_DIR/$n.log" | tail -25; fail=1
        fi
    done
    return $fail
}
is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0;; *) return 1;; esac; }
# First working python interpreter (Windows only ships `python`).
PY=; for _c in python3 python; do "$_c" -c 1 >/dev/null 2>&1 && { PY=$_c; break; }; done
export PY
