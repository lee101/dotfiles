#!/usr/bin/env python3
"""Convert Nsight Systems, Nsight Compute, and trtexec reports to markdown."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


NSYS_DEFAULT_REPORTS = (
    "cuda_api_sum",
    "cuda_gpu_kern_sum",
    "cuda_gpu_mem_time_sum",
    "cuda_gpu_mem_size_sum",
    "nvtx_sum",
)

NSYS_SUMMARY_METRICS = (
    "Throughput",
    "Latency",
    "Enqueue Time",
    "H2D Latency",
    "GPU Compute Time",
    "D2H Latency",
    "Total Host Walltime",
    "Total GPU Compute Time",
)

TRT_PCT_KEYS = {90: "p90", 95: "p95", 99: "p99"}


@dataclass
class TableReport:
    name: str
    headers: list[str]
    rows: list[dict[str, str]]
    skipped: str | None = None


def parse_float(value) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    match = re.search(r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", text.replace(",", ""))
    if not match:
        return None
    return float(match.group(0))


def normalize_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", key.strip().lower()).strip("_")


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    if pct <= 0:
        return min(values)
    if pct >= 100:
        return max(values)
    ordered = sorted(values)
    idx = (len(ordered) - 1) * (pct / 100.0)
    low = int(idx)
    high = min(low + 1, len(ordered) - 1)
    if low == high:
        return ordered[low]
    frac = idx - low
    return ordered[low] * (1.0 - frac) + ordered[high] * frac


def bytes_to_human(num_bytes: float) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(num_bytes)
    for unit in units:
        if abs(value) < 1024.0 or unit == units[-1]:
            return f"{value:.2f} {unit}"
        value /= 1024.0
    return f"{num_bytes:.2f} B"


def bandwidth_to_human(num_bytes: float, duration_s: float) -> str:
    if num_bytes <= 0 or duration_s <= 0:
        return "-"
    gbps = num_bytes / duration_s / 1_000_000_000.0
    return f"{gbps:.2f} GB/s"


def fmt_pct(value: float | None) -> str:
    return "-" if value is None else f"{value:.2f}%"


def fmt_ns(value: float | None) -> str:
    if value is None:
        return "-"
    if abs(value) >= 1_000_000_000:
        return f"{value / 1_000_000_000.0:.3f}s"
    if abs(value) >= 1_000_000:
        return f"{value / 1_000_000.0:.3f}ms"
    if abs(value) >= 1_000:
        return f"{value / 1_000.0:.3f}us"
    return f"{value:.0f}ns"


def _top_rows(report: TableReport, limit: int) -> list[dict[str, str]]:
    if not report.rows:
        return []
    rows = list(report.rows)

    def score(row: dict[str, str]) -> float:
        for key in ("Time (%)", "Total Time (ns)", "Total (ns)", "Metric Value"):
            value = parse_float(row.get(key))
            if value is not None:
                return float(value)
        return 0.0

    rows.sort(key=score, reverse=True)
    return rows[:limit]


def _row_label(row: dict[str, str]) -> str:
    for field in ("Name", "Operation", "Kernel Name", "Range", "Label"):
        value = row.get(field)
        if value:
            return value
    return "unknown"


def _row_total_ns(row: dict[str, str]) -> float:
    return parse_float(row.get("Total Time (ns)") or row.get("Total (ns)") or row.get("Sum (ns)")) or 0.0


def _section_name_from_processing_line(line: str) -> str | None:
    match = re.search(r"with\s+\[[^/]+/([^\]/]+?)(?:\.py)?\]\.\.\.", line)
    if match:
        return match.group(1)
    match = re.search(r"with\s+\[.*?/([^/\]]+)\.py\]\.\.\.", line)
    if match:
        return match.group(1)
    return None


def parse_nsys_stats_bundle(report_names: Iterable[str], output: str) -> dict[str, TableReport]:
    reports: dict[str, TableReport] = {}
    current_name: str | None = None
    current_lines: list[str] = []

    def flush() -> None:
        nonlocal current_name, current_lines
        if current_name is None:
            return
        reports[current_name] = _parse_csv_report(current_name, current_lines)
        current_name = None
        current_lines = []

    for line in output.splitlines():
        report_name = _section_name_from_processing_line(line)
        if report_name:
            flush()
            current_name = report_name
            continue
        if current_name is not None:
            current_lines.append(line)

    flush()
    for report_name in report_names:
        reports.setdefault(report_name, TableReport(name=report_name, headers=[], rows=[]))
    return reports


def _parse_csv_report(name: str, lines: list[str]) -> TableReport:
    body = [line for line in lines if line.strip()]
    if not body:
        return TableReport(name=name, headers=[], rows=[], skipped="empty report")
    if body[0].startswith("SKIPPED:"):
        return TableReport(name=name, headers=[], rows=[], skipped=body[0].split("SKIPPED:", 1)[1].strip())
    for index, line in enumerate(body):
        if "," in line:
            body = body[index:]
            break
    reader = csv.DictReader(body)
    rows = list(reader)
    headers = list(reader.fieldnames or [])
    return TableReport(name=name, headers=headers, rows=rows)


def _nsys_total(report: TableReport, *keys: str) -> float:
    total = 0.0
    for row in report.rows:
        for key in keys:
            value = parse_float(row.get(key))
            if value is not None:
                total += float(value)
                break
    return total


def _nsys_summary_lines(reports: dict[str, TableReport]) -> list[str]:
    lines: list[str] = []
    api = reports.get("cuda_api_sum", TableReport("cuda_api_sum", [], []))
    kernels = reports.get("cuda_gpu_kern_sum", TableReport("cuda_gpu_kern_sum", [], []))
    mem_time = reports.get("cuda_gpu_mem_time_sum", TableReport("cuda_gpu_mem_time_sum", [], []))
    mem_size = reports.get("cuda_gpu_mem_size_sum", TableReport("cuda_gpu_mem_size_sum", [], []))
    nvtx = reports.get("nvtx_sum", TableReport("nvtx_sum", [], []))

    if api.rows:
        top_api = _top_rows(api, 1)[0]
        api_name = _row_label(top_api)
        lines.append(f"- Hottest CUDA API: `{api_name}` at {fmt_pct(parse_float(top_api.get('Time (%)')))}.")
        lines.append(f"- CUDA API total time: {fmt_ns(_nsys_total(api, 'Total Time (ns)', 'Total (ns)'))}.")
    else:
        lines.append("- CUDA API summary: unavailable.")

    if kernels.rows:
        top_kernel = _top_rows(kernels, 1)[0]
        kernel_name = _row_label(top_kernel)
        lines.append(f"- Hottest kernel: `{kernel_name}` at {fmt_pct(parse_float(top_kernel.get('Time (%)')))}.")
        lines.append(f"- GPU kernel time: {fmt_ns(_nsys_total(kernels, 'Total Time (ns)', 'Total (ns)'))}.")
    else:
        lines.append("- GPU kernel summary: no kernels captured.")

    if mem_time.rows:
        top_mem = _top_rows(mem_time, 1)[0]
        mem_name = _row_label(top_mem)
        lines.append(f"- Hottest transfer: `{mem_name}` at {fmt_pct(parse_float(top_mem.get('Time (%)')))}.")
        lines.append(f"- Device transfer time: {fmt_ns(_nsys_total(mem_time, 'Total Time (ns)', 'Total (ns)'))}.")
    else:
        lines.append("- Device transfer summary: unavailable.")

    if mem_size.rows:
        transfer_bytes = _nsys_total(mem_size, "Total Size (bytes)", "Total Bytes", "Bytes")
        if transfer_bytes > 0:
            lines.append(f"- Total transfer volume: {bytes_to_human(transfer_bytes)}.")

    if nvtx.rows:
        top_nvtx = _top_rows(nvtx, 1)[0]
        lines.append(f"- Hottest NVTX range: `{_row_label(top_nvtx)}` at {fmt_pct(parse_float(top_nvtx.get('Time (%)')))}.")
        lines.append(f"- NVTX range time: {fmt_ns(_nsys_total(nvtx, 'Total Time (ns)', 'Total (ns)', 'Sum (ns)'))}.")

    return lines


def _nsys_recommendations(reports: dict[str, TableReport]) -> list[str]:
    recs: list[str] = []
    api = reports.get("cuda_api_sum", TableReport("cuda_api_sum", [], []))
    kernels = reports.get("cuda_gpu_kern_sum", TableReport("cuda_gpu_kern_sum", [], []))
    mem_time = reports.get("cuda_gpu_mem_time_sum", TableReport("cuda_gpu_mem_time_sum", [], []))
    nvtx = reports.get("nvtx_sum", TableReport("nvtx_sum", [], []))

    if api.rows:
        top_api = _top_rows(api, 1)[0]
        api_name = (top_api.get("Name") or top_api.get("Operation") or "").lower()
        api_pct = parse_float(top_api.get("Time (%)")) or 0.0
        if "cudamalloc" in api_name and api_pct >= 20.0:
            recs.append("Reuse device buffers or preallocate a persistent workspace so allocation overhead does not dominate.")
        if "memcpy" in api_name:
            recs.append("Reduce host/device transfers or keep tensors resident on device.")

    if not kernels.rows:
        recs.append("No GPU kernels were captured. Verify the profiled path is actually reaching CUDA work.")

    if kernels.rows and mem_time.rows:
        kernel_ns = _nsys_total(kernels, "Total Time (ns)", "Total (ns)")
        mem_ns = _nsys_total(mem_time, "Total Time (ns)", "Total (ns)")
        if mem_ns > kernel_ns * 1.2:
            recs.append("Transfer time exceeds kernel time. Focus on batching, overlap, and memory residency before kernel micro-optimizations.")
        elif kernel_ns > mem_ns * 1.2:
            recs.append("Kernel time dominates. Profile launch shape, occupancy, and math throughput next.")

    if nvtx.rows:
        top_nvtx = _top_rows(nvtx, 1)[0]
        if _row_total_ns(top_nvtx) > _nsys_total(nvtx, "Total Time (ns)", "Total (ns)", "Sum (ns)") * 0.5:
            recs.append(f"One NVTX range, `{_row_label(top_nvtx)}`, dominates the traced stage. Split it into finer-grained markers before tuning internals.")

    if not recs:
        recs.append("No single bottleneck dominated this run. Compare against a second profile or add hardware metrics.")

    deduped: list[str] = []
    for item in recs:
        if item not in deduped:
            deduped.append(item)
    return deduped[:4]


def _nsys_bottleneck_rows(reports: dict[str, TableReport]) -> list[list[str]]:
    candidates: list[tuple[float, str, str, str, str, str]] = []

    for key, area in (
        ("cuda_api_sum", "CUDA API"),
        ("cuda_gpu_kern_sum", "GPU Kernel"),
        ("cuda_gpu_mem_time_sum", "Transfer"),
        ("nvtx_sum", "NVTX"),
    ):
        report = reports.get(key, TableReport(key, [], []))
        if not report.rows:
            continue
        top = _top_rows(report, 1)[0]
        total_ns = _row_total_ns(top)
        if total_ns <= 0:
            continue
        count = top.get("Num Calls") or top.get("Instances") or top.get("Count") or "?"
        candidates.append(
            (
                total_ns,
                area,
                _row_label(top),
                fmt_ns(total_ns),
                fmt_pct(parse_float(top.get("Time (%)"))),
                str(count),
            )
        )

    candidates.sort(key=lambda item: item[0], reverse=True)
    rows: list[list[str]] = []
    for idx, (_, area, name, total, pct, count) in enumerate(candidates, 1):
        rows.append([str(idx), area, name, total, pct, count])
    return rows


def _nsys_range_table(report: TableReport, top_n: int) -> list[str]:
    if not report.rows:
        if report.skipped:
            return [f"No data. `{report.skipped}`"]
        return ["No data."]
    rows = []
    for row in _top_rows(report, top_n):
        rows.append(
            [
                _row_label(row),
                row.get("Style", "?"),
                row.get("Instances", "?"),
                fmt_pct(parse_float(row.get("Time (%)"))),
                fmt_ns(_row_total_ns(row)),
                fmt_ns(parse_float(row.get("Avg (ns)"))),
            ]
        )
    return _render_table(["Range", "Style", "Instances", "Time %", "Total", "Avg"], rows)


def analyze_nsys_report(
    report_path: Path,
    *,
    nsys_bin: str,
    report_names: Iterable[str] = NSYS_DEFAULT_REPORTS,
) -> tuple[dict[str, TableReport], str]:
    cmd = [
        nsys_bin,
        "stats",
        "--force-export=true",
        "--format",
        "csv",
        "--report",
        ",".join(report_names),
        str(report_path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode not in (0,):
        output = (proc.stdout or "") + (proc.stderr or "")
    else:
        output = (proc.stdout or "") + (proc.stderr or "")
    return _parse_nsys_report(output, report_names), output


def _ncu_parse_csv_blocks(text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    lines = text.splitlines()
    current: list[str] = []
    seen_header = False

    def flush() -> None:
        nonlocal current, seen_header
        if not current:
            return
        reader = csv.DictReader(current)
        rows.extend(list(reader))
        current = []
        seen_header = False

    for line in lines:
        stripped = line.strip()
        if not stripped:
            if seen_header:
                flush()
            continue
        if stripped.startswith("==PROF==") or stripped.startswith("==WARNING=="):
            continue
        if (stripped.startswith("ID,") or "Kernel Name" in stripped or "Metric Name" in stripped) and "," in stripped:
            if current:
                flush()
            current = [stripped]
            seen_header = True
            continue
        if current:
            current.append(stripped)

    flush()
    return rows


def _ncu_metric_lookup(metrics: dict[str, float], *needles: str) -> float | None:
    lowered = {normalize_key(key): value for key, value in metrics.items()}
    for needle in needles:
        needle_norm = normalize_key(needle)
        for key, value in lowered.items():
            if needle_norm in key:
                return value
    return None


def _normalize_ncu_rows(rows: list[dict[str, str]]) -> dict[str, dict[str, object]]:
    kernels: dict[str, dict[str, object]] = {}
    for row in rows:
        norm = {normalize_key(key): value for key, value in row.items() if key is not None}
        kernel_name = (
            row.get("Kernel Name")
            or row.get("Kernel")
            or row.get("kernel_name")
            or row.get("name")
            or "unknown"
        )
        kernel = kernels.setdefault(
            kernel_name,
            {
                "metrics": {},
                "rows": [],
                "duration_s": 0.0,
                "launch_count": 0,
            },
        )
        kernel["launch_count"] = int(kernel["launch_count"]) + 1
        kernel["rows"].append(norm)
        metric_name = row.get("Metric Name") or norm.get("metric_name") or norm.get("metric")
        metric_value = parse_float(row.get("Metric Value") or norm.get("metric_value"))
        if metric_name and metric_value is not None:
            kernel["metrics"][str(metric_name)] = float(metric_value)
        for key in ("duration_s", "time_s", "gpu_time_s"):
            value = parse_float(norm.get(key))
            if value is not None:
                kernel["duration_s"] = max(float(kernel["duration_s"]), float(value))
        for key in ("duration_ms", "time_ms", "gpu_time_ms", "kernel_time_ms"):
            value = parse_float(norm.get(key))
            if value is not None:
                kernel["duration_s"] = max(float(kernel["duration_s"]), float(value) / 1000.0)
        for key in ("duration_ns", "time_ns", "gpu_time_ns", "kernel_time_ns", "kernel_time", "time", "duration"):
            value = parse_float(norm.get(key))
            if value is not None:
                if key.endswith("_ns"):
                    kernel["duration_s"] = max(float(kernel["duration_s"]), value / 1_000_000_000.0)
                elif key.endswith("_us"):
                    kernel["duration_s"] = max(float(kernel["duration_s"]), value / 1_000_000.0)
                elif key.endswith("_ms"):
                    kernel["duration_s"] = max(float(kernel["duration_s"]), value / 1000.0)
                else:
                    kernel["duration_s"] = max(float(kernel["duration_s"]), value)
    return kernels


def analyze_ncu_report(report_path: Path, *, ncu_bin: str) -> tuple[dict[str, dict[str, object]], str]:
    cmd = [
        ncu_bin,
        "--import",
        str(report_path),
        "--csv",
        "--page",
        "raw",
        "--print-units",
        "base",
        "--print-summary",
        "per-kernel",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    output = (proc.stdout or "") + (proc.stderr or "")
    rows = _ncu_parse_csv_blocks(output)
    return _normalize_ncu_rows(rows), output


def _ncu_metrics_table(kernels: dict[str, dict[str, object]], top_n: int) -> list[str]:
    rows = sorted(kernels.items(), key=lambda item: float(item[1].get("duration_s", 0.0)), reverse=True)
    rows = rows[:top_n]
    if not rows:
        return ["No kernel metrics available."]

    lines = [
        "| Kernel | Launches | SM % | Mem % | Occupancy % | DRAM % | Regs / Thread | Shared Mem | Duration |",
        "|--------|----------|------|-------|-------------|--------|---------------|------------|----------|",
    ]
    for kernel_name, payload in rows:
        metrics = payload.get("metrics", {})
        assert isinstance(metrics, dict)
        sm = _ncu_metric_lookup(metrics, "sm__throughput.avg.pct_of_peak_sustained_elapsed", "sm_throughput", "sm_efficiency")
        mem = _ncu_metric_lookup(metrics, "gpu__compute_memory_throughput.avg.pct_of_peak_sustained_elapsed", "dram__throughput.avg.pct_of_peak_sustained_elapsed", "memory_throughput")
        occ = _ncu_metric_lookup(metrics, "sm__warps_active.avg.pct_of_peak_sustained_active", "achieved_occupancy", "occupancy")
        dram = _ncu_metric_lookup(metrics, "dram__throughput.avg.pct_of_peak_sustained_elapsed", "dram_throughput")
        regs = _ncu_metric_lookup(metrics, "launch__registers_per_thread", "registers_per_thread")
        smem = _ncu_metric_lookup(metrics, "launch__shared_mem_config_size", "shared_mem_config_size")
        duration_s = float(payload.get("duration_s", 0.0))
        lines.append(
            f"| `{kernel_name[:60]}` | {int(payload.get('launch_count', 0))} | {fmt_pct(sm)} | {fmt_pct(mem)} | "
            f"{fmt_pct(occ)} | {fmt_pct(dram)} | {regs if regs is not None else '-'} | {smem if smem is not None else '-'} | {duration_s:.6f}s |"
        )
    return lines


def _ncu_summary_lines(kernels: dict[str, dict[str, object]]) -> list[str]:
    if not kernels:
        return ["- No kernels were parsed."]

    unique_metrics: set[str] = set()
    attention_kernels: list[str] = []
    for kernel_name, payload in kernels.items():
        metrics = payload.get("metrics", {})
        if isinstance(metrics, dict):
            unique_metrics.update(metrics.keys())
        if "attention" in kernel_name.lower():
            attention_kernels.append(kernel_name)

    lines = [
        f"- Kernels analyzed: {len(kernels)}",
        f"- Unique metrics captured: {len(unique_metrics)}",
    ]
    if attention_kernels:
        lines.append(f"- Attention kernels: {', '.join(f'`{name}`' for name in attention_kernels[:5])}")
    return lines


def _trtexec_metric_block(body: str) -> dict[str, float]:
    values: dict[str, float] = {}
    if "qps" in body.lower():
        throughput = parse_float(body)
        if throughput is not None:
            values["throughput_qps"] = throughput
        return values
    for part in body.split(","):
        chunk = part.strip()
        if "=" not in chunk:
            continue
        key, raw_value = [piece.strip() for piece in chunk.split("=", 1)]
        value = parse_float(raw_value)
        if value is None:
            continue
        lowered = key.lower().replace(" ", "_")
        percent_match = re.match(r"percentile\((\d+)%\)", lowered)
        if percent_match:
            values[f"p{percent_match.group(1)}"] = value
        elif lowered in {"min", "max", "mean", "median"}:
            values[lowered] = value
        else:
            values[normalize_key(key)] = value
    return values


def parse_trtexec_log(text: str) -> dict[str, object]:
    summary: dict[str, dict[str, float]] = {}
    layer_rows: list[dict[str, object]] = []
    notes: list[str] = []

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if "=== Performance summary ===" in line:
            continue
        if "dumpProfile" in line or "dumpLayerInfo" in line:
            continue

        summary_match = re.search(
            r"\[TRT\]\s*(Throughput|Latency|Enqueue Time|H2D Latency|GPU Compute Time|D2H Latency|Total Host Walltime|Total GPU Compute Time):\s*(.+)$",
            line,
        )
        if summary_match:
            summary[summary_match.group(1)] = _trtexec_metric_block(summary_match.group(2))
            continue

        if "ms" in line and "[TRT]" in line and not any(metric in line for metric in NSYS_SUMMARY_METRICS):
            stripped = re.sub(r"^.*?\[TRT\]\s*", "", line).strip()
            if "|" in stripped:
                pieces = [piece.strip() for piece in stripped.split("|") if piece.strip()]
                numeric = [value for value in (parse_float(piece) for piece in pieces) if value is not None]
                if numeric:
                    layer_rows.append(
                        {
                            "name": pieces[0],
                            "time_ms": numeric[-1],
                            "raw": stripped,
                        }
                    )
                    continue
            match = re.search(r"(.+?)\s+([0-9]+(?:\.[0-9]+)?)\s*ms(?:\s|$)", stripped)
            if match:
                name = match.group(1).strip(" -:\t")
                time_ms = float(match.group(2))
                layer_rows.append({"name": name, "time_ms": time_ms, "raw": stripped})
                continue

        if "[TRT]" in line and any(token in line for token in ("warn", "error", "fail", "skip")):
            notes.append(line)

    return {"summary": summary, "layers": layer_rows, "notes": notes}


def _trtexec_summary_lines(data: dict[str, object]) -> list[str]:
    summary = data.get("summary", {})
    if not isinstance(summary, dict):
        return ["- No performance summary parsed."]

    throughput = summary.get("Throughput", {})
    latency = summary.get("Latency", {})
    enqueue = summary.get("Enqueue Time", {})
    h2d = summary.get("H2D Latency", {})
    gpu = summary.get("GPU Compute Time", {})
    d2h = summary.get("D2H Latency", {})
    host = summary.get("Total Host Walltime", {})
    gpu_total = summary.get("Total GPU Compute Time", {})

    lines = []
    if isinstance(throughput, dict) and throughput.get("throughput_qps") is not None:
        lines.append(f"- Throughput: {throughput['throughput_qps']:.2f} qps")
    if isinstance(latency, dict) and latency:
        lines.append(
            "- Latency: "
            + ", ".join(
                f"{key}={value:.3f} ms" for key, value in latency.items() if key in {"min", "max", "mean", "median", "p90", "p95", "p99"}
            )
        )
    for label, block in (
        ("Enqueue Time", enqueue),
        ("H2D Latency", h2d),
        ("GPU Compute Time", gpu),
        ("D2H Latency", d2h),
        ("Total Host Walltime", host),
        ("Total GPU Compute Time", gpu_total),
    ):
        if isinstance(block, dict) and block:
            parts = []
            for key in ("min", "max", "mean", "median", "p90", "p95", "p99"):
                if key in block:
                    parts.append(f"{key}={block[key]:.3f} ms")
            if "throughput_qps" in block:
                parts.append(f"{block['throughput_qps']:.2f} qps")
            if parts:
                lines.append(f"- {label}: " + ", ".join(parts))

    return lines or ["- No performance summary parsed."]


def _trtexec_recommendations(data: dict[str, object]) -> list[str]:
    summary = data.get("summary", {})
    layers = data.get("layers", [])
    recs: list[str] = []

    if isinstance(summary, dict):
        enqueue = summary.get("Enqueue Time", {})
        gpu = summary.get("GPU Compute Time", {})
        h2d = summary.get("H2D Latency", {})
        d2h = summary.get("D2H Latency", {})
        if isinstance(enqueue, dict) and isinstance(gpu, dict):
            enqueue_mean = enqueue.get("mean")
            gpu_mean = gpu.get("mean")
            if isinstance(enqueue_mean, (int, float)) and isinstance(gpu_mean, (int, float)) and enqueue_mean > gpu_mean:
                recs.append("Enqueue time exceeds GPU compute time. CUDA Graphs or less host-side work may help.")
        if isinstance(h2d, dict) and isinstance(d2h, dict):
            transfer_sum = float(h2d.get("mean", 0.0) or 0.0) + float(d2h.get("mean", 0.0) or 0.0)
            gpu_mean = float(gpu.get("mean", 0.0) or 0.0) if isinstance(gpu, dict) else 0.0
            if transfer_sum > gpu_mean and gpu_mean > 0:
                recs.append("Host/device transfer time is comparable to or larger than GPU compute time. Consider `--noDataTransfers` or keeping tensors resident on device.")

    if isinstance(layers, list) and layers:
        top_layer = max(layers, key=lambda row: float(row.get("time_ms", 0.0)))
        if float(top_layer.get("time_ms", 0.0)) > 0:
            recs.append(f"Top layer: `{top_layer.get('name', 'unknown')}` at {float(top_layer.get('time_ms', 0.0)):.3f} ms.")

    if not recs:
        recs.append("No single bottleneck dominated this run. Compare against a second profile or collect layer-level output with `--dumpProfile` and `--dumpLayerInfo`.")

    deduped: list[str] = []
    for item in recs:
        if item not in deduped:
            deduped.append(item)
    return deduped[:4]


def analyze_trtexec_log(log_path: Path) -> dict[str, object]:
    return parse_trtexec_log(log_path.read_text())


def _render_table(headers: list[str], rows: list[list[str]]) -> str:
    if not headers:
        return "No data."
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def render_nsys_markdown(
    report_path: Path,
    reports: dict[str, TableReport],
    *,
    command: str | None = None,
) -> str:
    api = reports.get("cuda_api_sum", TableReport("cuda_api_sum", [], []))
    kernels = reports.get("cuda_gpu_kern_sum", TableReport("cuda_gpu_kern_sum", [], []))
    mem_time = reports.get("cuda_gpu_mem_time_sum", TableReport("cuda_gpu_mem_time_sum", [], []))
    mem_size = reports.get("cuda_gpu_mem_size_sum", TableReport("cuda_gpu_mem_size_sum", [], []))
    nvtx = reports.get("nvtx_sum", TableReport("nvtx_sum", [], []))

    lines = [
        f"# Nsight Systems Report: {report_path.name}",
        "",
        "## Summary",
        "",
        f"- Source: `{report_path}`",
        f"- Report sections: `{', '.join(reports.keys())}`",
    ]
    if command:
        lines.append(f"- Command: `{command}`")
    lines.extend(["", "## Executive Summary", ""])
    lines.extend(_nsys_summary_lines(reports))
    lines.extend(["", "## Recommendations", ""])
    for rec in _nsys_recommendations(reports):
        lines.append(f"- {rec}")

    bottlenecks = _nsys_bottleneck_rows(reports)
    if bottlenecks:
        lines.extend(["", "## Bottleneck Ranking", ""])
        lines.append(_render_table(["Rank", "Area", "Item", "Total", "Time %", "Count"], bottlenecks))

    if api.rows:
        lines.extend(["", "## CUDA API Hotspots", ""])
        api_rows = []
        for row in _top_rows(api, 10):
            api_rows.append(
                [
                    row.get("Name") or row.get("Operation") or "unknown",
                    row.get("Num Calls", row.get("Instances", "?")),
                    fmt_pct(parse_float(row.get("Time (%)"))),
                    fmt_ns(parse_float(row.get("Total Time (ns)"))),
                    fmt_ns(parse_float(row.get("Avg (ns)"))),
                ]
            )
        lines.append(_render_table(["API", "Calls", "Time %", "Total", "Avg"], api_rows))
    if kernels.rows:
        lines.extend(["", "## GPU Kernels", ""])
        kernel_rows = []
        for row in _top_rows(kernels, 10):
            kernel_rows.append(
                [
                    row.get("Name") or row.get("Kernel Name") or row.get("Operation") or "unknown",
                    row.get("Instances", row.get("Num Calls", "?")),
                    fmt_pct(parse_float(row.get("Time (%)"))),
                    fmt_ns(parse_float(row.get("Total Time (ns)") or row.get("Total (ns)"))),
                    fmt_ns(parse_float(row.get("Avg (ns)"))),
                ]
            )
        lines.append(_render_table(["Kernel", "Instances", "Time %", "Total", "Avg"], kernel_rows))
    if mem_time.rows:
        lines.extend(["", "## Device Transfers", ""])
        transfer_rows = []
        size_index: dict[str, dict[str, str]] = {}
        for row in mem_size.rows:
            key = _row_label(row)
            if key:
                size_index[key] = row
        for row in _top_rows(mem_time, 10):
            name = _row_label(row)
            size_row = size_index.get(name, {})
            size_value = parse_float(
                size_row.get("Total Size (bytes)")
                or size_row.get("Size (bytes)")
                or size_row.get("Total Bytes")
                or size_row.get("Bytes")
            )
            transfer_rows.append(
                [
                    name,
                    row.get("Count", row.get("Instances", row.get("Num Calls", "?"))),
                    fmt_ns(parse_float(row.get("Total Time (ns)") or row.get("Total (ns)"))),
                    bytes_to_human(size_value) if size_value is not None else "-",
                ]
            )
        lines.append(_render_table(["Operation", "Count", "Total Time", "Total Size"], transfer_rows))

    if nvtx.rows:
        lines.extend(["", "## NVTX Ranges", ""])
        lines.append(_nsys_range_table(nvtx, 10))

    return "\n".join(lines) + "\n"


def render_ncu_markdown(report_path: Path, kernels: dict[str, dict[str, object]], *, command: str | None = None) -> str:
    lines = [
        f"# Nsight Compute Report: {report_path.name}",
        "",
        "## Summary",
        "",
        f"- Source: `{report_path}`",
    ]
    if command:
        lines.append(f"- Command: `{command}`")
    lines.extend(["", "## Executive Summary", ""])
    lines.extend(_ncu_summary_lines(kernels))
    lines.extend(["", "## Kernel Metrics", ""])
    lines.extend(_ncu_metrics_table(kernels, top_n=20))

    return "\n".join(lines) + "\n"


def render_trtexec_markdown(report_path: Path, data: dict[str, object], *, command: str | None = None) -> str:
    layers = data.get("layers", [])
    lines = [
        f"# TensorRT trtexec Report: {report_path.name}",
        "",
        "## Summary",
        "",
        f"- Source: `{report_path}`",
    ]
    if command:
        lines.append(f"- Command: `{command}`")
    lines.extend(["", "## Performance Summary", ""])
    lines.extend(_trtexec_summary_lines(data))
    if isinstance(layers, list) and layers:
        lines.extend(["", "## Per-Layer Runtime", ""])
        layer_rows = []
        for row in sorted(layers, key=lambda item: float(item.get("time_ms", 0.0)), reverse=True)[:20]:
            layer_rows.append(
                [
                    str(row.get("name", "unknown")),
                    f"{float(row.get('time_ms', 0.0)):.3f}",
                ]
            )
        lines.append(_render_table(["Layer", "Time (ms)"], layer_rows))
    lines.extend(["", "## Recommendations", ""])
    for rec in _trtexec_recommendations(data):
        lines.append(f"- {rec}")
    if isinstance(data.get("notes"), list) and data["notes"]:
        lines.extend(["", "## Notes", ""])
        for note in data["notes"]:
            lines.append(f"- {note}")
    return "\n".join(lines) + "\n"


def detect_kind(input_path: Path, explicit_kind: str | None = None) -> str:
    if explicit_kind and explicit_kind != "auto":
        return explicit_kind
    suffix = input_path.suffix.lower()
    if suffix in {".nsys-rep", ".sqlite"}:
        return "nsys"
    if suffix in {".ncu-rep", ".ncu"}:
        return "ncu"
    if suffix in {".log", ".txt"}:
        if input_path.exists():
            text = input_path.read_text(errors="ignore")
            if "=== Performance summary ===" in text or "Total GPU Compute Time" in text or "Throughput:" in text:
                return "trtexec"
            if "Kernel Name" in text and "Metric Name" in text:
                return "ncu"
        return "trtexec"
    if suffix == ".csv":
        if input_path.exists():
            text = input_path.read_text(errors="ignore")
            if "Metric Name" in text and "Kernel Name" in text:
                return "ncu"
            if "Time (%),Total Time (ns)" in text:
                return "nsys"
    return "nsys"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="profile-md",
        description="Convert Nsight Systems, Nsight Compute, and trtexec outputs to markdown.",
    )
    parser.add_argument("input_file", type=Path, help="Input report/log file to analyze")
    parser.add_argument("--out", type=Path, default=None, help="Output markdown file (default: stdout)")
    parser.add_argument("--kind", choices=["auto", "nsys", "ncu", "trtexec"], default="auto", help="Force a parser kind")
    parser.add_argument("--nsys", default="nsys", help="Path to the nsys binary")
    parser.add_argument("--ncu", default="ncu", help="Path to the ncu binary")
    parser.add_argument("--top", type=int, default=20, help="How many rows to include in each table")
    parser.add_argument(
        "--report",
        action="append",
        default=[],
        help="Nsight Systems report sections to request when analyzing .nsys-rep/.sqlite files",
    )
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(list(argv) if argv is not None else None)
    input_path = args.input_file
    kind = detect_kind(input_path, args.kind)
    command = None

    if kind == "nsys":
        report_names = tuple(args.report or NSYS_DEFAULT_REPORTS)
        reports, _output = analyze_nsys_report(input_path, nsys_bin=args.nsys, report_names=report_names)
        markdown = render_nsys_markdown(input_path, reports, command=command)
    elif kind == "ncu":
        kernels, _output = analyze_ncu_report(input_path, ncu_bin=args.ncu)
        markdown = render_ncu_markdown(input_path, kernels, command=command)
    elif kind == "trtexec":
        data = analyze_trtexec_log(input_path)
        markdown = render_trtexec_markdown(input_path, data, command=command)
    else:
        raise SystemExit(f"Unsupported profile kind: {kind}")

    if args.out:
        args.out.write_text(markdown)
        print(f"Wrote markdown report to {args.out}")
    else:
        sys.stdout.write(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
