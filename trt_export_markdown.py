#!/usr/bin/env python3
"""Render CuteChronos export/TensorRT JSON reports as Markdown."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _fmt_bool(value: Any) -> str:
    if value is True:
        return "yes"
    if value is False:
        return "no"
    return "unknown"


def _append(lines: list[str], text: str = "") -> None:
    lines.append(text)


def _render_key_values(lines: list[str], mapping: dict[str, Any]) -> None:
    for key, value in mapping.items():
        _append(lines, f"- {key}: `{value}`")


def _render_recommendations(report: dict[str, Any]) -> list[str]:
    recs: list[str] = []
    dynamo = report.get("dynamo_explain", {})
    onnx_export = report.get("onnx_export", {})
    tensorrt = report.get("tensorrt", {})
    env = report.get("environment", {})

    if not env.get("onnx_installed", False):
        recs.append("Install `onnx` in the export environment before retrying.")
    if not env.get("onnxscript_installed", False):
        recs.append("Install `onnxscript` if you want the newer dynamo-based ONNX exporter to run.")
    if dynamo.get("graph_break_count", 0):
        recs.append(
            f"`torch.compile` still sees `{dynamo['graph_break_count']}` graph breaks. "
            "Use the break reasons below to decide whether fullgraph work is worth it."
        )
    if report.get("torch_export", {}).get("export_mode") == "static":
        recs.append("`torch.export` succeeded only for the fixed sample shape; dynamic export still needs more shape cleanup.")
    torch_export_error = str(report.get("torch_export", {}).get("error", ""))
    if "Constraints violated" in torch_export_error:
        recs.append("Dynamic export currently wants context lengths constrained to patch-size multiples.")
    if not onnx_export.get("success", False):
        recs.append("ONNX export failed. Fix that first before spending time on TensorRT.")
    onnx_error = str(onnx_export.get("error", "")).lower()
    if "nanmean" in onnx_error:
        recs.append("Current ONNX blocker is `aten::nanmean` in Chronos preprocessing/normalization.")
    if "asinh" in onnx_error:
        recs.append("Current ONNX blocker is `aten::asinh`; replacing or decomposing arcsinh is the next export step.")
    if tensorrt.get("requested") and tensorrt.get("available") is False:
        recs.append("Install `tensorrt` on the target GPU machine, then rerun with `--build-engine`.")
    if onnx_export.get("success", False) and not tensorrt.get("requested"):
        recs.append("Next step: run the same export on the GPU host with `--build-engine --fp16`.")
    if not recs:
        recs.append("No obvious blockers were detected in the exported report.")
    return recs


def render_markdown(report: dict[str, Any]) -> str:
    lines: list[str] = []
    _append(lines, "# TensorRT Export Report")
    _append(lines)
    _append(lines, "## Summary")
    _append(lines, f"- model_path: `{report.get('model_path')}`")
    _append(lines, f"- resolved_model_path: `{report.get('resolved_model_path')}`")
    _append(lines, f"- device: `{report.get('device')}`")
    _append(lines, f"- dtype: `{report.get('dtype')}`")
    _append(lines, f"- batch_size: `{report.get('batch_size')}`")
    _append(lines, f"- context_length: `{report.get('context_length')}`")
    _append(lines, f"- num_output_patches: `{report.get('num_output_patches')}`")

    dynamo = report.get("dynamo_explain", {})
    _append(lines, f"- dynamo_graph_breaks: `{dynamo.get('graph_break_count', 'unknown')}`")

    onnx_export = report.get("onnx_export", {})
    _append(lines, f"- onnx_export_success: `{_fmt_bool(onnx_export.get('success'))}`")
    if onnx_export.get("path"):
        _append(lines, f"- onnx_path: `{onnx_export['path']}`")

    tensorrt = report.get("tensorrt", {})
    _append(lines, f"- tensorrt_requested: `{_fmt_bool(tensorrt.get('requested'))}`")
    _append(lines, f"- tensorrt_built: `{_fmt_bool(tensorrt.get('built'))}`")
    if tensorrt.get("path"):
        _append(lines, f"- tensorrt_plan: `{tensorrt['path']}`")

    _append(lines)
    _append(lines, "## Environment")
    _render_key_values(lines, report.get("environment", {}))

    _append(lines)
    _append(lines, "## Export Backends")
    _render_key_values(lines, report.get("backend_overrides", {}))

    _append(lines)
    _append(lines, "## torch._dynamo")
    if dynamo.get("available") is False:
        _append(lines, f"- unavailable: `{dynamo.get('reason', 'unknown')}`")
    else:
        _append(lines, f"- graph_count: `{dynamo.get('graph_count', 'unknown')}`")
        _append(lines, f"- graph_break_count: `{dynamo.get('graph_break_count', 'unknown')}`")
        _append(lines, f"- op_count: `{dynamo.get('op_count', 'unknown')}`")
        for idx, reason in enumerate(dynamo.get("break_reasons", []), start=1):
            _append(lines, f"- break_{idx}: `{reason.get('reason', 'unknown')}`")
        if dynamo.get("error"):
            _append(lines, f"- error: `{dynamo['error']}`")

    _append(lines)
    _append(lines, "## torch.export")
    torch_export = report.get("torch_export", {})
    _append(lines, f"- available: `{_fmt_bool(torch_export.get('available'))}`")
    _append(lines, f"- success: `{_fmt_bool(torch_export.get('success'))}`")
    if torch_export.get("export_mode"):
        _append(lines, f"- export_mode: `{torch_export['export_mode']}`")
    if torch_export.get("node_count") is not None:
        _append(lines, f"- node_count: `{torch_export['node_count']}`")
    for item in torch_export.get("call_function_ops", [])[:10]:
        _append(lines, f"- op `{item['name']}`: `{item['count']}`")
    if torch_export.get("error"):
        _append(lines, f"- error: `{torch_export['error']}`")
    if torch_export.get("dynamic_export_error"):
        _append(lines, f"- dynamic_export_error: `{torch_export['dynamic_export_error']}`")

    _append(lines)
    _append(lines, "## ONNX")
    _append(lines, f"- success: `{_fmt_bool(onnx_export.get('success'))}`")
    if onnx_export.get("elapsed_ms") is not None:
        _append(lines, f"- export_ms: `{onnx_export['elapsed_ms']:.2f}`")
    if onnx_export.get("size_bytes") is not None:
        _append(lines, f"- size_bytes: `{onnx_export['size_bytes']}`")
    if onnx_export.get("node_count") is not None:
        _append(lines, f"- node_count: `{onnx_export['node_count']}`")
    for item in onnx_export.get("op_histogram", [])[:10]:
        _append(lines, f"- op `{item['name']}`: `{item['count']}`")
    if onnx_export.get("error"):
        _append(lines, f"- error: `{onnx_export['error']}`")

    _append(lines)
    _append(lines, "## TensorRT")
    _append(lines, f"- requested: `{_fmt_bool(tensorrt.get('requested'))}`")
    _append(lines, f"- available: `{_fmt_bool(tensorrt.get('available'))}`")
    _append(lines, f"- built: `{_fmt_bool(tensorrt.get('built'))}`")
    if tensorrt.get("elapsed_ms") is not None:
        _append(lines, f"- build_ms: `{tensorrt['elapsed_ms']:.2f}`")
    if tensorrt.get("profiles"):
        _append(lines, f"- profile: `{json.dumps(tensorrt['profiles'])}`")
    for err in tensorrt.get("parse_errors", [])[:10]:
        _append(lines, f"- parse_error: `{err}`")
    if tensorrt.get("error"):
        _append(lines, f"- error: `{tensorrt['error']}`")
    if tensorrt.get("reason"):
        _append(lines, f"- reason: `{tensorrt['reason']}`")

    _append(lines)
    _append(lines, "## Recommendations")
    for rec in _render_recommendations(report):
        _append(lines, f"- {rec}")

    _append(lines)
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render TensorRT export JSON to Markdown")
    parser.add_argument("json_path", type=Path)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = json.loads(args.json_path.read_text())
    markdown = render_markdown(report)
    if args.output:
        args.output.write_text(markdown)
    else:
        print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
