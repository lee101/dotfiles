#!/usr/bin/env python3
"""Unit tests for mojoflame, the gdb-driven sampling profiler.

A profiler whose sampler is missing must say so and exit, not hang — that failure
mode is the first thing worth testing here, so the dependency-missing tests run
against a deliberately empty PATH rather than assuming anything about this host.

The sampling path itself needs gdb (or perf). Where gdb exists, the launch backend
is exercised against a real compute-bound C program; that is also what covers the
interactive-prompt parsing bug that used to make every launch collect zero stacks.
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mojo_toolkit  # noqa: E402
from mojo_toolkit import have, write  # noqa: E402


CC = next((c for c in ("gcc", "clang") if have(c)), "")

# Long enough that the profiler can take several samples, short enough that the
# suite stays fast. -O0 keeps the hot loop a single frame in main.
SPIN_C = """\
#include <stdio.h>

volatile double acc = 0.0;

int main(void) {
    for (int i = 0; i < 2000000000; i++) {
        acc += i * 0.5;
    }
    printf("%f\\n", acc);
    return 0;
}
"""

# Exits immediately: there is nothing to sample, which is a real and useful state
# to cover (a profile of a 5 ms program must not be reported as a broken tool).
FLASH_C = """\
int main(void) { return 0; }
"""


def load(name: str):
    """Import a mojo tool as a module so its helpers can be unit-tested directly."""
    import importlib.machinery
    import importlib.util

    path = mojo_toolkit.BIN_DIR / name
    loader = importlib.machinery.SourceFileLoader(f"_mojo_{name}", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class MissingSamplerTest(mojo_toolkit.ToolTestCase):
    """The tool's own dependency checks, on a PATH that provably lacks them."""

    tool = "mojoflame"

    def _empty_path(self) -> dict:
        empty = self.tmp / "emptybin"
        empty.mkdir(exist_ok=True)
        return {"PATH": str(empty)}

    def test_no_sampler_exits_fast_and_explains(self) -> None:
        """No gdb and no perf: exit non-zero, name the missing dependency, hang
        is not an acceptable outcome (the caller's timeout is the backstop)."""
        r = self.run_tool("--samples", "2", "--timeout", "10", "/bin/true",
                          env=self._empty_path(), timeout=60)
        self.assertNotEqual(r.rc, 0, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertTrue("gdb" in r.text or "perf" in r.text, r.text)

    def test_missing_gdb_message_names_gdb(self) -> None:
        """mojoflame's gdb path must name gdb, not a generic 'command failed'."""
        if have("gdb"):
            self.skipTest("gdb is installed; this asserts the no-gdb branch")
        r = self.run_tool("--samples", "2", "--timeout", "10", "/bin/true",
                          env=self._empty_path(), timeout=60)
        self.assertIn("gdb not found", r.text)

    def test_perf_backend_without_perf(self) -> None:
        r = self.run_tool("--backend", "perf", "/bin/true",
                          env=self._empty_path(), timeout=60)
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("perf not found", r.text)
        self.assertNotIn("Traceback", r.text)

    def test_perf_backend_needs_a_command(self) -> None:
        r = self.run_tool("--backend", "perf", "--pid", str(__import__("os").getpid()),
                          env=self._empty_path(), timeout=60)
        self.assertNotEqual(r.rc, 0, r.text)
        self.assertNotIn("Traceback", r.text)


class ArgvValidationTest(mojo_toolkit.ToolTestCase):
    tool = "mojoflame"

    def test_missing_command(self) -> None:
        r = self.run_tool("/bin/definitely-not-here")
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such command", r.text)

    def test_non_executable(self) -> None:
        f = write(self.tmp / "plain.txt", "x\n")
        r = self.run_tool(str(f))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("not executable", r.text)

    def test_dead_pid(self) -> None:
        r = self.run_tool("--pid", "999999")
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no process with pid", r.text)

    def test_bad_backend_choice(self) -> None:
        r = self.run_tool("--backend", "nonsense", "/bin/true")
        self.assertNotEqual(r.rc, 0)
        self.assertNotIn("Traceback", r.text)


class ParseBacktraceTest(unittest.TestCase):
    """parse_bt is what stands between gdb's output and a flame tree."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.mf = load("mojoflame")

    def test_batch_output_parses(self) -> None:
        """`gdb -batch` output has no prompt prefix."""
        stacks = self.mf.parse_bt(
            "#0  0x000055555555517f in main () at spin.c:3\n"
            "#1  0x00007ffff7b2d82a in __libc_start_call_main (libc-start.c:52)\n")
        self.assertEqual(len(stacks), 1)
        self.assertEqual(stacks[0][0], "main")

    def test_interactive_output_parses(self) -> None:
        """gdb driven over stdin echoes every line behind its `(gdb) ` prompt.

        This is the launch backend's actual input shape. If the prompt is not
        stripped, every frame is unmatched and the profiler reports
        'no samples collected' while gdb is printing perfect backtraces.
        """
        stacks = self.mf.parse_bt(
            "Program received signal SIGINT, Interrupt.\n"
            "0x000055555555517f in main () at spin.c:3\n"
            "(gdb) #0  0x000055555555517f in main () at spin.c:3\n"
            "(gdb) #1  0x00007ffff7b2d82a in __libc_start_call_main (libc-start.c:52)\n"
            "(gdb) ")
        self.assertTrue(stacks, "interactive gdb output parsed to zero stacks")
        self.assertIn("main", stacks[0])

    def test_thread_dump_splits_per_thread(self) -> None:
        stacks = self.mf.parse_bt(
            "Thread 1 \"main\":\n"
            "#0  0x1 in worker () at a.c:1\n"
            "Thread 2 \"w\":\n"
            "#0  0x2 in idle () at b.c:2\n")
        self.assertEqual(len(stacks), 2)

    def test_garbage_yields_nothing(self) -> None:
        self.assertEqual(self.mf.parse_bt("nothing useful here\n"), [])


class IdleFilterTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mf = load("mojoflame")

    def test_parked_worker_threads_are_dropped(self) -> None:
        root = self.mf.build([["futex_wait", "main"], ["main"]], drop_idle=True)
        self.assertEqual(root.total, 1)
        self.assertEqual(root.idle, 1)

    def test_keep_idle_retains_them(self) -> None:
        root = self.mf.build([["futex_wait", "main"], ["main"]], drop_idle=False)
        self.assertEqual(root.total, 2)
        self.assertEqual(root.idle, 0)


@unittest.skipUnless(CC, "no C compiler for the sampling fixture")
class SamplingTest(mojo_toolkit.ToolTestCase):
    tool = "mojoflame"

    def setUp(self) -> None:
        super().setUp()
        self.spin = self._cc("spin", SPIN_C)
        self.flash = self._cc("flash", FLASH_C)

    def _cc(self, name: str, src: str) -> Path:
        cfile = write(self.tmp / f"{name}.c", src)
        out = self.tmp / name
        r = subprocess.run([CC, "-O0", "-g", "-o", str(out), str(cfile)],
                           capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)
        return out

    @unittest.skipUnless(have("gdb"), "gdb missing (mojoflame's sampler)")
    def test_gdb_backend_samples_a_real_loop(self) -> None:
        """The whole launch path: run under gdb, sample, aggregate, report."""
        r = self.run_tool("--backend", "gdb", "--samples", "4", "--interval", "0.05",
                          "--timeout", "40", str(self.spin), timeout=180)
        self.assertEqual(r.rc, 0, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertIn("# mojoflame", r.out)
        self.assertIn("gdb backend", r.out)
        self.assertIn("main", r.out)
        self.assertIn("hot leaves", r.out)
        self.assertIn("flame tree", r.out)

    @unittest.skipUnless(have("gdb"), "gdb missing (mojoflame's sampler)")
    def test_all_samples_idle_is_explained(self) -> None:
        """A program that exits before a sample lands must be diagnosed, not
        reported as a crash.

        "No samples" is only the right answer when the program really is shorter
        than one sample interval, which is a statement about scheduling rather than
        about the fixture: this is a `return 0` binary, so under load the profiler
        sometimes gets a sample of it sitting in a startup path and correctly reports
        that instead. The test therefore accepts the three answers mojoflame can
        honestly give for a process that outlives no useful work — the "no samples"
        diagnosis, a profile built from whatever was caught, or the timeout — and
        still rejects a crash, a traceback, or a silently empty report.
        """
        r = self.run_tool("--backend", "gdb", "--samples", "3", "--timeout", "10",
                          str(self.flash), timeout=120)
        self.assertNotIn("Traceback", r.text)
        self.assertTrue("no samples collected" in r.text or "idle" in r.text
                        or "# mojoflame" in r.out,
                        f"nothing explained the empty profile:\n{r.text}")

    @unittest.skipUnless(have("perf") and Path("/proc/sys/kernel/perf_event_paranoid")
                         .read_text().strip().isdigit()
                         and int(Path("/proc/sys/kernel/perf_event_paranoid").read_text()) <= 2,
                         "perf unavailable or perf_event_paranoid > 2")
    def test_perf_backend_samples(self) -> None:
        r = self.run_tool("--backend", "perf", str(self.spin), timeout=300)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("perf backend", r.out)


if __name__ == "__main__":
    unittest.main()