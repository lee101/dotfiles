#!/usr/bin/env python3
"""Bench harness for the native Mojo profile-md core.

Measures best-of-N wall time, median, stdev and peak RSS of a profile-md binary
over one or more inputs. Pair it with test.sh: the suite pins behaviour, this
pins cost, and an optimisation that only moves the second number is noise.

Usage:
  python3 profiling/mojo/bench_pmd.py --bin tools/.bin/profile-md-mojo \\
      --inputs profiling/tests/fixtures/trtexec_large.log -n 7

Build the binary under test first; this harness never builds for you:
  bash profiling/mojo/build.sh /tmp/pmd-cand
"""
from __future__ import annotations

import argparse
import os
import resource
import statistics
import subprocess
import tempfile
import time

_scratch = os.path.join(tempfile.gettempdir(), "pmd-bench-out.md")


def run_once(binary: str, path: str, extra: list[str]) -> tuple[float, int, bytes]:
    before = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    start = time.perf_counter()
    proc = subprocess.run(
        # A regular temp file, not os.devnull: Mojo's open(path, "w") calls
        # chmod on the handle, which fails with EPERM on /dev/null.
        [binary, path, "--out", _scratch] + extra,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    elapsed = time.perf_counter() - start
    after = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    if proc.returncode != 0:
        raise SystemExit(
            f"{binary} {path} exited {proc.returncode}\n"
            + proc.stderr.decode(errors="replace")[-2000:]
        )
    # ru_maxrss for children is a high-water mark across all children, so it can
    # only grow within a process; report the max observed, which is an upper
    # bound for a single run.
    return elapsed, max(after, before), proc.stdout


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", required=True)
    ap.add_argument("--inputs", nargs="+", required=True)
    ap.add_argument("-n", type=int, default=7)
    ap.add_argument("--csv")
    ap.add_argument("--extra", nargs="*", default=[])
    args = ap.parse_args()

    print(f"binary: {args.bin}   runs: {args.n}")
    print(f"{'input':<28} {'best_ms':>9} {'median_ms':>10} {'stdev_ms':>9} "
          f"{'min_rss_mb':>11} {'bytes':>12}")
    rows = []
    for path in args.inputs:
        times, rss, out = [], 0, b""
        for _ in range(args.n):
            elapsed, peak, out = run_once(args.bin, path, args.extra)
            times.append(elapsed * 1000.0)
            rss = max(rss, peak)
        size = os.path.getsize(path)
        best, med = min(times), statistics.median(times)
        sd = statistics.stdev(times) if len(times) > 1 else 0.0
        rows.append((os.path.basename(path), best, med, sd, rss / 1024.0, size))
        print(f"{os.path.basename(path):<28} {best:9.1f} {med:10.1f} {sd:9.1f} "
              f"{rss / 1024.0:11.1f} {size:12d}")
    if args.csv:
        import csv
        with open(args.csv, "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["input", "best_ms", "median_ms", "stdev_ms", "rss_mb", "bytes"])
            w.writerows(rows)


if __name__ == "__main__":
    main()