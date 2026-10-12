#!/usr/bin/env python3
"""Unit tests for mojomem, the LD_PRELOAD allocation profiler.

The interesting paths here are all reachable without a Mojo toolchain: the shim is
plain C, so a fake runtime that exports `KGEN_CompilerRT_AlignedAlloc` /
`KGEN_CompilerRT_AlignedFree` is enough to drive the whole mojo backend. That is
what these tests do — the shim, the TSV parser and the report are exercised
exactly as they are for a real Mojo binary.

Symbolization (addr2line) and the valgrind backends are keyed on the dependency
probes from install.sh, so they run wherever the tooling exists and skip with the
missing binary named otherwise.
"""
from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mojo_toolkit  # noqa: E402  (module access, not `from ... import ToolTestCase`:
# an imported TestCase subclass is itself collected and would re-run its
# tests in every file that imports it)
from mojo_toolkit import SHIM_C, have, write  # noqa: E402


CC = next((c for c in ("gcc", "clang") if have(c)), "")

# A stand-in for libKGENCompilerRTShared.so: the two symbols mojomem interposes.
RUNTIME_C = """\
#include <stdlib.h>

void *KGEN_CompilerRT_AlignedAlloc(size_t align, size_t size) {
    return aligned_alloc(align, size);
}

void KGEN_CompilerRT_AlignedFree(void *p) {
    free(p);
}
"""

# A program that allocates through the interposable symbols: three 4 KiB blocks it
# frees, plus one 128 B block it deliberately leaks.
ALLOC_C = """\
#include <stddef.h>

void *KGEN_CompilerRT_AlignedAlloc(size_t align, size_t size);
void KGEN_CompilerRT_AlignedFree(void *p);

int main(void) {
    for (int i = 0; i < 3; i++) {
        void *p = KGEN_CompilerRT_AlignedAlloc(64, 4096);
        if (!p) return 2;
        KGEN_CompilerRT_AlignedFree(p);
    }
    KGEN_CompilerRT_AlignedAlloc(64, 128);   /* leaked on purpose */
    return 0;
}
"""

# Allocates nothing at all: the clean zero-allocation case must be reported as
# such, not as a failure and not as "the shim did not run".
NOALLOC_C = """\
#include <stdio.h>

int main(void) {
    printf("hi\\n");
    return 0;
}
"""

requires_cc = unittest.skipUnless(CC, "neither gcc nor clang (mojomem builds its shim with one)")


@requires_cc
class ShimTestCase(mojo_toolkit.ToolTestCase):
    """Builds the C fixtures once per test; skips entirely without a compiler."""

    tool = "mojomem"

    def setUp(self) -> None:
        super().setUp()
        self.env = {"XDG_CACHE_HOME": str(self.tmp / "cache")}
        self.lib = self._cc("libkgen.so", ["-shared", "-fPIC", "-O0", "-g"], RUNTIME_C)
        self.alloc = self._cc("alloc", ["-O0", "-g"], ALLOC_C, link=[str(self.lib)])
        self.noalloc = self._cc("noalloc", ["-O0", "-g"], NOALLOC_C)

    def _cc(self, name: str, flags: list[str], src: str, link: list[str] | None = None):
        """Compile `src` into `name` in this test's own temp dir."""
        cfile = write(self.tmp / f"{name}.c", src)
        out = self.tmp / name
        cmd = [CC, *flags, "-o", str(out), str(cfile), *(link or [])]
        if "-shared" in flags:
            cmd.append(f"-Wl,-rpath,{self.tmp}")
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, f"{' '.join(cmd)} failed:\n{r.stderr}")
        return out

    def mem(self, *args, **kw) -> "tuple[int, str, str]":
        kw.setdefault("timeout", 120)
        return self.run_tool(*args, env=self.env, **kw)


class ShimBuildTest(ShimTestCase):
    def test_shipped_shim_compiles(self) -> None:
        """The .c file in the repo must build with the flags build_shim() uses."""
        so = self.tmp / "mojomem_shim.so"
        r = subprocess.run(
            [CC, "-shared", "-fPIC", "-O2", "-g", "-o", str(so), str(SHIM_C), "-ldl"],
            capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(so.is_file())

        nm = subprocess.run(["nm", "-D", "--defined-only", str(so)],
                            capture_output=True, text=True)
        if nm.returncode == 0:
            defined = nm.stdout
            # install.sh's mojomem warning and every doc reference to the shim
            # name these two symbols; if they change, the profiler silently
            # profiles nothing.
            for sym in ("KGEN_CompilerRT_AlignedAlloc", "KGEN_CompilerRT_AlignedFree"):
                self.assertIn(sym, defined, f"shim no longer defines {sym}")

    def test_no_compiler_is_a_clear_error(self) -> None:
        """With no C compiler the tool must say so, not die building a shim."""
        empty = self.tmp / "emptybin"
        empty.mkdir(exist_ok=True)
        env = dict(self.env, PATH=str(empty))
        r = self.run_tool(str(self.alloc), env=env)
        self.assertNotEqual(r.rc, 0)
        self.assertIn("need gcc or clang", r.text)
        self.assertNotIn("Traceback", r.text)


class ZeroAllocationTest(ShimTestCase):
    """The shim wiring works on its own: a program with no Mojo allocations."""

    def test_zero_allocations_is_reported_cleanly(self) -> None:
        r = self.mem(str(self.noalloc))
        self.assertEqual(r.rc, 0, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertIn("# mojomem", r.out)
        self.assertIn("0 Mojo allocations", r.out)
        self.assertIn("No Mojo allocations recorded", r.out)
        # the hint names the symbol pair the shim actually intercepts
        self.assertIn("KGEN_CompilerRT_AlignedAlloc", r.out)

    def test_leaked_block_is_counted(self) -> None:
        r = self.mem(str(self.alloc))
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("4 Mojo allocations", r.out)      # 3 freed + 1 leaked
        self.assertIn("3 frees", r.out)
        self.assertIn("1 blocks never freed", r.out)
        self.assertIn("128B", r.out)                    # the leak's size
        self.assertIn("12.0K", r.out)                   # 3 x 4096

    def test_repeated_runs_agree(self) -> None:
        a = self.mem(str(self.alloc)).out
        b = self.mem(str(self.alloc)).out
        strip = lambda s: "\n".join(l for l in s.splitlines() if not l.startswith("# mojomem"))  # noqa: E731
        self.assertEqual(strip(a), strip(b))

    def test_top_truncates_the_table(self) -> None:
        big = self.mem(str(self.alloc))
        one = self.mem("--top", "1", str(self.alloc))
        self.assertEqual(one.rc, 0, one.text)
        self.assertEqual(one.out.count("| 3 | 12.0K"), 1)
        self.assertGreaterEqual(big.out.count("| 3 | 12.0K"), 1)

    def test_stacks_prints_backtraces(self) -> None:
        r = self.mem("--stacks", str(self.alloc))
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("## stacks", r.out)
        # with -g the frames resolve to our own source even without addr2line
        if have("addr2line"):
            self.assertIn("main [alloc.c:", r.out)
        else:
            self.assertNotIn("Traceback", r.text)


class SymbolizationTest(ShimTestCase):
    @unittest.skipUnless(have("addr2line"), "addr2line missing (binutils); "
                                            "mojomem symbolizes with it")
    def test_addr2line_frames_name_the_source_file(self) -> None:
        r = self.mem(str(self.alloc))
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("main [alloc.c:", r.out)


class BadTargetTest(ShimTestCase):
    def test_missing_binary(self) -> None:
        r = self.mem(str(self.tmp / "does-not-exist"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such command", r.text)
        self.assertNotIn("Traceback", r.text)

    def test_non_executable_file(self) -> None:
        plain = write(self.tmp / "plain.txt", "not a program\n")
        r = self.mem(str(plain))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("not executable", r.text)
        self.assertNotIn("Traceback", r.text)

    def test_non_mojo_binary_exits_clean(self) -> None:
        """A target that never calls the symbols still reports, it does not bail."""
        r = self.mem(str(self.tmp / "src.c"))
        self.assertNotIn("Traceback", r.text)


class ValgrindBackendTest(ShimTestCase):
    """--tool dhat / massif. Keyed on install.sh's valgrind dependency check."""

    @unittest.skipUnless(have("valgrind"), "valgrind missing (mojomem --tool dhat|massif)")
    def test_dhat_reports_the_c_heap(self) -> None:
        r = self.mem("--tool", "dhat", str(self.alloc), timeout=300)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("dhat, C heap only", r.out)
        self.assertNotIn("Traceback", r.text)

    @unittest.skipUnless(have("valgrind"), "valgrind missing (mojomem --tool dhat|massif)")
    def test_massif_reports_a_timeline(self) -> None:
        r = self.mem("--tool", "massif", str(self.alloc), timeout=300)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("massif, C heap only", r.out)

    def test_missing_valgrind_is_explained(self) -> None:
        """Without valgrind the dhat path must bail clearly, not traceback."""
        empty = self.tmp / "emptybin"
        empty.mkdir(exist_ok=True)
        env = dict(self.env, PATH=str(empty))
        r = self.run_tool("--tool", "dhat", str(self.alloc), env=env)
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("valgrind not found", r.text)
        self.assertNotIn("Traceback", r.text)


class ShimOutputFormatTest(unittest.TestCase):
    """The shim's TSV is a private contract between mojomem_shim.c and mojomem."""

    @requires_cc
    def test_summary_and_site_rows_parse(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            out = os.path.join(td, "mm.tsv")
            so = os.path.join(td, "shim.so")
            c = subprocess.run([CC, "-shared", "-fPIC", "-O2", "-g", "-o", so,
                                str(SHIM_C), "-ldl"], capture_output=True, text=True)
            self.assertEqual(c.returncode, 0, c.stderr)
            prog = os.path.join(td, "p")
            main_c = os.path.join(td, "m.c")
            with open(main_c, "w") as f:
                f.write('#include <stdlib.h>\n'
                        'void *KGEN_CompilerRT_AlignedAlloc(size_t a, size_t s);\n'
                        'void KGEN_CompilerRT_AlignedFree(void *p);\n'
                        'int main(void){void*p=KGEN_CompilerRT_AlignedAlloc(64,256);'
                        'KGEN_CompilerRT_AlignedFree(p);return 0;}\n')
            # the symbols must resolve at link time; the *runtime* binding is
            # what LD_PRELOAD then interposes
            rlib = subprocess.run(
                [CC, "-shared", "-fPIC", "-O0", "-o", os.path.join(td, "rt.so"), "-x",
                 "c", "-"], input=RUNTIME_C, capture_output=True, text=True)
            self.assertEqual(rlib.returncode, 0, rlib.stderr)
            build = subprocess.run(
                [CC, "-O0", "-g", "-o", prog, main_c, os.path.join(td, "rt.so"),
                 f"-Wl,-rpath,{td}"], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            env = dict(os.environ, LD_PRELOAD=so, MOJOMEM_OUT=out)
            subprocess.run([prog], env=env, check=True)
            with open(out) as f:
                rows = [ln.rstrip("\n").split("\t") for ln in f]

        self.assertIn("#summary\tcalls\tbytes\tfrees\tpeak_live".split("\t"), rows)
        summary = [r for r in rows if r[0] == "summary"][0]
        self.assertEqual(summary[1], "1")          # one allocation
        self.assertEqual(summary[2], "256")        # 256 bytes
        self.assertEqual(summary[3], "1")          # one free
        sites = [r for r in rows if r[0] == "site"]
        self.assertTrue(sites, "shim recorded no site rows for a live allocation")
        self.assertEqual(sites[0][1], "1")
        # each frame column is "<addr>|<backtrace_symbols text>"
        self.assertTrue(any("|" in col for col in sites[0][4:]))


if __name__ == "__main__":
    unittest.main()