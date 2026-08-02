#!/usr/bin/env python3
"""Tests for the dependency-free contrast CLI."""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


TOOL = Path(__file__).resolve().parents[1] / "contrast"


class ContrastTest(unittest.TestCase):
    def run_tool(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(TOOL), *args], text=True, capture_output=True, check=False)

    def test_known_black_white_ratio(self) -> None:
        result = self.run_tool("#000", "#fff")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "21.00 AAA")

    def test_compact_json_and_short_hex(self) -> None:
        result = self.run_tool("--json", "#777", "white")
        self.assertEqual(json.loads(result.stdout), {"fg": "#777", "bg": "white", "r": 4.48, "grade": "AA18"})

    def test_alpha_is_composited_over_background(self) -> None:
        translucent = self.run_tool("--ratio", "rgba(255,255,255,.5)", "#000")
        self.assertAlmostEqual(float(translucent.stdout), 5.28, places=2)

    def test_minimum_controls_exit_status(self) -> None:
        self.assertEqual(self.run_tool("--min", "4.5", "#777", "#fff").returncode, 1)
        self.assertEqual(self.run_tool("--min", "4.5", "#767676", "#fff").returncode, 0)


if __name__ == "__main__":
    unittest.main()
