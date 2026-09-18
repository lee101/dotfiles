#!/usr/bin/env python3
"""Render a standalone SVG flamegraph from a Go CPU pprof profile."""

from __future__ import annotations

import argparse
import hashlib
import html
import re
import subprocess
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path


SAMPLE_RE = re.compile(r"^\s+(\d+(?:\.\d+)?)(ns|us|ms|s)\s+(.+?)\s*$")
UNIT_NS = {"ns": 1.0, "us": 1_000.0, "ms": 1_000_000.0, "s": 1_000_000_000.0}


def _parse_trace_output(text: str) -> dict[tuple[str, ...], float]:
	stacks: dict[tuple[str, ...], float] = defaultdict(float)
	weight = 0.0
	frames: list[str] = []

	def flush() -> None:
		nonlocal weight, frames
		if weight > 0 and frames:
			# pprof prints leaf first; flamegraphs conventionally put the root first.
			stacks[tuple(reversed(frames))] += weight
		weight = 0.0
		frames = []

	for line in text.splitlines():
		if line.startswith("-----------+"):
			flush()
			continue
		match = SAMPLE_RE.match(line)
		if match:
			flush()
			weight = float(match.group(1)) * UNIT_NS[match.group(2)]
			frames = [match.group(3)]
		elif weight and line.startswith("             "):
			frame = line.strip()
			if frame:
				frames.append(frame)
	flush()
	return dict(stacks)


@dataclass
class Node:
	name: str
	value: float = 0.0
	children: dict[str, "Node"] = field(default_factory=dict)


def _tree(stacks: dict[tuple[str, ...], float]) -> Node:
	root = Node("all")
	for stack, weight in stacks.items():
		root.value += weight
		node = root
		for frame in stack:
			node = node.children.setdefault(frame, Node(frame))
			node.value += weight
	return root


def _depth(node: Node) -> int:
	return 1 + max((_depth(child) for child in node.children.values()), default=0)


def _color(name: str) -> str:
	digest = hashlib.blake2s(name.encode(), digest_size=3).digest()
	return f"rgb({205 + digest[0] % 45},{65 + digest[1] % 105},{35 + digest[2] % 75})"


def _render_svg(stacks: dict[tuple[str, ...], float], title: str, width: int = 1400) -> str:
	root = _tree(stacks)
	if root.value <= 0:
		raise ValueError("profile contained no samples")
	row_height = 19
	top = 42
	height = top + (_depth(root) + 1) * row_height
	parts = [
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
		"<style>text{font:12px monospace;fill:#111}.title{font:16px sans-serif;font-weight:bold}rect{stroke:#fff;stroke-width:.5}</style>",
		f'<text class="title" x="10" y="22">{html.escape(title)}</text>',
		f'<text x="10" y="38">Total sampled CPU: {root.value / 1e9:.3f}s</text>',
	]

	def draw(node: Node, x: float, depth: int, parent_value: float) -> None:
		if depth > 0:
			rect_width = width * node.value / root.value
			y = height - (depth + 1) * row_height
			pct = 100.0 * node.value / root.value
			label = html.escape(node.name)
			parts.append(
				f'<g><title>{label} — {node.value / 1e6:.2f}ms ({pct:.2f}%)</title>'
				f'<rect x="{x:.2f}" y="{y}" width="{max(rect_width, 0.1):.2f}" height="{row_height - 1}" fill="{_color(node.name)}"/>'
			)
			if rect_width > 35:
				max_chars = max(1, int((rect_width - 6) / 7))
				shown = node.name if len(node.name) <= max_chars else node.name[: max_chars - 1] + "…"
				parts.append(f'<text x="{x + 3:.2f}" y="{y + 13}">{html.escape(shown)}</text>')
			parts.append("</g>")
		cursor = x
		for child in sorted(node.children.values(), key=lambda item: item.name):
			draw(child, cursor, depth + 1, node.value)
			cursor += width * child.value / root.value

	draw(root, 0.0, 0, root.value)
	parts.append("</svg>")
	return "\n".join(parts)


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("binary", type=Path)
	parser.add_argument("profile", type=Path)
	parser.add_argument("--out", type=Path, required=True)
	parser.add_argument("--title", default="Go CPU flamegraph")
	parser.add_argument("--width", type=int, default=1400)
	args = parser.parse_args()
	result = subprocess.run(
		["go", "tool", "pprof", "-traces", "-nodefraction=0", "-edgefraction=0", str(args.binary), str(args.profile)],
		check=True,
		capture_output=True,
		text=True,
	)
	stacks = _parse_trace_output(result.stdout)
	args.out.parent.mkdir(parents=True, exist_ok=True)
	args.out.write_text(_render_svg(stacks, args.title, args.width))
	print(f"Wrote {args.out} ({len(stacks)} unique stacks)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
