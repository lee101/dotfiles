#!/usr/bin/env python3
"""Run Nsight Systems on a command and emit a readable Markdown report."""

from __future__ import annotations

import argparse
import csv
import errno
import heapq
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


DEFAULT_REPORTS = (
    "cuda_api_sum",
    "cuda_gpu_kern_sum",
    "cuda_gpu_mem_time_sum",
    "cuda_gpu_mem_size_sum",
)

REPORT_SECTIONS = {
    "api": ("cuda_api_sum",),
    "kernels": ("cuda_gpu_kern_sum",),
    "transfers": ("cuda_gpu_mem_time_sum", "cuda_gpu_mem_size_sum"),
    "all": DEFAULT_REPORTS,
}
DEFAULT_REPORT_SECTIONS = ("api", "kernels", "transfers")


@dataclass
class StatsReport:
    name: str
    headers: list[str]
    rows: list[dict[str, str]]
    skipped: str | None = None
    raw_output: str = ""


@dataclass
class ProfileArtifacts:
    command: list[str]
    exit_code: int
    stats_exit_code: int | None
    wall_time_s: float
    generated_at: str
    prefix: Path
    rep_path: Path
    sqlite_path: Path | None
    reports: dict[str, StatsReport]
    profile_stdout: str = ""
    profile_stderr: str = ""


@dataclass
class PolicyCheck:
    name: str
    ok: bool
    message: str


@dataclass
class _ParseState:
    headers: list[str] | None = None
    rows: list[dict[str, str]] | None = None
    skipped: str | None = None
    raw_lines: list[str] | None = None

    def __post_init__(self) -> None:
        if self.rows is None:
            self.rows = []
        if self.raw_lines is None:
            self.raw_lines = []


def overall_status(artifacts: ProfileArtifacts, policy_checks: Iterable[PolicyCheck] = ()) -> str:
    checks = list(policy_checks)
    if artifacts.exit_code != 0:
        return "ERROR"
    if artifacts.stats_exit_code not in (None, 0):
        return "ERROR"
    if any(not check.ok for check in checks):
        return "FAIL"
    if checks:
        return "PASS"
    return "OK"


def _status_summary(artifacts: ProfileArtifacts, policy_checks: Iterable[PolicyCheck] = ()) -> str:
    checks = list(policy_checks)
    status = overall_status(artifacts, checks)
    if status == "PASS":
        return "[PASS]"
    if status == "OK":
        return "[OK]"
    if status == "ERROR":
        if artifacts.stats_exit_code not in (None, 0) and artifacts.exit_code == 0:
            return f"[ERROR stats_exit={artifacts.stats_exit_code}]"
        return f"[ERROR target_exit={artifacts.exit_code}]"
    failing = [check.name for check in checks if not check.ok]
    if failing:
        return f"[FAIL {', '.join(failing)}]"
    return "[FAIL]"


def _cli_followup_lines(
    artifacts: ProfileArtifacts,
    policy_checks: Iterable[PolicyCheck] = (),
    report_sections: Iterable[str] | None = None,
) -> list[str]:
    lines: list[str] = []
    failing_checks = [check for check in policy_checks if not check.ok]
    if failing_checks:
        for check in failing_checks[:3]:
            lines.append(f"  - {check.name}: {check.message}")

    recommendations = _build_recommendation_lines(artifacts, report_sections=report_sections)
    if recommendations:
        lines.append(f"  - next: {recommendations[0]}")

    lines.append(f"  - report: {artifacts.rep_path}")
    if artifacts.sqlite_path is not None:
        lines.append(f"  - sqlite: {artifacts.sqlite_path}")
    return lines


def _empty_report(name: str, skipped: str | None = None) -> StatsReport:
    return StatsReport(name=name, headers=[], rows=[], skipped=skipped)


def _report(reports: dict[str, StatsReport], name: str) -> StatsReport:
    return reports.get(name, _empty_report(name))


def _report_section(value: str) -> str:
    lowered = value.strip().lower()
    if lowered not in REPORT_SECTIONS:
        choices = ", ".join(REPORT_SECTIONS.keys())
        raise argparse.ArgumentTypeError(f"unknown report section {value!r}; choose from {choices}")
    return lowered


def _resolve_report_sections(
    sections: Iterable[str] | None,
    require_kernels: bool = False,
    max_api_time_pct: Iterable[tuple[str, float]] = (),
) -> tuple[str, ...]:
    ordered: list[str] = []
    requested = list(sections or DEFAULT_REPORT_SECTIONS)
    if not requested:
        requested = list(DEFAULT_REPORT_SECTIONS)
    if "all" in requested:
        requested = list(DEFAULT_REPORT_SECTIONS)
    for section in requested:
        normalized = _report_section(section)
        if normalized != "all" and normalized not in ordered:
            ordered.append(normalized)
    if require_kernels and "kernels" not in ordered:
        ordered.append("kernels")
    if list(max_api_time_pct) and "api" not in ordered:
        ordered.append("api")
    return tuple(ordered)


def _resolve_internal_reports(sections: Iterable[str]) -> tuple[str, ...]:
    reports: list[str] = []
    for section in sections:
        for report_name in REPORT_SECTIONS[section]:
            if report_name not in reports:
                reports.append(report_name)
    return tuple(reports)


def _default_prefix() -> str:
    return datetime.now(timezone.utc).strftime("cuda_profile_%Y%m%d_%H%M%S")


def _default_prefix_path(markdown_out: Path | None) -> Path:
    if markdown_out is not None:
        return markdown_out.with_suffix("")
    return Path.cwd() / _default_prefix()


def _normalize_path(path: Path | None) -> Path | None:
    if path is None:
        return None
    return path.expanduser()


def _artifact_path(prefix: Path, cwd: Path | None) -> Path:
    if prefix.is_absolute() or cwd is None:
        return prefix
    return cwd / prefix


def _replace_path(dst: Path) -> None:
    if dst.is_symlink():
        dst.unlink()
        return
    if dst.exists():
        if dst.is_dir():
            raise OSError(errno.EISDIR, "path is a directory", str(dst))
        dst.unlink()


def _link_or_copy(src: Path, dst: Path) -> None:
    resolved_src = src.resolve()
    dst.parent.mkdir(parents=True, exist_ok=True)
    _replace_path(dst)
    try:
        dst.symlink_to(resolved_src)
    except OSError as exc:
        if exc.errno not in (errno.EPERM, errno.EOPNOTSUPP, errno.ENOTSUP):
            raise
        shutil.copy2(resolved_src, dst)


def _sync_optional_link(src: Path | None, dst: Path) -> None:
    if src is not None and src.exists():
        _link_or_copy(src, dst)
        return
    if dst.is_symlink() or dst.exists():
        _replace_path(dst)


def _update_latest_links(
    markdown_path: Path,
    artifacts: ProfileArtifacts,
    latest_link: Path | None,
) -> None:
    if latest_link is None:
        return

    _link_or_copy(markdown_path, latest_link)
    _sync_optional_link(artifacts.rep_path, latest_link.with_suffix(".nsys-rep"))
    _sync_optional_link(artifacts.sqlite_path, latest_link.with_suffix(".sqlite"))


def _find_nsys(path_override: str | None) -> str:
    if path_override:
        path = Path(path_override).expanduser()
        if not path.exists():
            raise SystemExit(f"nsys not found at {path_override}")
        if not os.access(path, os.X_OK):
            raise SystemExit(f"nsys is not executable: {path_override}")
        return str(path)
    nsys = shutil.which("nsys")
    if not nsys:
        raise SystemExit("nsys not found in PATH; install Nsight Systems first.")
    return nsys


def _run(
    cmd: list[str],
    cwd: Path | None = None,
    timeout_s: float | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout_s,
        )
    except subprocess.TimeoutExpired as exc:
        command = shlex.join(cmd)
        timeout = exc.timeout if exc.timeout is not None else 0.0
        raise RuntimeError(f"timed out after {timeout:.3f}s while running `{command}`") from exc
    except OSError as exc:
        command = shlex.join(cmd)
        detail = exc.strerror or str(exc)
        raise RuntimeError(f"failed to run `{command}`: {detail}") from exc


def _cleanup_old_artifacts(prefix: Path) -> None:
    for suffix in (".nsys-rep", ".sqlite"):
        path = prefix.with_suffix(suffix)
        if path.exists():
            path.unlink()


def _parse_csv_line(line: str) -> list[str]:
    return next(csv.reader([line]))


def _processing_report_name(line: str) -> str | None:
    match = re.search(r"/([^/\]]+)\.py\].*$", line)
    if not match:
        return None
    return match.group(1)


def _consume_stats_line(state: _ParseState, raw_line: str) -> None:
    state.raw_lines.append(raw_line)
    line = raw_line.strip()
    if not line:
        return
    if line.startswith("Generating SQLite file "):
        return
    if line.startswith("Processing ["):
        return
    if line.startswith("SKIPPED:"):
        state.skipped = line[len("SKIPPED:") :].strip()
        return
    if "," not in line:
        return

    parsed = _parse_csv_line(raw_line)
    if state.headers is None:
        state.headers = parsed
        return
    if len(parsed) != len(state.headers):
        return
    state.rows.append(dict(zip(state.headers, parsed)))


def parse_nsys_csv_output(report_name: str, output: str) -> StatsReport:
    state = _ParseState()
    for raw_line in output.splitlines():
        _consume_stats_line(state, raw_line)

    return StatsReport(
        name=report_name,
        headers=state.headers or [],
        rows=state.rows,
        skipped=state.skipped,
        raw_output="\n".join(state.raw_lines),
    )


def parse_nsys_stats_bundle(
    report_names: Iterable[str],
    output: str,
) -> dict[str, StatsReport]:
    names = list(report_names)
    states: dict[str, _ParseState] = {name: _ParseState() for name in names}
    current_name: str | None = None

    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("Processing ["):
            report_name = _processing_report_name(line)
            if report_name in states:
                current_name = report_name
                _consume_stats_line(states[current_name], raw_line)
            else:
                current_name = None
            continue

        if current_name is None:
            continue
        _consume_stats_line(states[current_name], raw_line)

    reports: dict[str, StatsReport] = {}
    for name, state in states.items():
        reports[name] = StatsReport(
            name=name,
            headers=state.headers or [],
            rows=state.rows,
            skipped=state.skipped,
            raw_output="\n".join(state.raw_lines),
        )
    return reports


def _to_float(value: str | None) -> float | None:
    if value is None:
        return None
    cleaned = value.replace(",", "").strip()
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _fmt_ns(ns: float | None) -> str:
    if ns is None:
        return "n/a"
    if ns >= 1_000_000_000:
        return f"{ns / 1_000_000_000:.3f} s"
    if ns >= 1_000_000:
        return f"{ns / 1_000_000:.3f} ms"
    if ns >= 1_000:
        return f"{ns / 1_000:.3f} us"
    return f"{ns:.0f} ns"


def _fmt_pct(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value:.1f}%"


def _fmt_bytes(value: float | None) -> str:
    if value is None:
        return "n/a"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    size = float(value)
    unit = units[0]
    for unit in units:
        if size < 1024 or unit == units[-1]:
            break
        size /= 1024
    return f"{size:.2f} {unit}"


def _top_rows(report: StatsReport, limit: int = 5) -> list[dict[str, str]]:
    def key(row: dict[str, str]) -> float:
        for field in ("Total Time (ns)", "Total (ns)", "Total", "Sum (ns)", "Size (bytes)"):
            value = _to_float(row.get(field))
            if value is not None:
                return value
        return 0.0

    if limit <= 0 or not report.rows:
        return []
    if limit >= len(report.rows):
        return sorted(report.rows, key=key, reverse=True)

    top = heapq.nlargest(
        limit,
        enumerate(report.rows),
        key=lambda item: (key(item[1]), -item[0]),
    )
    return [row for _, row in top]


def _positive_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"expected integer, got {value!r}") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be a positive integer")
    return parsed


def _positive_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"expected number, got {value!r}") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be a positive number")
    return parsed


def _api_pct_limit(value: str) -> tuple[str, float]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("expected NAME=PERCENT")
    name, raw_pct = value.split("=", 1)
    name = name.strip()
    if not name:
        raise argparse.ArgumentTypeError("API name must not be empty")
    try:
        pct = float(raw_pct)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid percent {raw_pct!r}") from exc
    if pct < 0:
        raise argparse.ArgumentTypeError("percent must be non-negative")
    return name, pct


def _report_total_ns(report: StatsReport) -> float:
    total = 0.0
    for row in report.rows:
        value = _to_float(row.get("Total Time (ns)") or row.get("Total (ns)") or row.get("Sum (ns)"))
        if value is not None:
            total += value
    return total


def _transfer_kind(name: str) -> str:
    lowered = name.lower()
    if "dtoh" in lowered:
        return "DtoH"
    if "htod" in lowered:
        return "HtoD"
    if "dtod" in lowered:
        return "DtoD"
    if "memset" in lowered:
        return "Memset"
    return "Other"


def _gpu_active_ns(reports: dict[str, StatsReport]) -> float:
    total = 0.0
    for report_name in ("cuda_gpu_kern_sum", "cuda_gpu_mem_time_sum"):
        total += _report_total_ns(_report(reports, report_name))
    return total


def _build_summary_lines(
    artifacts: ProfileArtifacts,
    report_sections: Iterable[str] | None = None,
) -> list[str]:
    reports = artifacts.reports
    sections = set(report_sections or DEFAULT_REPORT_SECTIONS)
    lines: list[str] = []

    if "api" in sections:
        api_report = _report(reports, "cuda_api_sum")
        if api_report.rows:
            top = _top_rows(api_report, 1)[0]
            name = top.get("Name", "unknown")
            percent = _to_float(top.get("Time (%)"))
            calls = top.get("Num Calls", "?")
            lines.append(
                f"CUDA API time is dominated by `{name}` ({_fmt_pct(percent)} across {calls} calls)."
            )

    if "kernels" in sections:
        kernel_report = _report(reports, "cuda_gpu_kern_sum")
        if kernel_report.rows:
            kernel_total = _report_total_ns(kernel_report)
            top_kernel = _top_rows(kernel_report, 1)[0]
            kernel_name = (
                top_kernel.get("Name")
                or top_kernel.get("Kernel Name")
                or top_kernel.get("Operation")
                or "unknown"
            )
            lines.append(
                f"Captured {len(kernel_report.rows)} kernel rows with {_fmt_ns(kernel_total)} total GPU kernel time; hottest kernel: `{kernel_name}`."
            )
        else:
            lines.append("No GPU kernel activity was captured in this run.")

    if "transfers" in sections:
        mem_time = _report(reports, "cuda_gpu_mem_time_sum")
        if mem_time.rows:
            mem_total = _report_total_ns(mem_time)
            top_mem = _top_rows(mem_time, 1)[0]
            name = top_mem.get("Name") or top_mem.get("Operation") or "unknown"
            lines.append(f"GPU memory operations consumed {_fmt_ns(mem_total)} total device time; hottest transfer: `{name}`.")
        else:
            lines.append("No GPU memory transfer activity was captured in this run.")

    if artifacts.exit_code != 0:
        lines.append(f"Target command exited with code `{artifacts.exit_code}`.")
    if artifacts.stats_exit_code not in (None, 0):
        lines.append(f"`nsys stats` exited with code `{artifacts.stats_exit_code}`, so the report may be incomplete.")

    return lines


def _build_use_lines(
    artifacts: ProfileArtifacts,
    report_sections: Iterable[str] | None = None,
) -> list[str]:
    reports = artifacts.reports
    sections = set(report_sections or DEFAULT_REPORT_SECTIONS)
    wall_ns = artifacts.wall_time_s * 1_000_000_000
    track_gpu_activity = "kernels" in sections or "transfers" in sections
    active_ns = _gpu_active_ns(reports) if track_gpu_activity else 0.0
    utilization = (active_ns / wall_ns * 100.0) if wall_ns > 0 and active_ns > 0 else None

    if track_gpu_activity:
        lines = [f"- Utilization: {_fmt_pct(utilization)} of wall time had traced GPU work."]
    else:
        lines = ["- Utilization: n/a because kernel and transfer sections were not collected."]

    api_report = _report(reports, "cuda_api_sum") if "api" in sections else _empty_report("cuda_api_sum")
    mem_report = _report(reports, "cuda_gpu_mem_time_sum") if "transfers" in sections else _empty_report("cuda_gpu_mem_time_sum")
    kernel_report = _report(reports, "cuda_gpu_kern_sum") if "kernels" in sections else _empty_report("cuda_gpu_kern_sum")

    saturation = "No clear saturation signal."
    strong_api_signal = False
    if api_report.rows:
        top = _top_rows(api_report, 1)[0]
        name = top.get("Name", "")
        percent = _to_float(top.get("Time (%)")) or 0.0
        if name == "cudaMalloc" and percent >= 50.0:
            saturation = "Allocation/setup overhead dominates; reuse device buffers or preallocate persistent workspaces."
            strong_api_signal = True
        elif "Memcpy" in name or "memcpy" in name:
            saturation = "Host/device transfer overhead dominates; batch transfers or keep data resident on device."
            strong_api_signal = True

    kernel_ns = _report_total_ns(kernel_report)
    mem_ns = _report_total_ns(mem_report)
    if not strong_api_signal and kernel_ns > 0 and mem_ns > 0:
        if mem_ns > kernel_ns * 1.2:
            saturation = "Transfer time exceeds kernel time; the run looks bandwidth-bound."
        elif kernel_ns > mem_ns * 1.2:
            saturation = "Kernel execution dominates GPU active time; focus on launch shape, occupancy, and math throughput."
    elif not strong_api_signal and kernel_ns > 0:
        saturation = "Kernel execution dominates traced GPU work."
    elif not strong_api_signal and mem_ns > 0:
        saturation = "GPU time is dominated by copies or memory ops."

    errors: list[str] = []
    for report in reports.values():
        if report.skipped:
            errors.append(f"{report.name}: {report.skipped}")
    if artifacts.exit_code != 0:
        errors.append(f"command exit code {artifacts.exit_code}")
    if artifacts.stats_exit_code not in (None, 0):
        errors.append(f"nsys stats exit code {artifacts.stats_exit_code}")
    if not errors:
        errors_text = "none"
    else:
        errors_text = "; ".join(errors)

    lines.append(f"- Saturation: {saturation}")
    lines.append(f"- Errors: {errors_text}")
    return lines


def _build_recommendation_lines(
    artifacts: ProfileArtifacts,
    report_sections: Iterable[str] | None = None,
) -> list[str]:
    reports = artifacts.reports
    sections = set(report_sections or DEFAULT_REPORT_SECTIONS)
    recommendations: list[str] = []

    api_report = _report(reports, "cuda_api_sum") if "api" in sections else _empty_report("cuda_api_sum")
    kernel_report = _report(reports, "cuda_gpu_kern_sum") if "kernels" in sections else _empty_report("cuda_gpu_kern_sum")
    mem_time_report = _report(reports, "cuda_gpu_mem_time_sum") if "transfers" in sections else _empty_report("cuda_gpu_mem_time_sum")

    if artifacts.exit_code != 0:
        recommendations.append("Fix the target command or profiler failure first; the rest of the profile may be incomplete.")
    elif artifacts.stats_exit_code not in (None, 0):
        recommendations.append("Fix the `nsys stats` failure first; the parsed summaries may be incomplete or missing.")

    if api_report.rows:
        top_api = _top_rows(api_report, 1)[0]
        name = top_api.get("Name", "")
        percent = _to_float(top_api.get("Time (%)")) or 0.0
        if name == "cudaMalloc" and percent >= 20.0:
            recommendations.append("Reuse device buffers or add a persistent workspace so allocation setup does not dominate each run.")
        elif "Memcpy" in name or "memcpy" in name:
            recommendations.append("Batch or eliminate host/device transfers; keeping tensors resident on device will likely matter more than kernel tuning.")

    if "kernels" in sections and not kernel_report.rows:
        recommendations.append("No GPU kernels were captured. Verify the target path is actually using CUDA work rather than a CPU fallback or setup-only path.")

    if "transfers" in sections and "kernels" in sections and mem_time_report.rows and kernel_report.rows:
        mem_ns = _report_total_ns(mem_time_report)
        kernel_ns = _report_total_ns(kernel_report)
        if mem_ns > kernel_ns * 1.2:
            recommendations.append("GPU memory transfer time exceeds kernel time. Focus on transfer volume, overlap, and batching before micro-optimizing kernels.")
        elif kernel_ns > mem_ns * 1.2:
            recommendations.append("Kernel time exceeds transfer time. Profile launch shape, occupancy, and math throughput next.")

    if not recommendations:
        recommendations.append("No single bottleneck dominated this run. Compare against another workload or collect hardware metrics for a sharper signal.")

    deduped: list[str] = []
    for item in recommendations:
        if item not in deduped:
            deduped.append(item)
    return deduped[:4]


def evaluate_policy_checks(
    artifacts: ProfileArtifacts,
    require_kernels: bool = False,
    max_api_time_pct: Iterable[tuple[str, float]] = (),
) -> list[PolicyCheck]:
    checks: list[PolicyCheck] = []
    kernel_report = _report(artifacts.reports, "cuda_gpu_kern_sum")
    if require_kernels:
        ok = bool(kernel_report.rows)
        checks.append(
            PolicyCheck(
                name="require-kernels",
                ok=ok,
                message=(
                    "GPU kernel activity was captured."
                    if ok
                    else "No GPU kernels were captured."
                ),
            )
        )

    api_report = _report(artifacts.reports, "cuda_api_sum")
    api_index = {row.get("Name", ""): row for row in api_report.rows}
    for api_name, limit in max_api_time_pct:
        row = api_index.get(api_name)
        if api_report.skipped:
            checks.append(
                PolicyCheck(
                    name=f"max-api-time-pct:{api_name}",
                    ok=False,
                    message=f"No CUDA API summary was available: {api_report.skipped}",
                )
            )
            continue
        if row is None:
            checks.append(
                PolicyCheck(
                    name=f"max-api-time-pct:{api_name}",
                    ok=False,
                    message=f"`{api_name}` was not present in the CUDA API summary.",
                )
            )
            continue
        actual = _to_float(row.get("Time (%)"))
        ok = actual is not None and actual <= limit
        actual_text = _fmt_pct(actual)
        checks.append(
            PolicyCheck(
                name=f"max-api-time-pct:{api_name}",
                ok=ok,
                message=(
                    f"`{api_name}` used {actual_text} CUDA API time (limit {_fmt_pct(limit)})."
                ),
            )
        )
    return checks


def _profiler_notes(artifacts: ProfileArtifacts) -> list[str]:
    notes: list[str] = []
    for stream in (artifacts.profile_stderr, artifacts.profile_stdout):
        for raw_line in stream.splitlines():
            line = raw_line.strip()
            if not line:
                continue
            lowered = line.lower()
            if any(token in lowered for token in ("warn", "error", "fail", "skip")):
                if line not in notes:
                    notes.append(line)
    return notes[:10]


def _render_table(headers: list[str], rows: list[list[str]]) -> list[str]:
    if not headers:
        return ["No data."]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return lines


def _api_table(report: StatsReport, limit: int) -> list[str]:
    if not report.rows:
        if report.skipped:
            return [f"No data. `{report.skipped}`"]
        return ["No data."]
    rows = []
    for row in _top_rows(report, limit):
        rows.append(
            [
                row.get("Name", "unknown"),
                row.get("Num Calls", row.get("Instances", "?")),
                _fmt_pct(_to_float(row.get("Time (%)"))),
                _fmt_ns(_to_float(row.get("Total Time (ns)"))),
                _fmt_ns(_to_float(row.get("Avg (ns)"))),
            ]
        )
    return _render_table(["API", "Calls", "Time %", "Total", "Avg"], rows)


def _kernel_table(report: StatsReport, limit: int) -> list[str]:
    if not report.rows:
        if report.skipped:
            return [f"No data. `{report.skipped}`"]
        return ["No data."]
    rows = []
    for row in _top_rows(report, limit):
        rows.append(
            [
                row.get("Name") or row.get("Kernel Name") or row.get("Operation") or "unknown",
                row.get("Instances", row.get("Num Calls", "?")),
                _fmt_pct(_to_float(row.get("Time (%)"))),
                _fmt_ns(_to_float(row.get("Total Time (ns)") or row.get("Total (ns)"))),
                _fmt_ns(_to_float(row.get("Avg (ns)"))),
            ]
        )
    return _render_table(["Kernel", "Instances", "Time %", "Total", "Avg"], rows)


def _transfer_rows(
    time_report: StatsReport,
    size_report: StatsReport,
    limit: int,
) -> list[list[str]]:
    if not time_report.rows and not size_report.rows:
        return []

    size_index: dict[str, dict[str, str]] = {}
    for row in size_report.rows:
        key = row.get("Name") or row.get("Operation") or ""
        if key:
            size_index[key] = row

    rows = []
    for row in _top_rows(time_report, limit):
        name = row.get("Name") or row.get("Operation") or "unknown"
        size_row = size_index.get(name, {})
        rows.append(
            [
                _transfer_kind(name),
                name,
                row.get("Count", row.get("Instances", row.get("Num Calls", "?"))),
                _fmt_ns(_to_float(row.get("Total Time (ns)") or row.get("Total (ns)"))),
                _fmt_bytes(
                    _to_float(
                        size_row.get("Total Size (bytes)")
                        or size_row.get("Size (bytes)")
                        or size_row.get("Total Bytes")
                        or size_row.get("Bytes")
                    )
                ),
            ]
        )
    return rows


def render_markdown(
    artifacts: ProfileArtifacts,
    top: int = 5,
    policy_checks: list[PolicyCheck] | None = None,
    report_sections: Iterable[str] | None = None,
) -> str:
    policy_checks = policy_checks or []
    sections = tuple(report_sections or DEFAULT_REPORT_SECTIONS)
    quoted = shlex.join(artifacts.command)
    lines = [
        "# CUDA Profile Report",
        "",
        f"- Overall status: `{overall_status(artifacts, policy_checks)}`",
        f"- Generated: `{artifacts.generated_at}`",
        f"- Command: `{quoted}`",
        f"- Exit code: `{artifacts.exit_code}`",
        f"- Stats exit code: `{artifacts.stats_exit_code if artifacts.stats_exit_code is not None else 'n/a'}`",
        f"- Wall time: `{artifacts.wall_time_s:.3f} s`",
        f"- Artifact prefix: `{artifacts.prefix}`",
        f"- Nsight report: `{artifacts.rep_path}`",
        f"- Report sections: `{', '.join(sections)}`",
    ]
    if artifacts.sqlite_path is not None:
        lines.append(f"- SQLite export: `{artifacts.sqlite_path}`")

    lines.extend(
        [
            "",
            "## Executive Summary",
            "",
        ]
    )
    for item in _build_summary_lines(artifacts, report_sections=sections):
        lines.append(f"- {item}")

    lines.extend(
        [
            "",
            "## USE Heuristics",
            "",
        ]
    )
    lines.extend(_build_use_lines(artifacts, report_sections=sections))

    lines.extend(["", "## Recommendations", ""])
    for item in _build_recommendation_lines(artifacts, report_sections=sections):
        lines.append(f"- {item}")

    if policy_checks:
        lines.extend(["", "## Policy Checks", ""])
        for check in policy_checks:
            status = "PASS" if check.ok else "FAIL"
            lines.append(f"- [{status}] `{check.name}`: {check.message}")

    profiler_notes = _profiler_notes(artifacts)
    if profiler_notes:
        lines.extend(["", "## Profiler Notes", ""])
        for note in profiler_notes:
            lines.append(f"- {note}")

    if "api" in sections:
        lines.extend(["", "## CUDA API Hotspots", ""])
        lines.extend(_api_table(_report(artifacts.reports, "cuda_api_sum"), top))

    if "kernels" in sections:
        lines.extend(["", "## GPU Kernels", ""])
        lines.extend(
            _kernel_table(_report(artifacts.reports, "cuda_gpu_kern_sum"), top)
        )

    if "transfers" in sections:
        lines.extend(["", "## Device Transfers", ""])
        transfer_table = _transfer_rows(
            _report(artifacts.reports, "cuda_gpu_mem_time_sum"),
            _report(artifacts.reports, "cuda_gpu_mem_size_sum"),
            top,
        )
        if transfer_table:
            lines.extend(
                _render_table(["Kind", "Operation", "Count", "Total Time", "Total Size"], transfer_table)
            )
        else:
            mem_time = _report(artifacts.reports, "cuda_gpu_mem_time_sum")
            if mem_time.skipped:
                lines.append(f"No data. `{mem_time.skipped}`")
            else:
                lines.append("No data.")

    return "\n".join(lines) + "\n"


def profile_command(
    command: list[str],
    prefix: Path,
    nsys_path: str,
    cwd: Path | None = None,
    trace: str = "cuda,nvtx,osrt",
    sample: str = "none",
    keep_sqlite: bool = False,
    report_names: Iterable[str] = DEFAULT_REPORTS,
    timeout_s: float | None = None,
    stats_timeout_s: float | None = None,
) -> ProfileArtifacts:
    selected_reports = tuple(report_names)
    if not selected_reports:
        raise ValueError("at least one Nsight report must be selected")
    artifact_prefix = _artifact_path(prefix, cwd)
    artifact_prefix.parent.mkdir(parents=True, exist_ok=True)
    _cleanup_old_artifacts(artifact_prefix)

    profile_cmd = [
        nsys_path,
        "profile",
        "--force-overwrite=true",
        "--trace",
        trace,
        "--sample",
        sample,
        "-o",
        str(prefix),
        *command,
    ]
    started = time.perf_counter()
    profile = _run(profile_cmd, cwd=cwd, timeout_s=timeout_s)
    wall_time_s = time.perf_counter() - started

    rep_path = artifact_prefix.with_suffix(".nsys-rep")
    sqlite_path = artifact_prefix.with_suffix(".sqlite")
    reports: dict[str, StatsReport] = {}
    stats_exit_code: int | None = None
    if rep_path.exists():
        stats = _run(
            [
                nsys_path,
                "stats",
                "--force-export=true",
                "--format",
                "csv",
                "--report",
                ",".join(selected_reports),
                str(rep_path),
            ],
            cwd=cwd,
            timeout_s=stats_timeout_s,
        )
        stats_exit_code = stats.returncode
        output = (stats.stdout or "") + (stats.stderr or "")
        reports = parse_nsys_stats_bundle(selected_reports, output)
        for report_name in selected_reports:
            report = reports.get(report_name, _empty_report(report_name))
            if stats.returncode != 0 and not report.skipped and not report.rows:
                report.skipped = f"nsys stats failed with exit code {stats.returncode}"
            reports[report_name] = report
    else:
        failure = f"nsys profile did not produce `{rep_path}` (exit code {profile.returncode})"
        for report_name in selected_reports:
            reports[report_name] = _empty_report(report_name, skipped=failure)

    if not keep_sqlite and sqlite_path.exists():
        sqlite_path.unlink()
        sqlite_path = None

    return ProfileArtifacts(
        command=command,
        exit_code=profile.returncode,
        stats_exit_code=stats_exit_code,
        wall_time_s=wall_time_s,
        generated_at=datetime.now(timezone.utc).isoformat(),
        prefix=artifact_prefix,
        rep_path=rep_path,
        sqlite_path=sqlite_path if sqlite_path and sqlite_path.exists() else sqlite_path,
        reports=reports,
        profile_stdout=profile.stdout or "",
        profile_stderr=profile.stderr or "",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run Nsight Systems on a command and emit a Markdown CUDA report."
    )
    parser.add_argument("--out", type=Path, default=None, help="Markdown output path")
    parser.add_argument(
        "--latest-link",
        type=Path,
        default=None,
        help="Update this path to point at the newest markdown report; sibling .nsys-rep/.sqlite links are updated too.",
    )
    parser.add_argument(
        "--prefix",
        type=Path,
        default=None,
        help="Output prefix for .nsys-rep artifacts (defaults to a timestamped prefix in cwd).",
    )
    parser.add_argument("--cwd", type=Path, default=None, help="Run command from this directory")
    parser.add_argument("--nsys", default=None, help="Path to nsys binary")
    parser.add_argument("--trace", default="cuda,nvtx,osrt", help="Nsight trace domains")
    parser.add_argument("--sample", default="none", help="Nsight sampling mode")
    parser.add_argument(
        "--timeout",
        type=_positive_float,
        default=None,
        help="Maximum seconds to allow `nsys profile` to run.",
    )
    parser.add_argument(
        "--stats-timeout",
        type=_positive_float,
        default=None,
        help="Maximum seconds to allow `nsys stats` to run.",
    )
    parser.add_argument(
        "--report",
        action="append",
        type=_report_section,
        default=[],
        metavar="SECTION",
        help="Sections to collect/render: api, kernels, transfers, all. Repeatable.",
    )
    parser.add_argument(
        "--top",
        type=_positive_int,
        default=5,
        help="Maximum number of rows to show in each summary table.",
    )
    parser.add_argument(
        "--require-kernels",
        action="store_true",
        help="Fail if no GPU kernel activity is captured in the profile.",
    )
    parser.add_argument(
        "--max-api-time-pct",
        action="append",
        type=_api_pct_limit,
        default=[],
        metavar="NAME=PERCENT",
        help="Fail if a CUDA API exceeds this percentage of traced CUDA API time. Repeatable.",
    )
    parser.add_argument(
        "--keep-sqlite",
        action="store_true",
        help="Keep the generated .sqlite export instead of deleting it after stats extraction.",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run after --")
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)

    if not args.command or args.command[0] != "--":
        raise SystemExit("Usage: cuda-prof-report [options] -- <command>")
    command = args.command[1:]
    if not command:
        raise SystemExit("No command provided after --")

    cwd = _normalize_path(args.cwd)
    raw_out_path = _normalize_path(args.out)
    out_path = _artifact_path(raw_out_path, cwd) if raw_out_path is not None else None
    raw_latest_link = _normalize_path(args.latest_link)
    latest_link = _artifact_path(raw_latest_link, cwd) if raw_latest_link is not None else None
    if latest_link is not None and out_path is None:
        raise SystemExit("--latest-link requires --out")
    prefix = _normalize_path(args.prefix) or _default_prefix_path(out_path)
    nsys_arg = str(_normalize_path(Path(args.nsys))) if args.nsys else None
    report_sections = _resolve_report_sections(
        args.report,
        require_kernels=args.require_kernels,
        max_api_time_pct=args.max_api_time_pct,
    )
    report_names = _resolve_internal_reports(report_sections)

    nsys_path = _find_nsys(nsys_arg)
    try:
        artifacts = profile_command(
            command=command,
            prefix=prefix,
            nsys_path=nsys_path,
            cwd=cwd,
            trace=args.trace,
            sample=args.sample,
            keep_sqlite=args.keep_sqlite,
            report_names=report_names,
            timeout_s=args.timeout,
            stats_timeout_s=args.stats_timeout,
        )
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc
    policy_checks = evaluate_policy_checks(
        artifacts,
        require_kernels=args.require_kernels,
        max_api_time_pct=args.max_api_time_pct,
    )
    markdown = render_markdown(
        artifacts,
        top=args.top,
        policy_checks=policy_checks,
        report_sections=report_sections,
    )

    if out_path:
        try:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(markdown)
        except OSError as exc:
            detail = exc.strerror or str(exc)
            raise SystemExit(f"failed to write report to {out_path}: {detail}") from exc
        try:
            _update_latest_links(out_path, artifacts, latest_link)
        except OSError as exc:
            detail = exc.strerror or str(exc)
            raise SystemExit(f"wrote report to {out_path} but failed to update latest link: {detail}") from exc
        print(f"Wrote CUDA profile report to {out_path} {_status_summary(artifacts, policy_checks)}")
        for line in _cli_followup_lines(artifacts, policy_checks, report_sections=report_sections):
            print(line)
        if latest_link is not None:
            print(f"  - latest: {latest_link}")
    else:
        print(markdown)
    if artifacts.exit_code != 0:
        return artifacts.exit_code
    if artifacts.stats_exit_code not in (None, 0):
        return artifacts.stats_exit_code
    if any(not check.ok for check in policy_checks):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
