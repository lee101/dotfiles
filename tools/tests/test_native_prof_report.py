#!/usr/bin/env python3
"""Unit tests for native_prof_report."""

from __future__ import annotations

import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

from native_prof_report import (
    _parse_callgrind_rows,
    _parse_massif_summary,
    _parse_source_hotspots,
)


CALLGRIND_OUTPUT = """\
--------------------------------------------------------------------------------
Ir                   file:function
--------------------------------------------------------------------------------
69,099,720 (100.0%)  PROGRAM TOTALS
60,935,994 (88.19%)  ???:bitbankc::ChronosEngine::ForecastLine(bitbankc::LineForecastRequest const&) const [/tmp/build/bitbankc_forecast_bench]
58,162,769 (84.17%)  ???:bitbankc::cuda::(anonymous namespace)::ReserveBuffers(unsigned long) [/tmp/build/bitbankc_forecast_bench]
--------------------------------------------------------------------------------
-- User-annotated source: /tmp/src/sample.cpp
--------------------------------------------------------------------------------
Ir

    .           int slow(int n) {
    .             std::vector<int> v;
3,006 ( 0.13%)    for (int i = 0; i < n; ++i) {
1,000 ( 0.04%)      v.push_back(i * 3);
    .             }
   10 ( 0.00%)  }
"""


MASSIF_OUTPUT = """\
desc: --massif-out-file=/tmp/native.massif.out
cmd: /tmp/build/bitbankc_forecast_bench
time_unit: i
#-----------
snapshot=0
#-----------
time=0
mem_heap_B=0
mem_heap_extra_B=0
mem_stacks_B=0
heap_tree=empty
#-----------
snapshot=7
#-----------
time=9411224
mem_heap_B=309040
mem_heap_extra_B=39136
mem_stacks_B=0
heap_tree=detailed
n13: 309040 (heap allocation functions) malloc/new/new[], --alloc-fns, etc.
 n1: 65536 0x5059C3C: cudaMalloc (in /usr/local/cuda/libcudart.so)
  n1: 65536 0x138CF6: bitbankc::cuda::(anonymous namespace)::ReserveBuffers(unsigned long) (in /tmp/build/bitbankc_forecast_bench)
   n1: 65536 0x13907D: bitbankc::cuda::LaunchForecastProjection(...) (in /tmp/build/bitbankc_forecast_bench)
    n1: 65536 0x13573C: bitbankc::ChronosEngine::ForecastLine(...) (in /tmp/build/bitbankc_forecast_bench)
     n0: 65536 0x12FD35: main (in /tmp/build/bitbankc_forecast_bench)
 n1: 8192 0x4B7B233: OPENSSL_LH_insert (in /usr/lib/libcrypto.so)
  n1: 8192 0x550CEBA: __libc_start_main@@GLIBC_2.34 (in /usr/lib/libc.so.6)
"""


class NativeProfReportTest(unittest.TestCase):
    def test_parse_callgrind_rows(self) -> None:
        rows = _parse_callgrind_rows(CALLGRIND_OUTPUT, top_n=5)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0].ir, 60935994)
        self.assertIn("ForecastLine", rows[0].location)
        self.assertEqual(rows[0].binary, "/tmp/build/bitbankc_forecast_bench")

    def test_parse_source_hotspots(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            source_path = Path(tmpdir) / "sample.cpp"
            source_path.write_text(
                textwrap.dedent(
                    """\
                    int slow(int n) {
                      std::vector<int> v;
                      for (int i = 0; i < n; ++i) {
                        v.push_back(i * 3);
                      }
                    }
                    """
                )
            )
            output = CALLGRIND_OUTPUT.replace("/tmp/src/sample.cpp", str(source_path))
            hotspots = _parse_source_hotspots(output, [source_path], top_n=3)
            self.assertIn(source_path, hotspots)
            self.assertEqual(hotspots[source_path][0].line_no, 3)
            self.assertEqual(hotspots[source_path][0].ir, 3006)
            self.assertIn("for (int i = 0; i < n; ++i)", hotspots[source_path][0].code)

    def test_parse_massif_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            massif_path = Path(tmpdir) / "native.massif.out"
            massif_path.write_text(MASSIF_OUTPUT)
            summary = _parse_massif_summary(massif_path, top_n=4, roots=[Path("/tmp/build")])
            self.assertEqual(summary.peak_snapshot, 7)
            self.assertEqual(summary.peak_total_bytes, 348176)
            self.assertGreaterEqual(len(summary.allocations), 1)
            self.assertIn("ReserveBuffers", summary.allocations[0].stack_summary)


if __name__ == "__main__":
    unittest.main()
