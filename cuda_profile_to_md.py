#!/usr/bin/env python3
"""
cuda_profile_to_md.py — Convert CUDA/PyTorch profiling data to readable markdown.

Supports:
  - Parsing torch.profiler Chrome trace JSON files
  - Direct profiling of a Python callable via torch.profiler
  - CLI: inline profiling of a shell command

Usage (CLI):
  python cuda_profile_to_md.py --trace profile.json --output report.md --top 20
  python cuda_profile_to_md.py --run "python -c 'import torch; ...'" --output report.md

Usage (Python API):
  from cuda_profile_to_md import profile_to_markdown, trace_to_markdown
  md = trace_to_markdown("trace.json", top_n=20)
  md = profile_to_markdown(lambda: model(x), warmup=3, runs=5)
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from typing import Any, Callable, Optional


# ---------------------------------------------------------------------------
# Chrome-trace JSON parsing
# ---------------------------------------------------------------------------

def _load_trace(path: str) -> list[dict[str, Any]]:
    """Load Chrome trace JSON and return the event list."""
    with open(path, "r") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return data.get("traceEvents", [])
    return []


def _is_kernel_event(ev: dict) -> bool:
    """Return True if event looks like a GPU kernel execution."""
    cat = ev.get("cat", "")
    name = ev.get("name", "")
    ph = ev.get("ph", "")
    if ph not in ("X", "B", "E"):
        return False
    # torch.profiler marks GPU kernels with cat "kernel" or "gpu_memcpy"
    if cat in ("kernel", "Kernel", "gpu_kernel"):
        return True
    # Nsight/nvprof traces may use different categories
    if cat in ("cuda", "gpu"):
        return True
    # Heuristic: names that look like CUDA kernels
    # Note: "aten::" is excluded — those are CPU-side PyTorch operators,
    # not GPU kernels.  GPU kernels use "at::native::" in void function names.
    kernel_hints = (
        "gemm", "sgemm", "dgemm", "hgemm",
        "cutlass", "volta", "ampere", "sm80", "sm90",
        "elementwise", "reduce", "softmax", "layernorm",
        "nchwToNhwc", "nhwcToNchw",
        "vectorized", "at::native",
    )
    name_lower = name.lower()
    for hint in kernel_hints:
        if hint in name_lower:
            return True
    return False


def _is_memcpy_event(ev: dict) -> bool:
    cat = ev.get("cat", "")
    name = ev.get("name", "")
    if "memcpy" in name.lower() or "memcpy" in cat.lower():
        return True
    return False


def _memcpy_direction(ev: dict) -> str:
    name = ev.get("name", "").lower()
    args = ev.get("args", {})
    # torch profiler uses names like "Memcpy HtoD", "Memcpy DtoH"
    if "htod" in name:
        return "H->D"
    if "dtoh" in name:
        return "D->H"
    if "dtod" in name:
        return "D->D"
    # Check args
    src = str(args.get("src", "")).lower()
    dst = str(args.get("dst", "")).lower()
    if "host" in src and "device" in dst:
        return "H->D"
    if "device" in src and "host" in dst:
        return "D->H"
    if "device" in src and "device" in dst:
        return "D->D"
    return "Unknown"


def _is_sync_event(ev: dict) -> bool:
    return "synchronize" in ev.get("name", "").lower()


def _is_mem_event(ev: dict) -> bool:
    """Memory allocation / deallocation events."""
    name = ev.get("name", "").lower()
    cat = ev.get("cat", "").lower()
    if "malloc" in name or "cudamalloc" in name or "alloc" in cat:
        return True
    if "[memory]" in name or cat == "memory":
        return True
    return False


def _event_dur_ms(ev: dict) -> float:
    """Duration in milliseconds. Chrome trace stores dur in microseconds."""
    return ev.get("dur", 0) / 1000.0


def _event_bytes(ev: dict) -> float:
    """Try to extract byte count from event args."""
    args = ev.get("args", {})
    for key in ("bytes", "Bytes", "size", "Size", "num_bytes"):
        if key in args:
            val = args[key]
            if isinstance(val, (int, float)):
                return float(val)
            try:
                return float(val)
            except (ValueError, TypeError):
                pass
    return 0.0


# ---------------------------------------------------------------------------
# Trace analysis
# ---------------------------------------------------------------------------

def analyze_trace(events: list[dict], top_n: int = 20) -> dict[str, Any]:
    """Analyze Chrome trace events and return structured data for report."""

    kernel_stats: dict[str, dict] = defaultdict(lambda: {"calls": 0, "total_us": 0.0})
    memcpy_stats: dict[str, dict] = defaultdict(
        lambda: {"count": 0, "total_bytes": 0.0, "total_us": 0.0}
    )
    sync_stats: dict[str, dict] = defaultdict(lambda: {"count": 0, "total_us": 0.0})
    mem_allocs: list[dict] = []

    total_gpu_us = 0.0
    total_cpu_us = 0.0

    for ev in events:
        ph = ev.get("ph", "")
        if ph != "X":
            # Only handle complete events for duration stats
            # (B/E pairs would need matching, skip for simplicity)
            continue

        dur_us = ev.get("dur", 0)
        name = ev.get("name", "")
        cat = ev.get("cat", "")

        if _is_kernel_event(ev):
            kernel_stats[name]["calls"] += 1
            kernel_stats[name]["total_us"] += dur_us
            total_gpu_us += dur_us

        elif _is_memcpy_event(ev):
            direction = _memcpy_direction(ev)
            memcpy_stats[direction]["count"] += 1
            memcpy_stats[direction]["total_bytes"] += _event_bytes(ev)
            memcpy_stats[direction]["total_us"] += dur_us
            total_gpu_us += dur_us

        elif _is_sync_event(ev):
            sync_stats[name]["count"] += 1
            sync_stats[name]["total_us"] += dur_us
            total_cpu_us += dur_us

        elif _is_mem_event(ev):
            mem_allocs.append({
                "name": name,
                "bytes": _event_bytes(ev),
                "ts": ev.get("ts", 0),
                "dur_us": dur_us,
            })

        else:
            # General CPU-side event
            total_cpu_us += dur_us

    # Sort kernels by total time descending
    sorted_kernels = sorted(
        kernel_stats.items(), key=lambda kv: kv[1]["total_us"], reverse=True
    )[:top_n]

    return {
        "kernels": sorted_kernels,
        "memcpy": dict(memcpy_stats),
        "sync": dict(sync_stats),
        "mem_allocs": mem_allocs,
        "total_gpu_us": total_gpu_us,
        "total_cpu_us": total_cpu_us,
    }


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------

def _fmt_ms(us: float) -> str:
    """Format microseconds as milliseconds string."""
    ms = us / 1000.0
    if ms >= 100:
        return f"{ms:,.1f}"
    if ms >= 1:
        return f"{ms:.2f}"
    return f"{ms:.3f}"


def _fmt_mb(b: float) -> str:
    mb = b / (1024 * 1024)
    if mb >= 10:
        return f"{mb:,.1f}"
    return f"{mb:.3f}"


def _generate_markdown(analysis: dict[str, Any], top_n: int = 20) -> str:
    """Generate markdown report from analysis dict."""
    lines: list[str] = []
    lines.append("# CUDA Profiling Report")
    lines.append("")
    lines.append(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")

    total_gpu_ms = analysis["total_gpu_us"] / 1000.0
    total_cpu_ms = analysis["total_cpu_us"] / 1000.0

    # --- Kernel Hotspots ---
    lines.append("## GPU Kernel Hotspots")
    lines.append("")
    kernels = analysis["kernels"]
    if kernels:
        lines.append(
            "| Rank | Kernel | Calls | Total (ms) | Avg (ms) | % GPU |"
        )
        lines.append(
            "|------|--------|-------|-----------|---------|-------|"
        )
        for i, (name, stats) in enumerate(kernels, 1):
            calls = stats["calls"]
            total_us = stats["total_us"]
            avg_us = total_us / calls if calls else 0
            pct = (total_us / analysis["total_gpu_us"] * 100) if analysis["total_gpu_us"] > 0 else 0
            # Truncate very long kernel names
            display_name = name if len(name) <= 60 else name[:57] + "..."
            lines.append(
                f"| {i} | `{display_name}` | {calls} | {_fmt_ms(total_us)} | {_fmt_ms(avg_us)} | {pct:.1f}% |"
            )
        lines.append("")
    else:
        lines.append("_No GPU kernel events found._")
        lines.append("")

    # --- Host-Device Transfers ---
    lines.append("## Host <-> Device Transfers")
    lines.append("")
    memcpy = analysis["memcpy"]
    if memcpy:
        lines.append(
            "| Direction | Count | Total (MB) | Total (ms) | Avg (MB/s) |"
        )
        lines.append(
            "|-----------|-------|-----------|-----------|------------|"
        )
        for direction in ("H->D", "D->H", "D->D", "Unknown"):
            if direction not in memcpy:
                continue
            stats = memcpy[direction]
            count = stats["count"]
            total_bytes = stats["total_bytes"]
            total_us = stats["total_us"]
            total_ms = total_us / 1000.0
            total_mb = total_bytes / (1024 * 1024)
            avg_mbps = (total_mb / (total_ms / 1000.0)) if total_ms > 0 else 0
            lines.append(
                f"| {direction} | {count} | {_fmt_mb(total_bytes)} | {_fmt_ms(total_us)} | {avg_mbps:,.0f} |"
            )
        lines.append("")
    else:
        lines.append("_No memory transfer events found._")
        lines.append("")

    # --- Memory Timeline ---
    lines.append("## Memory Timeline")
    lines.append("")
    mem_allocs = analysis["mem_allocs"]
    if mem_allocs:
        # Sort by timestamp
        mem_allocs_sorted = sorted(mem_allocs, key=lambda x: x["ts"])
        lines.append(
            "| Stage | Allocated (MB) | Delta (MB) | Peak (MB) |"
        )
        lines.append(
            "|-------|---------------|-----------|----------|"
        )
        running = 0.0
        peak = 0.0
        # Group into up to 10 buckets
        n = len(mem_allocs_sorted)
        bucket_size = max(1, n // 10)
        for i in range(0, n, bucket_size):
            bucket = mem_allocs_sorted[i : i + bucket_size]
            delta = sum(a["bytes"] for a in bucket)
            running += delta
            peak = max(peak, running)
            stage = f"Events {i + 1}-{min(i + bucket_size, n)}"
            lines.append(
                f"| {stage} | {_fmt_mb(running)} | {_fmt_mb(delta)} | {_fmt_mb(peak)} |"
            )
        lines.append("")
    else:
        lines.append("_No memory allocation events found._")
        lines.append("")

    # --- Sync Points ---
    lines.append("## Sync Points")
    lines.append("")
    sync = analysis["sync"]
    if sync:
        lines.append("| Location | Count | Total Wait (ms) |")
        lines.append("|----------|-------|-----------------|")
        sorted_sync = sorted(sync.items(), key=lambda kv: kv[1]["total_us"], reverse=True)
        for name, stats in sorted_sync:
            lines.append(
                f"| `{name}` | {stats['count']} | {_fmt_ms(stats['total_us'])} |"
            )
        lines.append("")
    else:
        lines.append("_No synchronization events found._")
        lines.append("")

    # --- Summary ---
    lines.append("## Summary")
    lines.append("")
    lines.append(f"| Metric | Value |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Total GPU Time | {_fmt_ms(analysis['total_gpu_us'])} ms |")
    lines.append(f"| Total CPU Time | {_fmt_ms(analysis['total_cpu_us'])} ms |")

    combined = total_gpu_ms + total_cpu_ms
    gpu_util = (total_gpu_ms / combined * 100) if combined > 0 else 0
    lines.append(f"| GPU Utilization | {gpu_util:.1f}% |")

    num_kernels = sum(s["calls"] for _, s in analysis["kernels"])
    lines.append(f"| Total Kernel Launches | {num_kernels:,} |")

    total_transfers = sum(s["count"] for s in memcpy.values())
    lines.append(f"| Total Transfers | {total_transfers:,} |")

    total_sync = sum(s["count"] for s in sync.values())
    lines.append(f"| Total Sync Calls | {total_sync:,} |")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def trace_to_markdown(trace_path: str, top_n: int = 20) -> str:
    """Parse a Chrome trace JSON file and return a markdown report.

    Args:
        trace_path: Path to the Chrome trace JSON file.
        top_n: Number of top kernels to display.

    Returns:
        Markdown string.
    """
    events = _load_trace(trace_path)
    analysis = analyze_trace(events, top_n=top_n)
    return _generate_markdown(analysis, top_n=top_n)


def profile_to_markdown(
    fn: Callable,
    warmup: int = 3,
    runs: int = 5,
    top_n: int = 20,
    activities: Optional[list] = None,
) -> str:
    """Profile a Python callable using torch.profiler and return markdown.

    Args:
        fn: Callable to profile (no arguments).
        warmup: Number of warmup iterations before profiling.
        runs: Number of profiled iterations.
        top_n: Number of top kernels to show.
        activities: List of torch.profiler.ProfilerActivity values.
                    Defaults to [CPU, CUDA].

    Returns:
        Markdown string.
    """
    try:
        import torch
        from torch.profiler import ProfilerActivity, profile, schedule
    except ImportError:
        raise ImportError("torch is required for profile_to_markdown()")

    if activities is None:
        activities = [ProfilerActivity.CPU, ProfilerActivity.CUDA]

    # Warmup
    for _ in range(warmup):
        fn()
        if torch.cuda.is_available():
            torch.cuda.synchronize()

    # Profile via Chrome trace export, then parse
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        trace_path = tmp.name

    try:
        with profile(
            activities=activities,
            schedule=schedule(wait=0, warmup=0, active=runs, repeat=1),
            record_shapes=True,
            profile_memory=True,
            with_stack=False,
        ) as prof:
            for _ in range(runs):
                fn()
                if torch.cuda.is_available():
                    torch.cuda.synchronize()
                prof.step()

        prof.export_chrome_trace(trace_path)
        return trace_to_markdown(trace_path, top_n=top_n)
    finally:
        try:
            os.unlink(trace_path)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _run_command_with_profiling(cmd: str, top_n: int) -> str:
    """Run a shell command that produces a trace, or wrap it with profiling.

    Strategy: write a small wrapper script that imports torch.profiler,
    executes the user command, and exports a Chrome trace to a temp file.
    Then we parse that trace.
    """
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        trace_path = tmp.name

    # Build a wrapper script that profiles the command
    wrapper = f"""\
import sys, os, subprocess, tempfile, json

trace_path = {trace_path!r}

try:
    import torch
    from torch.profiler import profile, ProfilerActivity, schedule

    has_cuda = torch.cuda.is_available()
    activities = [ProfilerActivity.CPU]
    if has_cuda:
        activities.append(ProfilerActivity.CUDA)

    # The user command might be a python -c "..." or a script
    # We execute it in a subprocess with profiling env vars,
    # but for simplicity we exec it inline if it's python -c
    user_cmd = {cmd!r}

    # If it is "python -c '...'" or "python -c \\"...\\"", extract the code
    import shlex
    parts = shlex.split(user_cmd)
    if len(parts) >= 3 and parts[0] in ("python", "python3") and parts[1] == "-c":
        code = parts[2]
        # Profile the code inline
        with profile(
            activities=activities,
            record_shapes=True,
            profile_memory=True,
            with_stack=False,
        ) as prof:
            exec(code, {{"__name__": "__main__"}})
            if has_cuda:
                torch.cuda.synchronize()
            prof.step()

        prof.export_chrome_trace(trace_path)
    else:
        # Run as subprocess — no inline profiling possible
        # Just run it and hope it generates a trace
        result = subprocess.run(user_cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Command failed: {{result.stderr}}", file=sys.stderr)
            sys.exit(1)
        # Write empty trace if nothing generated
        if not os.path.exists(trace_path) or os.path.getsize(trace_path) == 0:
            with open(trace_path, "w") as f:
                json.dump([], f)

except ImportError:
    print("torch not available, running command without profiling", file=sys.stderr)
    import subprocess
    result = subprocess.run({cmd!r}, shell=True)
    sys.exit(result.returncode)
"""

    wrapper_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".py", delete=False
        ) as wf:
            wf.write(wrapper)
            wrapper_path = wf.name

        result = subprocess.run(
            [sys.executable, wrapper_path],
            capture_output=True,
            text=True,
            timeout=600,
        )

        if result.stderr:
            print(result.stderr, file=sys.stderr)

        if os.path.exists(trace_path) and os.path.getsize(trace_path) > 0:
            return trace_to_markdown(trace_path, top_n=top_n)
        else:
            return (
                "# CUDA Profiling Report\n\n"
                "_No trace data was generated. "
                "Ensure the command uses PyTorch with CUDA._\n"
            )
    finally:
        if wrapper_path:
            try:
                os.unlink(wrapper_path)
            except OSError:
                pass
        try:
            os.unlink(trace_path)
        except OSError:
            pass


def main(argv: Optional[list[str]] = None) -> None:
    parser = argparse.ArgumentParser(
        description="Convert CUDA/PyTorch profiling data to readable markdown.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Examples:
  # Parse an existing Chrome trace
  %(prog)s --trace profile.json --output report.md --top 20

  # Profile a Python command inline
  %(prog)s --run "python -c 'import torch; x=torch.randn(1000,1000,device=\\"cuda\\"); y=x@x'" --output report.md
""",
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--trace",
        metavar="FILE",
        help="Path to Chrome trace JSON file (from torch.profiler)",
    )
    group.add_argument(
        "--run",
        metavar="CMD",
        help="Shell command to profile (wraps with torch.profiler)",
    )

    parser.add_argument(
        "--output", "-o",
        metavar="FILE",
        help="Output markdown file (default: stdout)",
    )
    parser.add_argument(
        "--top", "-n",
        type=int,
        default=20,
        metavar="N",
        help="Number of top kernels to display (default: 20)",
    )

    args = parser.parse_args(argv)

    if args.trace:
        if not os.path.isfile(args.trace):
            parser.error(f"Trace file not found: {args.trace}")
        md = trace_to_markdown(args.trace, top_n=args.top)
    else:
        md = _run_command_with_profiling(args.run, top_n=args.top)

    if args.output:
        with open(args.output, "w") as f:
            f.write(md)
        print(f"Report written to {args.output}")
    else:
        print(md)


if __name__ == "__main__":
    main()
