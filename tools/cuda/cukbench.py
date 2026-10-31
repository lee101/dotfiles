#!/usr/bin/env python3
"""Cold-L2 CUDA-graph microbench for torch callables.

    from cukbench import bench, show
    mn, p50 = bench(lambda i: lambda: kernel(w[i]), copies=16)

Each replay starts after a read-only L2 flush, so a 4 MiB working set cannot
pretend to be a DRAM measurement. The empty-graph replay cost is reported and
subtracted (`net_*`), matching the judge-style timing used by the kernel
challenges. `cukbench` adds a CLI, JSON, and a regression history.

    cukbench --script bench.py --tag attn --reps 50
"""
import argparse
import importlib.util
import json
import os
import statistics as st
import subprocess
import sys
import time
import warnings
from pathlib import Path

import torch

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "cuk"
HIST = CACHE / "bench.jsonl"


class Stats:
    __slots__ = ("min_us", "p50_us", "p90_us", "max_us", "empty_us", "net_min_us", "net_p50_us", "n")

    def __init__(self, **kw):
        for k in self.__slots__:
            setattr(self, k, kw.get(k))

    def __iter__(self):  # keep the old `(min, p50)` unpacking
        yield self.min_us
        yield self.p50_us

    def __getitem__(self, i):
        return (self.min_us, self.p50_us)[i]

    def as_dict(self):
        return {k: getattr(self, k) for k in self.__slots__}


def _pct(xs, q):
    s = sorted(xs)
    return s[min(len(s) - 1, int(q * (len(s) - 1)))]


def _replay_us(g, flush=None, sink=None):
    if flush is not None:
        sink.copy_(flush.sum())  # read-only L2 flush; before the timed event
    a, b = torch.cuda.Event(True), torch.cuda.Event(True)
    a.record()
    g.replay()
    b.record()
    torch.cuda.synchronize()
    return a.elapsed_time(b) * 1e3


def stats(make, copies=16, reps=30, inner=1, flush_mb=256, empty=True, warmup=2):
    """Return Stats in microseconds per call. `make(i)` must return a callable."""
    fns = [make(i) for i in range(copies)]
    for _ in range(max(1, warmup)):
        for f in fns:
            f()
    torch.cuda.synchronize()

    g = torch.cuda.CUDAGraph()
    with torch.cuda.graph(g):
        for _ in range(inner):
            for f in fns:
                f()
    n = copies * inner

    dev = torch.cuda.current_device()
    flush = sink = None
    flush_mb = max(flush_mb, 64) if flush_mb else 0  # enough traffic to keep clocks hot for empty-graph calibration
    if flush_mb:
        flush = torch.ones(int(flush_mb * 2**20) // 4, dtype=torch.float32, device=dev)
        sink = torch.empty((), dtype=torch.float32, device=dev)
        _replay_us(g, flush, sink)  # prime the flush path

    ts = [_replay_us(g, flush, sink) / n for _ in range(max(1, reps))]
    mn, p50 = min(ts), st.median(ts)

    # Measure the empty-graph cost *after* the timed reps: clocks are hot, so
    # the subtraction is not inflated by an idle-clock event floor.
    empty_us = 0.0
    if empty:
        eg = torch.cuda.CUDAGraph()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            with torch.cuda.graph(eg):
                pass
        empty_us = st.median([_replay_us(eg, flush, sink) for _ in range(7)])
    return Stats(min_us=mn, p50_us=p50, p90_us=_pct(ts, 0.9), max_us=max(ts),
                 empty_us=empty_us, net_min_us=max(0.0, mn - empty_us),
                 net_p50_us=max(0.0, p50 - empty_us), n=n)


def bench(make, copies=16, reps=30, inner=1, flush_mb=256, empty=True, warmup=2):
    """Backward-compatible `(min, p50)`; use `stats()` for the full record."""
    s = stats(make, copies, reps, inner, flush_mb, empty, warmup)
    return s.min_us, s.p50_us


def show(name, res, ref=None):
    s = res if isinstance(res, Stats) else Stats(min_us=res[0], p50_us=res[1])
    out = f"{name:36} min {s.min_us:7.2f}us p50 {s.p50_us:7.2f}us p90 {s.p90_us or 0:7.2f}us"
    if s.net_p50_us is not None:
        out += f" net {s.net_p50_us:7.2f}us"
    if ref:
        out += f" x{ref[0] / s.min_us:.2f}"
    print(out)


def _load_script(path):
    p = Path(path)
    spec = importlib.util.spec_from_file_location("cukbench_target", p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    if hasattr(m, "make"):
        return m.make
    if hasattr(m, "fns"):
        fns = m.fns
        return lambda i: fns[i]
    sys.exit(f"{p}: define make(i) or fns")


def _gpu():
    try:
        r = subprocess.run(["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
                           capture_output=True, text=True)
        return r.stdout.strip().splitlines()[0] if r.stdout.strip() else "?"
    except Exception:
        return "?"


def _history():
    rows = []
    if HIST.exists():
        for line in HIST.read_text().splitlines():
            try:
                rows.append(json.loads(line))
            except ValueError:
                pass
    return rows


def main():
    ap = argparse.ArgumentParser(prog="cukbench")
    ap.add_argument("-s", "--script", required=True, help="python file defining make(i) or fns")
    ap.add_argument("--tag", default=None)
    ap.add_argument("--copies", type=int, default=16)
    ap.add_argument("--reps", type=int, default=30)
    ap.add_argument("--inner", type=int, default=1)
    ap.add_argument("--flush-mb", type=int, default=256)
    ap.add_argument("--no-flush", action="store_true")
    ap.add_argument("--no-empty", action="store_true")
    ap.add_argument("--warmup", type=int, default=2)
    ap.add_argument("--baseline", help="history tag to compare against")
    ap.add_argument("--threshold", type=float, default=5.0, help="regression threshold percent")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    s = stats(_load_script(a.script), a.copies, a.reps, a.inner,
              0 if a.no_flush else a.flush_mb, not a.no_empty, a.warmup)
    tag = a.tag or Path(a.script).stem
    hist = _history()
    prev = None
    want = a.baseline or tag
    for r in reversed(hist):
        if r.get("tag") == want:
            prev = r
            break
    delta = None
    if prev and prev.get("net_p50_us") and s.net_p50_us is not None:
        delta = 100 * (s.net_p50_us - prev["net_p50_us"]) / prev["net_p50_us"]
    rec = dict(ts=int(time.time()), tag=tag, gpu=_gpu(), **s.as_dict())
    CACHE.mkdir(parents=True, exist_ok=True)
    with HIST.open("a") as f:
        f.write(json.dumps(rec, separators=(",", ":")) + "\n")
    if a.json:
        print(json.dumps(dict(tag=tag, gpu=rec["gpu"], stats=s.as_dict(),
                              prev_tag=want if prev else None, delta_pct=delta), separators=(",", ":")))
        return
    print(f"{tag:28} {rec['gpu']} min {s.min_us:7.2f} p50 {s.p50_us:7.2f} p90 {s.p90_us:7.2f}us "
          f"empty {s.empty_us:5.2f} net {s.net_p50_us:7.2f}us")
    if prev:
        print(f"  vs {want}: {delta:+.1f}% net p50 ({prev['net_p50_us']:.2f} -> {s.net_p50_us:.2f}us)")
        if delta is not None and delta > a.threshold:
            print(f"  REGRESSION >{a.threshold:.0f}%")
    else:
        print(f"  history: {HIST}")


if __name__ == "__main__":
    main()
