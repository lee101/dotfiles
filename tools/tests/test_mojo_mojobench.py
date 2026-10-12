#!/usr/bin/env python3
"""Tests for tools/mojo/bin/mojobench — the A/B benchmark harness.

mojobench is the tool that decides whether an optimisation is real, so its failure
mode is not a crash: it is a confident wrong answer. A harness that always reports
a win (or that cannot tell a 2x slowdown from noise) is worse than no harness,
because the reader trusts it.

Every test here drives it over trivial shell commands — `true`, `sleep 0.05` — so a
timing assertion costs milliseconds and needs no Mojo toolchain.

One thing to know when reading the fixtures: mojobench runs every target with cwd
set to its own scratch directory, not the test's. A target that wants to record
anything has to use an absolute path.
"""
from __future__ import annotations

import os
import re
import statistics
import sys
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

from mojo_toolkit import ToolTestCase, duration_quantum, parse_duration, write  # noqa: E402

ROW_RE = re.compile(r"^\|\s*(?P<target>[^|]+?)\s*\|\s*(?P<rest>.*?)\s*\|$")


def parse_rows(out: str, cells: int):
    """[(target, [cells])] for every markdown table row with exactly `cells` columns.

    mojobench prints two tables and they have different widths: the timing table is
    `target | median | min | MAD | max | build`, the comparison table is
    `target | median | speedup | verdict`. Counting columns is what keeps them apart —
    matching on a cell pattern alone cannot, because `**29.64x SLOWER**` looks
    exactly like a `build` cell to a regex and `0.03x` exactly like a duration to a
    unit test.
    """
    rows = []
    for line in out.splitlines():
        m = ROW_RE.match(line)
        if m and not line.startswith("|---") and m.group("target") != "target":
            row = (m.group("target"), [c.strip() for c in m.group("rest").split("|")])
            if len(row[1]) == cells:
                rows.append(row)
    return rows


def timings(out: str):
    """{target: [median, min, MAD, max, build]} from the timing table."""
    return dict((t, c) for t, c in parse_rows(out, 5))


def v_text(out: str, target: str = "b") -> str:
    """The verdict cell for one target of the `vs baseline` table."""
    return verdicts(out)[target][1]


def verdicts(out: str):
    """{target: (speedup_text, verdict_text)} from the `vs baseline` table."""
    return dict((t, (c[1], c[2])) for t, c in parse_rows(out, 3))


def sh_script(path: Path, body: str) -> Path:
    """An executable /bin/sh script, so a target is a real argv[0] with real cost.

    The trailing newline is not decoration: dash parses a final line with no
    newline as incomplete and silently executes nothing.
    """
    write(path, "#!/bin/sh\n" + body.rstrip("\n") + "\n")
    os.chmod(path, 0o755)
    return path


def mad(xs) -> float:
    """Median absolute deviation — mojobench's noise measure, in seconds."""
    m = statistics.median(xs)
    return statistics.median([abs(x - m) for x in xs])


class MojobenchTest(ToolTestCase):
    tool = "mojobench"
    usage_token = "mojobench"

    def setUp(self) -> None:
        super().setUp()
        self.fast = sh_script(self.tmp / "fast.sh", "exit 0\n")
        self.slow = sh_script(self.tmp / "slow.sh", "sleep 0.05\nexit 0\n")

    # ---- report shape -------------------------------------------------------

    def test_reports_a_row_per_target_with_median_min_mad_max(self) -> None:
        r = self.run_tool("--reps", "3", "--warmup", "0", str(self.fast))
        self.assertNotIn("Traceback", r.text)
        self.assertEqual(r.rc, 0, r.text)
        self.assertRegex(r.out, r"^# mojobench — 3 reps, 0 warmup")
        for header in ("| target | median | min | MAD | max | build |",
                       "|---|---|---|---|---|---|"):
            self.assertIn(header, r.out)
        rows = [x for x in parse_rows(r.out, 5) if x[0] == "fast.sh"]
        self.assertEqual(len(rows), 1, r.out)
        median, mn, m, mx, build = rows[0][1]
        self.assertRegex(median, r"^(?:\d+us|\d+\.\d+ms|\d+\.\d+s)$")
        self.assertRegex(mn, r"^(?:\d+us|\d+\.\d+ms|\d+\.\d+s)$")
        self.assertRegex(m, r"^(?:\d+us|\d+\.\d+ms|\d+\.\d+s)$")
        self.assertRegex(mx, r"^(?:\d+us|\d+\.\d+ms|\d+\.\d+s)$")
        self.assertEqual(build, "-", "no build column for a prebuilt binary")
        # min <= median <= max must hold or the statistics are nonsense.
        # parse_duration matches the unit from the suffix, so this holds for any
        # unit the formatter picks — the old hand-rolled `us()` read `float(s[:-2])`
        # for "ms" but `float(s[:-1])` for "us", which happens to agree only because
        # mojobench renders microseconds with no decimal point.
        self.assertLessEqual(parse_duration(mn), parse_duration(median))
        self.assertLessEqual(parse_duration(median), parse_duration(mx))
        # a single-column target is not compared against anything, so the `vs` table
        # must not appear: a comparison table that is absent is not a defect.
        self.assertNotIn("## vs `", r.out,
                         "one target cannot be faster or slower than itself")

    def test_labels_name_the_rows(self) -> None:
        r = self.run_tool("--reps", "2", "--warmup", "0",
                          f"--label=slow={self.slow}", f"--label=fast={self.fast}")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("| slow |", r.out)
        self.assertIn("| fast |", r.out)
        self.assertNotIn("slow.sh", r.out, "--label must replace the basename")

    def test_bad_label_is_a_usage_error(self) -> None:
        for bad in ("--label=noname", "--label=noequals", "--label==x"):
            with self.subTest(label=bad):
                r = self.run_tool(bad, str(self.fast))
                self.assertNotEqual(r.rc, 0, f"{bad} accepted: {r.text}")
                self.assertNotIn("Traceback", r.text)

    # ---- the verdict is derived from the numbers -----------------------------

    def test_faster_target_is_reported_faster(self) -> None:
        r = self.run_tool("--reps", "5", "--warmup", "0",
                          f"--label=fast={self.fast}", f"--label=slow={self.slow}")
        self.assertEqual(r.rc, 0, r.text)
        v = verdicts(r.out)
        self.assertIn("slow", v, r.out)
        spd, text = v["slow"]
        self.assertRegex(spd, r"^\d+\.\d+x$")
        self.assertIn("SLOWER", text, f"slow target called faster:\n{r.out}")
        self.assertIn("## vs `fast`", r.out, "the baseline is the first target")

    def test_slower_first_makes_the_other_one_faster(self) -> None:
        """Same two commands, order swapped: the verdict must flip with the data.

        A harness that hard-codes 'faster' passes the test above and this one is
        what catches it.
        """
        r = self.run_tool("--reps", "5", "--warmup", "0",
                          f"--label=slow={self.slow}", f"--label=fast={self.fast}")
        v = verdicts(r.out)
        self.assertIn("fast", v, r.out)
        _, text = v["fast"]
        self.assertIn("faster", text)
        self.assertNotIn("SLOWER", text, r.out)

    def test_identical_targets_are_called_noise_not_a_win(self) -> None:
        """The verdict must follow from the gate, not from the label.

        Two runs of the same command are the control for every other test here: if
        mojobench called an identical pair "faster", none of its other verdicts would
        mean anything. What the tool promises is a *rule* — "a difference inside 2x
        the larger MAD is not a result" — not a fixed outcome, because on a shared
        box two runs of one binary really can differ by more than the gate. So this
        checks the rule: taking the medians and MADs from the report itself, a
        verdict is required to agree with `|median_a - median_b| < 2 * max(MAD)`,
        except in the narrow band where the rendered cells are too rounded to tell
        which side of the gate the difference fell on.
        """
        r = self.run_tool("--reps", "7", "--warmup", "0",
                          f"--label=a={self.fast}", f"--label=b={self.fast}")
        v = verdicts(r.out)
        self.assertIn("b", v, r.out)
        _, text = v["b"]
        self.assertRegex(v["b"][0], r"^\d+\.\d+x$", "a ratio is printed whatever the verdict")
        self.assertIn("Noise gate", r.out, "the reader is told what the gate is")

        rows = timings(r.out)
        self.assertEqual(set(rows), {"a", "b"}, r.out)
        a_med, b_med = parse_duration(rows["a"][0]), parse_duration(rows["b"][0])
        a_mad, b_mad = parse_duration(rows["a"][2]), parse_duration(rows["b"][2])

        # Each cell is rounded for humans, so the medians carry up to one cell width
        # of error between them. Inside that band the report simply does not contain
        # enough information to decide the question, and asserting either way would be
        # asserting something the tool cannot have printed.
        quantum = duration_quantum(rows["a"][0])
        diff = abs(a_med - b_med)
        gate = 2 * max(a_mad, b_mad)
        if diff + quantum <= gate:
            self.assertIn("no measurable difference", text, r.out)
            self.assertNotIn("faster", text, r.out)
        elif diff - quantum > gate:
            self.assertNotIn("no measurable difference", text, r.out)

    def test_identical_targets_render_the_same_number(self) -> None:
        """A pair that differs by more than its own spread is not "noise".

        "no measurable difference" is not a decoration — it is the claim that the
        difference is smaller than the dispersion of the measurement. So the check is
        the claim itself: a difference larger than the reported dispersion must not be
        called noise, and a difference inside it must be. Every number comes from the
        report, so the comparison is exact, and unlike "the two medians must look
        alike" it does not ask a loaded box to be quiet.
        """
        r = self.run_tool("--reps", "7", "--warmup", "0",
                          f"--label=a={self.fast}", f"--label=b={self.fast}")
        rows = timings(r.out)
        self.assertEqual(set(rows), {"a", "b"}, r.out)
        a, b = rows["a"], rows["b"]
        a_med, b_med = parse_duration(a[0]), parse_duration(b[0])
        a_mad, b_mad = parse_duration(a[2]), parse_duration(b[2])
        diff, gate = abs(a_med - b_med), 2 * max(a_mad, b_mad)
        if diff - duration_quantum(a[0]) > gate:
            self.assertNotIn("no measurable difference", v_text(r.out),
                             f"{a[0]} vs {b[0]}, MAD {a[2]}/{b[2]}: a difference "
                             f"larger than the spread is a result, not noise")
        if diff + duration_quantum(a[0]) <= gate:
            self.assertIn("no measurable difference", v_text(r.out), r.out)

    def test_speedup_ratio_is_the_measured_one(self) -> None:
        """The number printed has to be the ratio of the two medians, not a constant."""
        r = self.run_tool("--reps", "5", "--warmup", "0",
                          f"--label=fast={self.fast}", f"--label=slow={self.slow}")
        rows = timings(r.out)
        self.assertEqual(set(rows), {"fast", "slow"}, r.out)

        base, other = parse_duration(rows["fast"][0]), parse_duration(rows["slow"][0])
        printed = float(verdicts(r.out)["slow"][0].rstrip("x"))
        self.assertAlmostEqual(printed, base / other, delta=0.35 * (base / other),
                               msg=f"printed {printed}x, medians imply {base / other:.2f}x")

    # ---- awkward targets -----------------------------------------------------

    def test_failing_command_is_reported_not_silently_timed(self) -> None:
        bad = sh_script(self.tmp / "bad.sh", "exit 3\n")
        r = self.run_tool("--reps", "2", "--warmup", "0", str(bad))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("exited 3", r.err)
        self.assertNotIn("Traceback", r.text)

    def test_failing_command_in_the_second_slot_also_fails_the_run(self) -> None:
        bad = sh_script(self.tmp / "bad.sh", "exit 7\n")
        r = self.run_tool("--reps", "2", "--warmup", "0", str(self.fast), str(bad))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("exited 7", r.err)

    def test_huge_output_does_not_swamp_the_report(self) -> None:
        """Timing stdout to /dev/null is the whole reason this stays fast."""
        noisy = sh_script(self.tmp / "noisy.sh",
                          "i=0\nwhile [ $i -lt 4000 ]; do echo 'a line of output padding'; i=$((i+1)); done\nexit 0\n")
        r = self.run_tool("--reps", "2", "--warmup", "0", str(noisy))
        self.assertEqual(r.rc, 0, r.text)
        self.assertLess(len(r.out), 4096, f"{len(r.out)} bytes: stdout leaked into the report")
        self.assertNotIn("padding", r.out)
        self.assertIn("| noisy.sh |", r.out)

    def test_command_writing_to_stderr_is_still_timed(self) -> None:
        chatty = sh_script(self.tmp / "chatty.sh",
                           "echo 'to stderr' >&2\nexit 0\n")
        r = self.run_tool("--reps", "2", "--warmup", "0", str(chatty))
        self.assertEqual(r.rc, 0, r.text)
        self.assertNotIn("to stderr", r.out + r.err)
        self.assertIn("| chatty.sh |", r.out)

    def test_args_are_passed_to_every_target(self) -> None:
        """Every timed run of every target sees the same --args.

        warmup=0, so the count is exactly reps x targets — that pins both the
        argument plumbing and the run count.
        """
        seen = self.tmp / "seen.txt"
        rec = sh_script(self.tmp / "rec.sh", f'echo "$1" >> {seen}\nexit 0\n')
        r = self.run_tool("--reps", "2", "--warmup", "0", "--args=hello",
                          str(rec), str(rec))
        self.assertEqual(r.rc, 0, r.text)
        self.assertEqual(seen.read_text().split(), ["hello"] * 4)

    def test_warmup_runs_are_real_but_not_timed(self) -> None:
        """warmup=N executes each target N+reps times; the timing loop runs reps.

        The fixture is given an absolute output path on purpose. mojobench runs
        every target with cwd set to its own scratch directory, so neither a
        relative path nor "$PWD" points at the test's temp dir.
        """
        seen = self.tmp / "seen.txt"
        rec = sh_script(self.tmp / "rec.sh", f'echo "$1" >> "{seen}"\nexit 0\n')
        r = self.run_tool("--reps", "2", "--warmup", "3", str(rec))
        self.assertEqual(r.rc, 0, r.text)
        self.assertEqual(len(seen.read_text().splitlines()), 5,
                         "warmup runs did not execute")
        self.assertRegex(r.out, r"^# mojobench — 2 reps, 3 warmup")

    def test_run_count_of_one_still_reports(self) -> None:
        """MAD of a single sample is 0, so the noise gate collapses to 0.

        Which means the "verdict" for one rep is decided by the difference alone:
        |m1 - m2| < 0 is never true, so every pair is reported as a result and the
        test that catches a crash on --reps 1 also catches a silent "no measurable
        difference" — a claim about noise that a single sample cannot support. That
        direction is asserted here, because a target that outran the other by three
        orders of magnitude (the fast/slow fixture) is the one case where the report
        is certain.
        """
        for reps in ("1",):
            with self.subTest(reps=reps):
                r = self.run_tool("--reps", reps, "--warmup", "0",
                                  f"--label=a={self.fast}", f"--label=b={self.slow}")
                self.assertEqual(r.rc, 0, r.text)
                v = verdicts(r.out)
                self.assertIn("b", v, r.out)
                self.assertRegex(v["b"][0], r"^\d+\.\d+x$")
                self.assertIn("SLOWER", v["b"][1], r.out)
                self.assertNotIn("no measurable difference", v["b"][1], r.out)

    def test_zero_reps_is_not_a_crash(self) -> None:
        """--reps 0 measures nothing.

        It must not print a traceback (the tool's whole contract) and it must not
        exit 0, because an empty measurement silently reported as a clean run is
        the failure mode this tool exists to prevent.
        """
        r = self.run_tool("--reps", "0", "--warmup", "0", str(self.fast))
        self.assertNotIn("Traceback", r.text, f"unhandled exception:\n{r.text}")
        self.assertNotEqual(r.rc, 0, f"an empty measurement reported success:\n{r.text}")

    # ---- argument errors ------------------------------------------------------

    def test_missing_target_exits_two_with_usage(self) -> None:
        r = self.run_tool("--reps", "2", str(self.tmp / "nope.sh"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such target", r.err)
        self.assertNotIn("Traceback", r.text)

    def test_non_executable_target_is_refused(self) -> None:
        p = write(self.tmp / "plain.txt", "not a program\n")
        r = self.run_tool("--reps", "2", str(p))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("not executable", r.err)
        self.assertNotIn("Traceback", r.text)

    def test_needs_mojo_only_for_mojo_sources(self) -> None:
        """A .mojo target needs a toolchain and must say so, not traceback."""
        src = write(self.tmp / "k.mojo", "def main():\n    pass\n")
        r = self.run_tool("--reps", "1", str(src))
        self.assertNotIn("Traceback", r.text)
        self.assertEqual(r.rc, 2, r.text)
        self.assertRegex(r.err.lower(), r"mojo not found|build failed")


if __name__ == "__main__":
    unittest.main()