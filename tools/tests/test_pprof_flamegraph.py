import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

from pprof_flamegraph import _parse_trace_output, _render_svg


TRACE = """\
File: app.test
-----------+-------------------------------------------------------
      10ms   leaf.one
             parent.one
             root
-----------+-------------------------------------------------------
      20ms   leaf.two
             root
"""


def test_parse_reverses_pprof_leaf_first_stacks():
	stacks = _parse_trace_output(TRACE)
	assert stacks[("root", "parent.one", "leaf.one")] == 10_000_000
	assert stacks[("root", "leaf.two")] == 20_000_000


def test_render_svg_contains_frames_and_sample_total():
	svg = _render_svg(_parse_trace_output(TRACE), "Profile")
	assert svg.startswith("<svg")
	assert "leaf.one" in svg
	assert "Total sampled CPU: 0.030s" in svg
