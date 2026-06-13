#!/usr/bin/env python3
"""Convert flamegraphs, profiles, traces, and perf logs to markdown."""

from __future__ import annotations

import csv
import json
import os
import re
import statistics
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Dict, List
import xml.etree.ElementTree as ET

import click


SVG_NS = {"svg": "http://www.w3.org/2000/svg", "xlink": "http://www.w3.org/1999/xlink"}


def percentile(values: List[float], pct: float) -> float:
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


def parse_float(value) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    text = text.replace(",", "")
    match = re.search(r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", text)
    if not match:
        return None
    return float(match.group(0))


def normalize_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", key.strip().lower()).strip("_")


def classify_workload(name: str, category: str = "") -> str:
    text = f"{name} {category}".lower()
    if any(token in text for token in ("memcpy hto d", "memcpy h2d", "htod", "host to device", "[cuda memcpy hto d]")):
        return "Memcpy HtoD"
    if any(token in text for token in ("memcpy dto h", "memcpy d2h", "dtoh", "device to host", "[cuda memcpy dto h]")):
        return "Memcpy DtoH"
    if any(token in text for token in ("memcpy dto d", "memcpy d2d", "dtod", "device to device", "[cuda memcpy dto d]")):
        return "Memcpy DtoD"
    if "memcpy" in text:
        return "Memcpy Other"
    if "memset" in text:
        return "Memset"
    if any(token in text for token in ("kernel", "cuda launch", "gpu", "sm ", "compute")):
        return "GPU Compute"
    if any(token in text for token in ("cuda api", "runtime api", "driver api", "cpu")):
        return "CPU Runtime"
    if any(token in text for token in ("sync", "synchronize", "wait", "barrier")):
        return "Synchronization"
    return "Other"


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


class FlamegraphParser:
    """Parse SVG flamegraph files, including Graphviz SVG emitted by go tool pprof."""

    def __init__(self, svg_path: Path):
        self.svg_path = svg_path

    def parse(self) -> List[Dict]:
        tree = ET.parse(self.svg_path)
        root = tree.getroot()
        frames: List[Dict] = []

        for g in root.findall(".//svg:g", SVG_NS):
            cls = g.get("class")
            if cls == "func_g":
                frame = self._extract_func_g_frame(g)
                if frame:
                    frames.append(frame)
            elif cls == "node":
                frame = self._extract_graphviz_frame(g)
                if frame:
                    frames.append(frame)

        total_time = max((f.get("time_s", 0.0) for f in frames), default=0.0)
        for frame in frames:
            if total_time > 0 and "percentage" not in frame:
                frame["percentage"] = frame.get("time_s", 0.0) / total_time * 100.0

        frames.sort(key=lambda item: item.get("time_s", 0.0), reverse=True)
        return frames

    def _extract_func_g_frame(self, g) -> Dict | None:
        title_elem = g.find("svg:title", SVG_NS)
        if title_elem is None or not title_elem.text:
            return None
        frame = self._parse_generic_title(title_elem.text)
        rect = g.find("svg:rect", SVG_NS)
        if rect is not None:
            frame["width"] = float(rect.get("width", 0) or 0)
            frame["x"] = float(rect.get("x", 0) or 0)
        return frame if frame.get("function") else None

    def _extract_graphviz_frame(self, g) -> Dict | None:
        anchor = g.find("svg:g/svg:a", SVG_NS)
        if anchor is None:
            return None
        title = anchor.get(f"{{{SVG_NS['xlink']}}}title") or anchor.get("title")
        if not title:
            return None
        frame = self._parse_graphviz_title(title)
        if not frame.get("function") or frame["function"].startswith("File: "):
            return None
        return frame

    def _parse_generic_title(self, title: str) -> Dict:
        info: Dict[str, object] = {"raw_title": title}
        lines = [line.strip() for line in title.strip().splitlines() if line.strip()]
        if not lines:
            return info

        info["function"] = lines[0]
        percent_match = re.search(r"(\d+(?:\.\d+)?)%", title)
        if percent_match:
            info["percentage"] = float(percent_match.group(1))
        time_match = re.search(r"(\d+(?:\.\d+)?)(ms|s)\b", title)
        if time_match:
            value = float(time_match.group(1))
            info["time_s"] = value / 1000.0 if time_match.group(2) == "ms" else value
        sample_match = re.search(r"([\d,]+)\s+samples", title)
        if sample_match:
            info["samples"] = sample_match.group(1).replace(",", "")
        return info

    def _parse_graphviz_title(self, title: str) -> Dict:
        info: Dict[str, object] = {"raw_title": title}
        match = re.match(r"(.+?)\s+\((\d+(?:\.\d+)?)s\)$", title.strip())
        if match:
            info["function"] = match.group(1).strip()
            info["time_s"] = float(match.group(2))
            return info
        info["function"] = title.strip()
        return info


class ProfileParser:
    """Parse Python profile files or text profile output."""

    def __init__(self, profile_path: Path):
        self.profile_path = profile_path

    def parse(self) -> List[Dict]:
        import pstats

        try:
            stats = pstats.Stats(str(self.profile_path))
            stats.strip_dirs()
            stats.calc_callees()
        except Exception:
            return self._parse_text_profile()

        profile_data = []
        for func, (cc, nc, tt, ct, callers) in stats.stats.items():
            filename, line, func_name = func
            profile_data.append(
                {
                    "function": f"{func_name} ({filename}:{line})",
                    "filename": filename,
                    "line": line,
                    "func_name": func_name,
                    "ncalls": nc,
                    "tottime": tt,
                    "percall": tt / nc if nc > 0 else 0,
                    "cumtime": ct,
                    "percall_cum": ct / nc if nc > 0 else 0,
                    "location": f"{filename}:{line}",
                }
            )

        return self._add_percentages(profile_data, key="cumtime")

    def _parse_text_profile(self) -> List[Dict]:
        profile_data = []
        content = self.profile_path.read_text()
        for line in content.strip().splitlines():
            match = re.match(r"\s*(\d+\.?\d*)\s+(\d+\.?\d*)\s+(\d+\.?\d*)\s+(\d+\.?\d*)\s+(.+)", line)
            if not match:
                continue
            cumtime, tottime, percall, percall_cum, func_info = match.groups()
            profile_data.append(
                {
                    "function": func_info.strip(),
                    "cumtime": float(cumtime),
                    "tottime": float(tottime),
                    "percall": float(percall),
                    "percall_cum": float(percall_cum),
                }
            )
        return self._add_percentages(profile_data, key="cumtime")

    def _add_percentages(self, data: List[Dict], key: str) -> List[Dict]:
        data.sort(key=lambda x: x.get(key, 0), reverse=True)
        total = sum(item.get(key, 0) for item in data)
        for item in data:
            item["percentage"] = item.get(key, 0) / total * 100 if total > 0 else 0
        return data


class GoPprofParser:
    """Parse Go CPU profiles by shelling out to go tool pprof -top."""

    TOP_RE = re.compile(
        r"^\s*(\d+(?:\.\d+)?(?:ms|s))\s+(\d+(?:\.\d+)?)%\s+(\d+(?:\.\d+)?)%\s+"
        r"(\d+(?:\.\d+)?(?:ms|s))\s+(\d+(?:\.\d+)?)%\s+(.+)$"
    )

    def __init__(self, profile_path: Path):
        self.profile_path = profile_path

    def parse(self) -> Dict:
        output = subprocess.run(
            ["go", "tool", "pprof", "-top", "-nodecount=200", str(self.profile_path)],
            check=True,
            capture_output=True,
            text=True,
        ).stdout

        lines = output.splitlines()
        total_samples_s = 0.0
        total_duration_s = 0.0
        entries = []

        for line in lines:
            total_match = re.search(r"Duration:\s*([\d.]+)s,\s*Total samples =\s*([\d.]+)s", line)
            if total_match:
                total_duration_s = float(total_match.group(1))
                total_samples_s = float(total_match.group(2))
                continue

            match = self.TOP_RE.match(line)
            if not match:
                continue
            flat, flat_pct, sum_pct, cum, cum_pct, function = match.groups()
            entries.append(
                {
                    "function": function.strip(),
                    "flat_s": self._parse_time_to_seconds(flat),
                    "flat_pct": float(flat_pct),
                    "sum_pct": float(sum_pct),
                    "cum_s": self._parse_time_to_seconds(cum),
                    "cum_pct": float(cum_pct),
                }
            )

        return {
            "duration_s": total_duration_s,
            "total_samples_s": total_samples_s,
            "entries": entries,
        }

    def _parse_time_to_seconds(self, value: str) -> float:
        if value.endswith("ms"):
            return float(value[:-2]) / 1000.0
        if value.endswith("s"):
            return float(value[:-1])
        return float(value)


class PerfCSVParser:
    """Parse harness CSV logs and compute steady-state summaries."""

    FLOAT_FIELDS = {
        "fps",
        "frame_max_ms",
        "frame_p99_ms",
        "update_max_ms",
        "draw_max_ms",
        "heap_alloc",
        "heap_inuse",
        "pause_total_ns",
        "pause_delta_ns",
        "last_pause_ns",
        "gc_cpu_fraction",
    }
    INT_FIELDS = {"t_unix", "wave", "enemies", "bullets", "num_gc", "num_gc_delta"}

    def __init__(self, csv_path: Path):
        self.csv_path = csv_path

    def parse(self) -> Dict:
        rows = []
        with self.csv_path.open(newline="") as fh:
            reader = csv.DictReader(fh)
            for raw in reader:
                row = {}
                for key, value in raw.items():
                    if value is None or value == "":
                        row[key] = value
                    elif key in self.INT_FIELDS:
                        row[key] = int(float(value))
                    elif key in self.FLOAT_FIELDS:
                        row[key] = float(value)
                    else:
                        row[key] = value
                rows.append(row)

        return {
            "rows": rows,
            "fps": [row["fps"] for row in rows if "fps" in row],
            "frame_max_ms": [row["frame_max_ms"] for row in rows if "frame_max_ms" in row],
            "frame_p99_ms": [row["frame_p99_ms"] for row in rows if "frame_p99_ms" in row],
            "update_max_ms": [row["update_max_ms"] for row in rows if "update_max_ms" in row],
            "draw_max_ms": [row["draw_max_ms"] for row in rows if "draw_max_ms" in row],
            "heap_alloc": [row["heap_alloc"] for row in rows if "heap_alloc" in row],
            "heap_inuse": [row["heap_inuse"] for row in rows if "heap_inuse" in row],
        }


class PerfettoTraceParser:
    """Parse exported Perfetto or Chrome trace JSON."""

    def __init__(self, json_path: Path):
        self.json_path = json_path

    def parse(self) -> Dict:
        payload = json.loads(self.json_path.read_text())
        trace_events = payload.get("traceEvents") if isinstance(payload, dict) else payload
        if not isinstance(trace_events, list):
            raise click.ClickException("Unsupported JSON structure. Expected Perfetto/Chrome trace JSON with traceEvents.")

        events = []
        min_ts = None
        max_ts = None
        for event in trace_events:
            if not isinstance(event, dict):
                continue
            phase = event.get("ph", "X")
            if phase not in {"X", "i", "I"}:
                continue
            dur_us = parse_float(event.get("dur"))
            if dur_us is None or dur_us < 0:
                dur_us = 0.0
            ts_us = parse_float(event.get("ts")) or 0.0
            name = str(event.get("name", "unnamed"))
            category = str(event.get("cat", ""))
            track = self._track_name(event)
            workload = classify_workload(name, category)
            events.append(
                {
                    "name": name,
                    "category": category,
                    "track": track,
                    "workload": workload,
                    "duration_s": dur_us / 1_000_000.0,
                    "ts_us": ts_us,
                }
            )
            end_us = ts_us + dur_us
            min_ts = ts_us if min_ts is None else min(min_ts, ts_us)
            max_ts = end_us if max_ts is None else max(max_ts, end_us)

        return {
            "events": events,
            "source": "perfetto_json",
            "trace_span_s": ((max_ts - min_ts) / 1_000_000.0) if min_ts is not None and max_ts is not None else 0.0,
        }

    def _track_name(self, event: Dict) -> str:
        pid = event.get("pid", "?")
        tid = event.get("tid", "?")
        thread_name = event.get("tname") or event.get("thread_name") or ""
        proc_name = event.get("pname") or event.get("process_name") or ""
        pieces = [piece for piece in [proc_name, thread_name, f"pid={pid}", f"tid={tid}"] if piece]
        return " / ".join(str(piece) for piece in pieces)


class PerfettoBinaryParser:
    """Parse binary Perfetto traces through trace_processor_shell when available."""

    QUERY = """
    SELECT
      s.name AS name,
      ifnull(s.category, '') AS category,
      s.ts AS ts,
      s.dur AS dur,
      ifnull(p.name, '') AS process_name,
      ifnull(t.name, '') AS thread_name,
      ifnull(t.tid, 0) AS tid,
      ifnull(p.pid, 0) AS pid
    FROM slice s
    LEFT JOIN thread_track tt ON s.track_id = tt.id
    LEFT JOIN thread t ON tt.utid = t.utid
    LEFT JOIN process p ON t.upid = p.upid
    WHERE s.dur >= 0;
    """

    def __init__(self, trace_path: Path):
        self.trace_path = trace_path

    def parse(self) -> Dict:
        binary = self._find_trace_processor_binary()
        if binary is None:
            raise click.ClickException(
                "No trace processor binary found. Set TRACE_PROCESSOR_BIN or install trace_processor_shell."
            )
        output = subprocess.run(
            [binary, str(self.trace_path), "-q", self.QUERY],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        reader = csv.DictReader(output.splitlines())
        events = []
        min_ts = None
        max_ts = None
        for row in reader:
            dur = parse_float(row.get("dur")) or 0.0
            ts = parse_float(row.get("ts")) or 0.0
            name = row.get("name") or "unnamed"
            category = row.get("category") or ""
            thread_name = row.get("thread_name") or ""
            process_name = row.get("process_name") or ""
            tid = row.get("tid") or "?"
            pid = row.get("pid") or "?"
            track = " / ".join(piece for piece in [process_name, thread_name, f"pid={pid}", f"tid={tid}"] if piece)
            events.append(
                {
                    "name": name,
                    "category": category,
                    "track": track,
                    "workload": classify_workload(name, category),
                    "duration_s": dur / 1_000_000_000.0,
                    "ts_us": ts / 1000.0,
                }
            )
            end_ts = ts + dur
            min_ts = ts if min_ts is None else min(min_ts, ts)
            max_ts = end_ts if max_ts is None else max(max_ts, end_ts)

        return {
            "events": events,
            "source": "perfetto_binary",
            "trace_span_s": ((max_ts - min_ts) / 1_000_000_000.0) if min_ts is not None and max_ts is not None else 0.0,
        }

    def _find_trace_processor_binary(self) -> str | None:
        candidates = [
            os.environ.get("TRACE_PROCESSOR_BIN"),
            "trace_processor_shell",
            "trace_processor",
        ]
        for candidate in candidates:
            if not candidate:
                continue
            try:
                subprocess.run([candidate, "--help"], capture_output=True, text=True, check=False)
                return candidate
            except FileNotFoundError:
                continue
        return None


class NsightCSVParser:
    """Parse exported Nsight-style CSV summaries."""

    def __init__(self, csv_path: Path):
        self.csv_path = csv_path

    def parse(self) -> Dict:
        with self.csv_path.open(newline="") as fh:
            reader = csv.DictReader(fh)
            rows = []
            for raw in reader:
                row = {normalize_key(key): value for key, value in raw.items() if key is not None}
                rows.append(row)

        events = []
        kernel_metrics = []
        for row in rows:
            name = row.get("name") or row.get("operation") or row.get("kernel_name") or row.get("range") or "unnamed"
            category = row.get("category") or row.get("kind") or row.get("event_class") or row.get("type") or ""
            duration_ns = self._duration_ns(row)
            bytes_value = self._bytes_value(row)
            track = row.get("stream") or row.get("context") or row.get("device") or row.get("thread") or row.get("process") or ""
            occupancy = self._metric(row, "achieved_occupancy", "occupancy", "sm_occupancy")
            dram_bw = self._metric(row, "dram_throughput_gb_s", "dram_bandwidth_gb_s", "memory_throughput_gb_s")
            mem_bw = self._metric(row, "mem_bw_gb_s", "memory_bandwidth_gb_s", "bandwidth_gb_s")
            sm_efficiency = self._metric(row, "sm_efficiency", "compute_throughput_pct", "sm_active_pct")
            events.append(
                {
                    "name": name,
                    "category": category,
                    "track": str(track),
                    "workload": classify_workload(name, category),
                    "duration_s": duration_ns / 1_000_000_000.0,
                    "bytes": bytes_value or 0.0,
                    "occupancy": occupancy,
                    "dram_bw_gb_s": dram_bw,
                    "mem_bw_gb_s": mem_bw,
                    "sm_efficiency_pct": sm_efficiency,
                }
            )
            if occupancy is not None or dram_bw is not None or mem_bw is not None or sm_efficiency is not None:
                kernel_metrics.append(
                    {
                        "name": name,
                        "occupancy": occupancy,
                        "dram_bw_gb_s": dram_bw,
                        "mem_bw_gb_s": mem_bw,
                        "sm_efficiency_pct": sm_efficiency,
                        "duration_s": duration_ns / 1_000_000_000.0,
                    }
                )

        return {
            "events": events,
            "kernel_metrics": kernel_metrics,
            "source": "nsight_csv",
            "trace_span_s": sum(event["duration_s"] for event in events),
        }

    def _duration_ns(self, row: Dict) -> float:
        for key in (
            "duration_ns",
            "time_ns",
            "gpu_time_ns",
            "kernel_time_ns",
            "duration",
            "time",
            "avg_ns",
            "average_ns",
        ):
            value = parse_float(row.get(key))
            if value is not None:
                if key.endswith("_ns") or key == "time_ns" or key == "gpu_time_ns" or key == "kernel_time_ns":
                    return value
                return value
        for key in ("duration_us", "time_us"):
            value = parse_float(row.get(key))
            if value is not None:
                return value * 1_000.0
        for key in ("duration_ms", "time_ms"):
            value = parse_float(row.get(key))
            if value is not None:
                return value * 1_000_000.0
        for key in ("duration_s", "time_s"):
            value = parse_float(row.get(key))
            if value is not None:
                return value * 1_000_000_000.0
        return 0.0

    def _bytes_value(self, row: Dict) -> float | None:
        for key in ("bytes", "size_bytes", "memory_bytes"):
            value = parse_float(row.get(key))
            if value is not None:
                return value
        for key in ("size_kb",):
            value = parse_float(row.get(key))
            if value is not None:
                return value * 1024.0
        for key in ("size_mb",):
            value = parse_float(row.get(key))
            if value is not None:
                return value * 1024.0 * 1024.0
        for key in ("size_gb",):
            value = parse_float(row.get(key))
            if value is not None:
                return value * 1024.0 * 1024.0 * 1024.0
        return None

    def _metric(self, row: Dict, *keys: str) -> float | None:
        for key in keys:
            value = parse_float(row.get(key))
            if value is not None:
                return value
        return None


class MarkdownFormatter:
    """Format parsed performance data as markdown."""

    def format_flamegraph(self, frames: List[Dict], input_file: str) -> str:
        total_time = max((frame.get("time_s", 0.0) for frame in frames), default=0.0)
        lines = [
            f"# Flamegraph Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"- Functions analyzed: {len(frames)}",
        ]
        if total_time > 0:
            lines.append(f"- Largest node time: {total_time:.2f}s")
        lines.extend(
            [
                "",
                "## Top Nodes",
                "",
                "| Rank | Function | Time | % of Largest Node |",
                "|------|----------|------|-------------------|",
            ]
        )

        for idx, frame in enumerate(frames[:20], start=1):
            function = self._truncate(frame.get("function", "Unknown"), 80)
            time_s = frame.get("time_s", 0.0)
            pct = frame.get("percentage", 0.0)
            lines.append(f"| {idx} | `{function}` | {time_s:.2f}s | {pct:.2f}% |")

        significant = [frame for frame in frames if frame.get("percentage", 0.0) >= 1.0]
        if significant:
            lines.extend(["", "## Hotspots", ""])
            for frame in significant[:20]:
                lines.append(f"- `{frame.get('function', 'Unknown')}`: {frame.get('time_s', 0.0):.2f}s ({frame.get('percentage', 0.0):.2f}%)")

        return "\n".join(lines)

    def format_profile(self, profile_data: List[Dict], input_file: str, top_n: int = 50, hotspot_threshold: float = 1.0) -> str:
        lines = [
            f"# Profile Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"- Functions profiled: {len(profile_data)}",
        ]
        total_time = sum(x.get("cumtime", 0) for x in profile_data)
        if total_time > 0:
            lines.append(f"- Total cumulative time: {total_time:.3f}s")
        lines.extend(
            [
                "",
                f"## Top {top_n} Time-Consuming Functions",
                "",
                "| Rank | Function | Location | Cumulative | Own Time | Calls | % Total |",
                "|------|----------|----------|------------|----------|-------|---------|",
            ]
        )

        for idx, item in enumerate(profile_data[:top_n], start=1):
            func_name = self._truncate(item.get("func_name", item.get("function", "Unknown")), 48)
            location = self._truncate(item.get("location", "Unknown"), 60)
            lines.append(
                f"| {idx} | `{func_name}` | {location} | {item.get('cumtime', 0):.3f}s | "
                f"{item.get('tottime', 0):.3f}s | {item.get('ncalls', 0):,} | {item.get('percentage', 0):.1f}% |"
            )

        hotspots = [item for item in profile_data if item.get("percentage", 0.0) >= hotspot_threshold]
        if hotspots:
            lines.extend(["", f"## Hotspots (>{hotspot_threshold}% of total time)", ""])
            for item in hotspots[:20]:
                lines.append(
                    f"- `{item.get('func_name', item.get('function', 'Unknown'))}`: "
                    f"{item.get('cumtime', 0):.3f}s cumulative, {item.get('percentage', 0):.2f}%"
                )

        return "\n".join(lines)

    def format_go_pprof(self, data: Dict, input_file: str, top_n: int = 30, hotspot_threshold: float = 1.0) -> str:
        entries = data.get("entries", [])
        lines = [
            f"# Go pprof Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"- Entries parsed: {len(entries)}",
            f"- Profile duration: {data.get('duration_s', 0.0):.2f}s",
            f"- Total CPU samples: {data.get('total_samples_s', 0.0):.2f}s",
            "",
            f"## Top {top_n} By Cumulative Time",
            "",
            "| Rank | Function | Flat | Flat % | Cumulative | Cum % |",
            "|------|----------|------|--------|------------|-------|",
        ]

        for idx, item in enumerate(entries[:top_n], start=1):
            lines.append(
                f"| {idx} | `{self._truncate(item['function'], 90)}` | {item['flat_s']:.2f}s | {item['flat_pct']:.2f}% | "
                f"{item['cum_s']:.2f}s | {item['cum_pct']:.2f}% |"
            )

        hotspots = [item for item in entries if item["cum_pct"] >= hotspot_threshold]
        if hotspots:
            lines.extend(["", f"## Hotspots (>{hotspot_threshold}% cumulative)", ""])
            for item in hotspots[:20]:
                lines.append(
                    f"- `{item['function']}`: {item['cum_s']:.2f}s cumulative ({item['cum_pct']:.2f}%), "
                    f"{item['flat_s']:.2f}s flat ({item['flat_pct']:.2f}%)"
                )

        return "\n".join(lines)

    def format_perf_csv(self, data: Dict, input_file: str) -> str:
        rows = data["rows"]
        fps = data["fps"]
        frame_max = data["frame_max_ms"]
        draw_max = data["draw_max_ms"]
        update_max = data["update_max_ms"]
        heap_alloc = data["heap_alloc"]
        heap_inuse = data["heap_inuse"]

        lines = [
            f"# Perf CSV Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"- Samples: {len(rows)} seconds",
            f"- Avg FPS: {statistics.mean(fps):.2f}" if fps else "- Avg FPS: n/a",
            f"- FPS P50/P95/P99: {percentile(fps, 50):.2f} / {percentile(fps, 95):.2f} / {percentile(fps, 99):.2f}" if fps else "- FPS P50/P95/P99: n/a",
            f"- Frame max avg / worst: {statistics.mean(frame_max):.2f}ms / {max(frame_max):.2f}ms" if frame_max else "- Frame max avg / worst: n/a",
            f"- Draw max avg / worst: {statistics.mean(draw_max):.3f}ms / {max(draw_max):.3f}ms" if draw_max else "- Draw max avg / worst: n/a",
            f"- Update max avg / worst: {statistics.mean(update_max):.3f}ms / {max(update_max):.3f}ms" if update_max else "- Update max avg / worst: n/a",
            f"- Heap alloc range: {min(heap_alloc)/1024/1024:.1f} MiB -> {max(heap_alloc)/1024/1024:.1f} MiB" if heap_alloc else "- Heap alloc range: n/a",
            f"- Heap in-use range: {min(heap_inuse)/1024/1024:.1f} MiB -> {max(heap_inuse)/1024/1024:.1f} MiB" if heap_inuse else "- Heap in-use range: n/a",
        ]

        worst_rows = sorted(rows, key=lambda row: row.get("frame_max_ms", 0.0), reverse=True)[:5]
        if worst_rows:
            lines.extend(
                [
                    "",
                    "## Worst Frame Seconds",
                    "",
                    "| t_unix | FPS | Frame Max ms | Draw Max ms | Update Max ms | Wave | Enemies | Bullets |",
                    "|--------|-----|--------------|-------------|---------------|------|---------|---------|",
                ]
            )
            for row in worst_rows:
                lines.append(
                    f"| {row.get('t_unix', '')} | {row.get('fps', 0):.0f} | {row.get('frame_max_ms', 0.0):.3f} | "
                    f"{row.get('draw_max_ms', 0.0):.3f} | {row.get('update_max_ms', 0.0):.3f} | "
                    f"{row.get('wave', 0)} | {row.get('enemies', 0)} | {row.get('bullets', 0)} |"
                )

        return "\n".join(lines)

    def format_trace(self, data: Dict, input_file: str, top_n: int = 20) -> str:
        events = [event for event in data.get("events", []) if event.get("duration_s", 0.0) >= 0.0]
        total_event_time = sum(event.get("duration_s", 0.0) for event in events)
        by_workload = defaultdict(float)
        by_workload_bytes = defaultdict(float)
        by_track = defaultdict(float)
        by_name = defaultdict(lambda: {"time_s": 0.0, "count": 0, "bytes": 0.0, "workload": "Other"})

        for event in events:
            duration_s = event.get("duration_s", 0.0)
            workload = event.get("workload", "Other")
            by_workload[workload] += duration_s
            by_workload_bytes[workload] += event.get("bytes", 0.0)
            by_track[event.get("track", "")] += duration_s
            name_entry = by_name[event.get("name", "unnamed")]
            name_entry["time_s"] += duration_s
            name_entry["count"] += 1
            name_entry["bytes"] += event.get("bytes", 0.0)
            name_entry["workload"] = workload

        lines = [
            f"# Trace Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"- Events analyzed: {len(events)}",
            f"- Trace span: {data.get('trace_span_s', 0.0):.3f}s",
            f"- Total timed event duration: {total_event_time:.3f}s",
            f"- Source: {data.get('source')}" if data.get("source") else "- Source: unknown",
            "",
            "## Time By Workload",
            "",
            "| Workload | Total Time | Share | Bytes | Bandwidth |",
            "|----------|------------|-------|-------|-----------|",
        ]

        workload_rows = sorted(by_workload.items(), key=lambda item: item[1], reverse=True)
        for workload, time_s in workload_rows:
            share = (time_s / total_event_time * 100.0) if total_event_time > 0 else 0.0
            bytes_value = by_workload_bytes.get(workload, 0.0)
            lines.append(
                f"| {workload} | {time_s:.3f}s | {share:.2f}% | "
                f"{bytes_to_human(bytes_value) if bytes_value > 0 else '-'} | {bandwidth_to_human(bytes_value, time_s)} |"
            )

        top_names = sorted(by_name.items(), key=lambda item: item[1]["time_s"], reverse=True)[:top_n]
        if top_names:
            lines.extend(
                [
                    "",
                    f"## Top {top_n} Operations",
                    "",
                    "| Rank | Operation | Workload | Time | Calls | Avg | Bytes | Bandwidth |",
                    "|------|-----------|----------|------|-------|-----|-------|-----------|",
                ]
            )
            for idx, (name, entry) in enumerate(top_names, start=1):
                calls = entry["count"]
                avg_s = entry["time_s"] / calls if calls else 0.0
                bytes_text = bytes_to_human(entry["bytes"]) if entry["bytes"] > 0 else "-"
                lines.append(
                    f"| {idx} | `{self._truncate(name, 70)}` | {entry['workload']} | {entry['time_s']:.3f}s | "
                    f"{calls} | {avg_s:.6f}s | {bytes_text} | {bandwidth_to_human(entry['bytes'], entry['time_s'])} |"
                )

        top_tracks = sorted(by_track.items(), key=lambda item: item[1], reverse=True)[:10]
        if top_tracks:
            lines.extend(
                [
                    "",
                    "## Busiest Tracks",
                    "",
                    "| Track | Total Time |",
                    "|-------|------------|",
                ]
            )
            for track, time_s in top_tracks:
                lines.append(f"| {self._truncate(track or 'unlabeled', 80)} | {time_s:.3f}s |")

        transfer_events = [event for event in events if event.get("workload", "").startswith("Memcpy")]
        if transfer_events:
            transfer_time = sum(event.get("duration_s", 0.0) for event in transfer_events)
            transfer_bytes = sum(event.get("bytes", 0.0) for event in transfer_events)
            lines.extend(
                [
                    "",
                    "## Transfer Summary",
                    "",
                    f"- Transfer events: {len(transfer_events)}",
                    f"- Total transfer time: {transfer_time:.3f}s",
                    f"- Total transfer volume: {bytes_to_human(transfer_bytes)}" if transfer_bytes > 0 else "- Total transfer volume: unavailable",
                    f"- Aggregate transfer bandwidth: {bandwidth_to_human(transfer_bytes, transfer_time)}" if transfer_bytes > 0 else "- Aggregate transfer bandwidth: unavailable",
                ]
            )

        kernel_metrics = data.get("kernel_metrics", [])
        if kernel_metrics:
            occupancy_values = [row["occupancy"] for row in kernel_metrics if row.get("occupancy") is not None]
            dram_values = [row["dram_bw_gb_s"] for row in kernel_metrics if row.get("dram_bw_gb_s") is not None]
            mem_values = [row["mem_bw_gb_s"] for row in kernel_metrics if row.get("mem_bw_gb_s") is not None]
            sm_values = [row["sm_efficiency_pct"] for row in kernel_metrics if row.get("sm_efficiency_pct") is not None]
            lines.extend(["", "## Kernel Metrics", ""])
            if occupancy_values:
                lines.append(f"- Avg occupancy: {statistics.mean(occupancy_values):.2f}")
            if dram_values:
                lines.append(f"- Avg DRAM throughput: {statistics.mean(dram_values):.2f} GB/s")
            if mem_values:
                lines.append(f"- Avg memory bandwidth: {statistics.mean(mem_values):.2f} GB/s")
            if sm_values:
                lines.append(f"- Avg SM efficiency: {statistics.mean(sm_values):.2f}%")
            lines.extend(
                [
                    "",
                    "| Kernel | Time | Occupancy | DRAM GB/s | Mem GB/s | SM Eff % |",
                    "|--------|------|-----------|-----------|----------|----------|",
                ]
            )
            for row in sorted(kernel_metrics, key=lambda item: item.get("duration_s", 0.0), reverse=True)[:10]:
                lines.append(
                    f"| `{self._truncate(row['name'], 60)}` | {row.get('duration_s', 0.0):.3f}s | "
                    f"{row.get('occupancy', '-') if row.get('occupancy') is not None else '-'} | "
                    f"{row.get('dram_bw_gb_s', '-') if row.get('dram_bw_gb_s') is not None else '-'} | "
                    f"{row.get('mem_bw_gb_s', '-') if row.get('mem_bw_gb_s') is not None else '-'} | "
                    f"{row.get('sm_efficiency_pct', '-') if row.get('sm_efficiency_pct') is not None else '-'} |"
                )

        return "\n".join(lines)

    def _truncate(self, value: str, limit: int) -> str:
        return value if len(value) <= limit else value[: limit - 3] + "..."


def detect_csv_format(input_path: Path) -> str:
    with input_path.open(newline="") as fh:
        reader = csv.reader(fh)
        headers = next(reader, [])
    normalized = {normalize_key(header) for header in headers}
    if {"fps", "frame_max_ms", "draw_max_ms"} <= normalized:
        return "perf_csv"
    if {"name", "duration"} & normalized or {"operation", "time_ns"} & normalized or {"kernel_name"} & normalized:
        return "nsight_csv"
    raise click.ClickException("Unsupported CSV format. Expected harness perf CSV or exported Nsight-style CSV.")


@click.command()
@click.argument("input_file", type=click.Path(exists=True))
@click.option("-o", "--output", type=click.Path(), help="Output markdown file (default: stdout)")
@click.option("-n", "--top-n", type=int, default=50, help="Number of top functions or operations to display (default: 50)")
@click.option("-t", "--threshold", type=float, default=1.0, help="Hotspot threshold percentage (default: 1.0)")
def cli(input_file, output, top_n, threshold):
    """Convert SVG, Go pprof, Python profile, Perfetto JSON, or CSV profiling exports to markdown."""
    input_path = Path(input_file)
    suffix = input_path.suffix.lower()
    formatter = MarkdownFormatter()

    if suffix == ".svg":
        markdown = formatter.format_flamegraph(FlamegraphParser(input_path).parse(), input_file)
    elif suffix in {".profile", ".prof"}:
        markdown = formatter.format_profile(ProfileParser(input_path).parse(), input_file, top_n=top_n, hotspot_threshold=threshold)
    elif suffix == ".pprof":
        markdown = formatter.format_go_pprof(GoPprofParser(input_path).parse(), input_file, top_n=top_n, hotspot_threshold=threshold)
    elif suffix == ".json":
        markdown = formatter.format_trace(PerfettoTraceParser(input_path).parse(), input_file, top_n=top_n)
    elif suffix in {".pftrace", ".perfetto_trace", ".perfetto-trace", ".proto"}:
        markdown = formatter.format_trace(PerfettoBinaryParser(input_path).parse(), input_file, top_n=top_n)
    elif suffix == ".csv":
        csv_format = detect_csv_format(input_path)
        if csv_format == "perf_csv":
            markdown = formatter.format_perf_csv(PerfCSVParser(input_path).parse(), input_file)
        else:
            markdown = formatter.format_trace(NsightCSVParser(input_path).parse(), input_file, top_n=top_n)
    else:
        raise click.ClickException(f"Unsupported file type: {suffix}")

    if output:
        Path(output).write_text(markdown)
        click.echo(f"Markdown analysis written to: {output}")
    else:
        click.echo(markdown)


if __name__ == "__main__":
    cli()
