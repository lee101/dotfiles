#!/usr/bin/env python3
"""Run native CPU and heap profilers and emit a compact Markdown report."""

from __future__ import annotations

import argparse
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


CALLGRIND_ROW_RE = re.compile(
    r"^\s*([\d,]+)\s+\(\s*([\d.]+)%\)\s+(.*?)(?:\s+\[(.+?)\])?\s*$"
)
SOURCE_ROW_RE = re.compile(r"^\s*([.,0-9]+)\s*(?:\(\s*([\d.]+)%\))?\s{2,}(.*)$")
MASSIF_NODE_RE = re.compile(r"^( +)n\d+:\s+(\d+)\s+(.*)$")
ADDR_PREFIX_RE = re.compile(r"^0x[0-9A-Fa-f]+:\s*")


@dataclass
class CommandRun:
    argv: list[str]
    exit_code: int
    wall_time_s: float
    stdout: str
    stderr: str


@dataclass
class CallgrindRow:
    ir: int
    pct: float
    location: str
    binary: str | None


@dataclass
class SourceHotspot:
    line_no: int
    ir: int
    pct: float
    code: str


@dataclass
class MassifAllocation:
    size_bytes: int
    stack_summary: str


@dataclass
class MassifSummary:
    peak_snapshot: int
    peak_total_bytes: int
    peak_heap_bytes: int
    peak_extra_bytes: int
    peak_stack_bytes: int
    allocations: list[MassifAllocation]


@dataclass
class ProfileArtifacts:
    command: list[str]
    callgrind_run: CommandRun
    massif_run: CommandRun
    callgrind_out: Path
    massif_out: Path
    callgrind_rows: list[CallgrindRow]
    user_callgrind_rows: list[CallgrindRow]
    source_hotspots: dict[Path, list[SourceHotspot]]
    massif_summary: MassifSummary
    notes: list[str]


def _default_prefix() -> str:
    return datetime.now(timezone.utc).strftime("native_profile_%Y%m%d_%H%M%S")


def _bytes_to_mb(value: int) -> float:
    return value / (1024 * 1024)


def _find_executable(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"{name} not found in PATH; install it first.")
    return path


def _run(cmd: list[str], timeout_s: float) -> CommandRun:
    started = time.perf_counter()
    completed = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout_s,
        check=False,
    )
    return CommandRun(
        argv=cmd,
        exit_code=completed.returncode,
        wall_time_s=time.perf_counter() - started,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


def _parse_callgrind_rows(text: str, top_n: int) -> list[CallgrindRow]:
    rows: list[CallgrindRow] = []
    in_table = False
    for line in text.splitlines():
        if "file:function" in line:
            in_table = True
            continue
        if not in_table:
            continue
        if line.startswith("-- User-annotated source:") or line.startswith("-- Auto-annotated source:"):
            break
        match = CALLGRIND_ROW_RE.match(line)
        if not match:
            continue
        location = match.group(3).strip()
        if location == "PROGRAM TOTALS":
            continue
        rows.append(
            CallgrindRow(
                ir=int(match.group(1).replace(",", "")),
                pct=float(match.group(2)),
                location=location,
                binary=match.group(4),
            )
        )
    return rows[:top_n]


def _split_sections(text: str) -> list[tuple[str, list[str]]]:
    sections: list[tuple[str, list[str]]] = []
    lines = text.splitlines()
    idx = 0
    while idx < len(lines):
        line = lines[idx]
        if line.startswith("-- User-annotated source: ") or line.startswith("-- Auto-annotated source: "):
            source_path = line.split(": ", 1)[1].strip()
            idx += 1
            section_lines: list[str] = []
            while idx < len(lines):
                current = lines[idx]
                if current.startswith("--------------------------------------------------------------------------------") and (
                    idx + 1 >= len(lines) or lines[idx + 1].startswith("-- ")
                ):
                    break
                section_lines.append(current)
                idx += 1
            sections.append((source_path, section_lines))
            continue
        idx += 1
    return sections


def _parse_source_hotspots(text: str, requested_sources: list[Path], top_n: int) -> dict[Path, list[SourceHotspot]]:
    source_map = {path.resolve(): path for path in requested_sources}
    parsed: dict[Path, list[SourceHotspot]] = {path: [] for path in requested_sources}
    sections = _split_sections(text)
    for raw_path, section_lines in sections:
        resolved = Path(raw_path).resolve()
        source_path = source_map.get(resolved)
        if source_path is None or not source_path.exists():
            continue

        source_lines = source_path.read_text().splitlines()
        cursor = 0
        hits: list[SourceHotspot] = []

        for raw_line in section_lines:
            if raw_line.startswith("-- line "):
                try:
                    cursor = int(raw_line.split()[2]) - 1
                except (IndexError, ValueError):
                    continue
                continue
            match = SOURCE_ROW_RE.match(raw_line)
            if not match:
                continue
            code = match.group(3)
            if code.startswith("=>"):
                continue
            if cursor >= len(source_lines):
                break
            count_token = match.group(1)
            pct_token = match.group(2)
            line_no = cursor + 1
            cursor += 1
            if count_token == ".":
                continue
            ir = int(count_token.replace(",", ""))
            if ir == 0:
                continue
            hits.append(
                SourceHotspot(
                    line_no=line_no,
                    ir=ir,
                    pct=float(pct_token or 0.0),
                    code=source_lines[line_no - 1].rstrip(),
                )
            )

        hits.sort(key=lambda item: item.ir, reverse=True)
        if hits or not parsed[source_path]:
            parsed[source_path] = hits[:top_n]

    return parsed


def _is_user_binary(binary: str | None, roots: list[Path]) -> bool:
    if not binary:
        return False
    try:
        resolved = Path(binary).resolve()
    except OSError:
        return False
    return any(root == resolved or root in resolved.parents for root in roots)


def _is_actionable_user_row(row: CallgrindRow, roots: list[Path]) -> bool:
    if not _is_user_binary(row.binary, roots):
        return False
    if row.location.startswith("???:(below main)"):
        return False
    if row.location.startswith("???:0x"):
        return False
    return True


def _clean_frame_name(raw: str) -> str:
    cleaned = ADDR_PREFIX_RE.sub("", raw).strip()
    cleaned = re.sub(r"\s+\(in [^)]+\)$", "", cleaned)
    return cleaned.strip()


def _summarize_massif_frames(frames: list[str], roots: list[Path]) -> str:
    preferred: list[str] = []
    fallback: list[str] = []
    for frame in frames:
        if "all below massif's threshold" in frame:
            continue
        name = _clean_frame_name(frame)
        if not name or name == "???":
            continue
        fallback.append(name)
        resolved = None
        match = re.search(r"\(in ([^)]+)\)", frame)
        if match:
            try:
                resolved = Path(match.group(1)).resolve()
            except OSError:
                resolved = None
        if resolved is not None and any(root == resolved or root in resolved.parents for root in roots):
            preferred.append(name)
        elif re.search(r"\([^)]+:\d+\)$", frame):
            preferred.append(name)
    chosen = preferred[:4] if preferred else fallback[:4]
    return " -> ".join(chosen) if chosen else "unknown"


def _parse_massif_summary(path: Path, top_n: int, roots: list[Path]) -> MassifSummary:
    lines = path.read_text().splitlines()
    snapshots: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    idx = 0
    while idx < len(lines):
        line = lines[idx]
        if line.startswith("snapshot="):
            if current is not None:
                snapshots.append(current)
            current = {
                "snapshot": int(line.split("=", 1)[1]),
                "mem_heap_B": 0,
                "mem_heap_extra_B": 0,
                "mem_stacks_B": 0,
                "tree_lines": [],
            }
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            if key in {"mem_heap_B", "mem_heap_extra_B", "mem_stacks_B"}:
                current[key] = int(value)
            elif key == "heap_tree" and value == "detailed":
                idx += 1
                tree_lines = current["tree_lines"]
                while idx < len(lines) and not lines[idx].startswith("#-----------"):
                    tree_lines.append(lines[idx])
                    idx += 1
                continue
        idx += 1
    if current is not None:
        snapshots.append(current)
    if not snapshots:
        raise SystemExit(f"No Massif snapshots found in {path}")

    peak = max(
        snapshots,
        key=lambda snap: int(snap["mem_heap_B"]) + int(snap["mem_heap_extra_B"]) + int(snap["mem_stacks_B"]),
    )
    if not peak["tree_lines"]:
        detailed_snapshots = [snap for snap in snapshots if snap["tree_lines"]]
        if detailed_snapshots:
            peak = max(
                detailed_snapshots,
                key=lambda snap: int(snap["mem_heap_B"]) + int(snap["mem_heap_extra_B"]) + int(snap["mem_stacks_B"]),
            )
    peak_total = int(peak["mem_heap_B"]) + int(peak["mem_heap_extra_B"]) + int(peak["mem_stacks_B"])
    tree_lines = peak["tree_lines"]

    allocations: list[MassifAllocation] = []
    current_size = 0
    current_frames: list[str] = []
    for line in tree_lines:
        match = MASSIF_NODE_RE.match(line)
        if not match:
            continue
        indent = len(match.group(1))
        size = int(match.group(2))
        frame = match.group(3)
        if indent == 1:
            if current_frames:
                allocations.append(
                    MassifAllocation(
                        size_bytes=current_size,
                        stack_summary=_summarize_massif_frames(current_frames, roots),
                    )
                )
            current_size = size
            current_frames = [frame]
        elif indent > 1 and current_frames:
            current_frames.append(frame)
    if current_frames:
        allocations.append(
            MassifAllocation(
                size_bytes=current_size,
                stack_summary=_summarize_massif_frames(current_frames, roots),
            )
        )

    allocations.sort(key=lambda item: item.size_bytes, reverse=True)
    return MassifSummary(
        peak_snapshot=int(peak["snapshot"]),
        peak_total_bytes=peak_total,
        peak_heap_bytes=int(peak["mem_heap_B"]),
        peak_extra_bytes=int(peak["mem_heap_extra_B"]),
        peak_stack_bytes=int(peak["mem_stacks_B"]),
        allocations=allocations[:top_n],
    )


def render_markdown(artifacts: ProfileArtifacts, cwd: Path) -> str:
    lines = [
        "# Native Profile Report",
        "",
        f"- Command: `{' '.join(shlex.quote(part) for part in artifacts.command)}`",
        f"- Callgrind exit: `{artifacts.callgrind_run.exit_code}` in `{artifacts.callgrind_run.wall_time_s:.2f}s`",
        f"- Massif exit: `{artifacts.massif_run.exit_code}` in `{artifacts.massif_run.wall_time_s:.2f}s`",
        f"- Callgrind data: `{artifacts.callgrind_out}`",
        f"- Massif data: `{artifacts.massif_out}`",
        "",
        "## CPU Hotspots",
        "",
        "| Ir | % | Location | Binary |",
        "| ---: | ---: | --- | --- |",
    ]
    for row in artifacts.user_callgrind_rows or artifacts.callgrind_rows:
        lines.append(
            f"| {row.ir:,} | {row.pct:.2f} | `{row.location}` | `{row.binary or '-'}` |"
        )
    lines.extend(
        [
            "",
            "## Heap Peak",
            "",
            f"- Peak total: `{_bytes_to_mb(artifacts.massif_summary.peak_total_bytes):.2f} MB`",
            f"- Heap bytes: `{_bytes_to_mb(artifacts.massif_summary.peak_heap_bytes):.2f} MB`",
            f"- Extra heap bytes: `{_bytes_to_mb(artifacts.massif_summary.peak_extra_bytes):.2f} MB`",
            f"- Stack bytes: `{_bytes_to_mb(artifacts.massif_summary.peak_stack_bytes):.2f} MB`",
            f"- Peak snapshot: `{artifacts.massif_summary.peak_snapshot}`",
            "",
            "| Bytes | % Peak | Stack |",
            "| ---: | ---: | --- |",
        ]
    )
    for allocation in artifacts.massif_summary.allocations:
        pct = (allocation.size_bytes / artifacts.massif_summary.peak_total_bytes * 100.0) if artifacts.massif_summary.peak_total_bytes else 0.0
        lines.append(
            f"| {allocation.size_bytes:,} | {pct:.2f} | `{allocation.stack_summary}` |"
        )

    if artifacts.source_hotspots:
        lines.extend(["", "## Source Hotspots", ""])
        for source_path, hotspots in artifacts.source_hotspots.items():
            rel_path = source_path
            try:
                rel_path = source_path.resolve().relative_to(cwd.resolve())
            except ValueError:
                rel_path = source_path
            lines.append(f"### `{rel_path}`")
            lines.append("")
            if not hotspots:
                lines.append("- No source line attribution. Rebuild with debug info, e.g. `cmake --preset prof`.")
                lines.append("")
                continue
            lines.append("| Line | Ir | % | Code |")
            lines.append("| ---: | ---: | ---: | --- |")
            for hotspot in hotspots:
                code = hotspot.code.replace("|", "\\|").strip()
                lines.append(
                    f"| {hotspot.line_no} | {hotspot.ir:,} | {hotspot.pct:.2f} | `{code}` |"
                )
            lines.append("")

    lines.extend(
        [
            "## Notes",
            "",
            "- CPU line attribution comes from `callgrind_annotate` source annotations.",
            "- Exact per-line heap attribution is not available here; the heap section reports peak allocation stacks instead.",
        ]
    )
    for note in artifacts.notes:
        lines.append(f"- {note}")
    lines.append("")
    return "\n".join(lines)


def profile_command(
    command: list[str],
    prefix: Path,
    top_n: int,
    source_files: list[Path],
    callgrind_timeout_s: float,
    massif_timeout_s: float,
) -> ProfileArtifacts:
    valgrind = _find_executable("valgrind")
    callgrind_annotate = _find_executable("callgrind_annotate")

    prefix.parent.mkdir(parents=True, exist_ok=True)
    callgrind_out = prefix.with_suffix(".callgrind.out")
    massif_out = prefix.with_suffix(".massif.out")

    callgrind_run = _run(
        [valgrind, "--tool=callgrind", f"--callgrind-out-file={callgrind_out}", *command],
        timeout_s=callgrind_timeout_s,
    )
    massif_run = _run(
        [valgrind, "--tool=massif", f"--massif-out-file={massif_out}", *command],
        timeout_s=massif_timeout_s,
    )

    annotate_run = _run(
        [
            callgrind_annotate,
            "--auto=yes",
            "--inclusive=yes",
            str(callgrind_out),
            *[str(path) for path in source_files],
        ],
        timeout_s=max(callgrind_timeout_s, 1.0),
    )
    if annotate_run.exit_code != 0:
        raise SystemExit(f"callgrind_annotate failed:\n{annotate_run.stderr}")

    cwd = Path.cwd().resolve()
    roots = [cwd]
    if command and Path(command[0]).exists():
        try:
            roots.append(Path(command[0]).resolve().parent)
        except OSError:
            pass

    callgrind_rows = _parse_callgrind_rows(annotate_run.stdout, top_n=top_n * 20)
    user_rows = [row for row in callgrind_rows if _is_actionable_user_row(row, roots)][:top_n]
    if not user_rows:
        user_rows = [row for row in callgrind_rows if _is_user_binary(row.binary, roots)][:top_n]
    source_hotspots = _parse_source_hotspots(annotate_run.stdout, source_files, top_n=top_n)
    massif_summary = _parse_massif_summary(massif_out, top_n=top_n, roots=roots)

    notes: list[str] = []
    if not user_rows:
        notes.append("No in-repo CPU hotspots were detected ahead of loader and system-library work.")
    if any(not hits for hits in source_hotspots.values()):
        notes.append("Source annotations depend on debug info and may drop lines in stripped or highly optimized builds.")

    return ProfileArtifacts(
        command=command,
        callgrind_run=callgrind_run,
        massif_run=massif_run,
        callgrind_out=callgrind_out,
        massif_out=massif_out,
        callgrind_rows=callgrind_rows[:top_n],
        user_callgrind_rows=user_rows,
        source_hotspots=source_hotspots,
        massif_summary=massif_summary,
        notes=notes,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run callgrind and massif on a native command and emit a Markdown report."
    )
    parser.add_argument("--out", type=Path, default=None, help="Markdown output path")
    parser.add_argument(
        "--prefix",
        type=Path,
        default=None,
        help="Artifact prefix for generated profiler files",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=10,
        help="Number of rows to keep per section",
    )
    parser.add_argument(
        "--source-file",
        action="append",
        default=[],
        help="Source file to annotate with line-level CPU counts",
    )
    parser.add_argument(
        "--callgrind-timeout",
        type=float,
        default=120.0,
        help="Timeout in seconds for the callgrind run",
    )
    parser.add_argument(
        "--massif-timeout",
        type=float,
        default=120.0,
        help="Timeout in seconds for the massif run",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run after --")
    args = parser.parse_args()

    if not args.command or args.command[0] != "--":
        raise SystemExit("Usage: native-prof-report [options] -- <command>")
    command = args.command[1:]
    if not command:
        raise SystemExit("No command provided after --")

    source_files = [Path(item).expanduser().resolve() for item in args.source_file]
    prefix = (args.prefix.expanduser() if args.prefix else Path(_default_prefix())).resolve()
    if args.out is not None and args.prefix is None:
        prefix = args.out.expanduser().resolve().with_suffix("")

    artifacts = profile_command(
        command=command,
        prefix=prefix,
        top_n=args.top,
        source_files=source_files,
        callgrind_timeout_s=args.callgrind_timeout,
        massif_timeout_s=args.massif_timeout,
    )
    markdown = render_markdown(artifacts, cwd=Path.cwd())

    if args.out is not None:
        args.out.expanduser().write_text(markdown)
        print(f"Wrote markdown report to {args.out}")
    else:
        print(markdown)


if __name__ == "__main__":
    main()
