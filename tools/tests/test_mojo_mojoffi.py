#!/usr/bin/env python3
"""Unit tests for mojoffi, the FFI / ABI checker.

The source-analysis paths are pure text work and are covered unconditionally.
`--check` needs `nm` and a real shared library; a C stand-in exporting the same
symbol names exercises it wherever binutils is present.

Note for anyone adding fixtures here: `@export` is not a bare decorator — mojoffi
requires the symbol name, `@export("kernel_name")`. A bare `@export` parses to
zero exports and the tool reports "no @export defs found", which looks like a
tool failure but is a malformed fixture.
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

# Every export scalar-typed with abi("C") and non-raising: the clean report.
CLEAN_MOJO = """\
@export("add_kernels")
def add(a: Int, b: Int) abi("C") -> Int:
    return a + b


@export("scale")
def scale(x: Float64, k: Float64) abi("C") -> Float64:
    return x * k
"""

# One finding of every kind mojoffi knows how to report.
MESSY_MOJO = """\
@export("bad_kernel")
def bad(a: Int) abi("C") -> Int:
    x = Int("42")
    raise Error("x")
    return x


@export("ptr_kernel")
def ptr(out: Int) abi("C") -> Int:
    return 1


@export("noabi_kernel")
def noabi(a: UnsafePointer[UInt8]) -> Int:
    return 2
"""

NO_EXPORTS_MOJO = """\
def helper(x: Int) -> Int:
    return x
"""


def load(name: str):
    import importlib.machinery
    import importlib.util

    loader = importlib.machinery.SourceFileLoader(f"_mojo_{name}", str(mojo_toolkit.BIN_DIR / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class ParseExportsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mf = load("mojoffi")

    def _parse(self, text: str):
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "k.mojo"
            p.write_text(text)
            return self.mf.parse_exports(p)

    def test_symbols_params_and_return_types(self) -> None:
        exports, _ = self._parse(CLEAN_MOJO)
        self.assertEqual([e["symbol"] for e in exports], ["add_kernels", "scale"])
        self.assertEqual(exports[0]["params"], [("a", "Int"), ("b", "Int")])
        self.assertEqual(exports[0]["ret"], "Int")
        self.assertEqual(exports[1]["ret"], "Float64")
        self.assertTrue(all(e["abi"] for e in exports))
        self.assertFalse(any(e["raises"] for e in exports))

    def test_abi_is_an_effect_before_the_arrow(self) -> None:
        exports, _ = self._parse('@export("k")\ndef k(a: Int) abi("C") -> Int:\n    return a\n')
        self.assertTrue(exports[0]["abi"])
        exports, _ = self._parse('@export("k")\ndef k(a: Int) -> Int:\n    return a\n')
        self.assertFalse(exports[0]["abi"])

    def test_missing_abi_is_detected_not_assumed(self) -> None:
        exports, _ = self._parse('@export("k")\ndef k(a: Int) -> Int:\n    return a\n')
        findings = self.mf.lint(exports, [""])
        self.assertTrue(any(f[3] == 'no abi("C")' for f in findings))

    def test_raises_is_detected(self) -> None:
        exports, _ = self._parse('@export("k")\ndef k(a: Int) raises -> Int:\n    return a\n')
        self.assertTrue(exports[0]["raises"])
        findings = self.mf.lint(exports, [""])
        self.assertTrue(any("raises" in f[3] for f in findings))

    def test_line_numbers_point_at_the_def(self) -> None:
        exports, _ = self._parse(CLEAN_MOJO)
        self.assertEqual(exports[0]["line"], 2)     # the `def`, not the decorator
        self.assertEqual(exports[1]["line"], 7)

    def test_bare_export_decorator_yields_nothing(self) -> None:
        """Documents the fixture trap: `@export` alone has no symbol name."""
        exports, _ = self._parse("@export\ndef k(a: Int) abi(\"C\") -> Int:\n    return a\n")
        self.assertEqual(exports, [])

    def test_raising_calls_in_the_body_are_flagged(self) -> None:
        exports, lines = self._parse(MESSY_MOJO)
        findings = self.mf.lint(exports, lines)
        issues = " ".join(f[3] for f in findings)
        self.assertIn('Int("...") raises', issues)
        self.assertIn("explicit raise", issues)
        self.assertIn("`out` is reserved", issues)
        self.assertIn("non-scalar parameter", issues)

    def test_comments_do_not_raise_findings(self) -> None:
        exports, lines = self._parse('@export("k")\ndef k(a: Int) abi("C") -> Int:\n'
                                      '    # Int("42") would raise, but this is a comment\n'
                                      '    return a\n')
        issues = " ".join(f[3] for f in self.mf.lint(exports, lines))
        self.assertNotIn('Int("...") raises', issues)

    def test_findings_do_not_bleed_into_the_next_export(self) -> None:
        """A raising call in export 1 must not be attributed to export 2."""
        exports, lines = self._parse(
            '@export("a")\ndef a(x: Int) abi("C") -> Int:\n    return Int("1")\n\n'
            '@export("b")\ndef b(x: Int) abi("C") -> Int:\n    return x\n')
        bad = {f[2] for f in self.mf.lint(exports, lines) if 'Int("...")' in f[3]}
        self.assertEqual(bad, {"a"})


class ReportTest(mojo_toolkit.ToolTestCase):
    tool = "mojoffi"

    def test_clean_source_has_no_findings(self) -> None:
        src = write(self.tmp / "k.mojo", CLEAN_MOJO)
        r = self.run_tool(str(src))
        self.assertEqual(r.rc, 0, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertIn("2 exported symbol(s)", r.out)
        self.assertIn("none — every export is scalar-typed", r.out)
        self.assertIn("**verdict:** 0 blocking", r.out)

    def test_findings_exit_one_with_a_verdict(self) -> None:
        """exit 1 is reserved for findings, so a clean exit means 'nothing found'."""
        src = write(self.tmp / "messy.mojo", MESSY_MOJO)
        r = self.run_tool(str(src))
        self.assertEqual(r.rc, 1, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertIn("## findings", r.out)
        self.assertIn("blocking", r.out)

    def test_missing_file(self) -> None:
        r = self.run_tool(str(self.tmp / "nope.mojo"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such file", r.text)

    def test_no_exports(self) -> None:
        src = write(self.tmp / "none.mojo", NO_EXPORTS_MOJO)
        r = self.run_tool(str(src))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no @export defs found", r.text)
        self.assertNotIn("Traceback", r.text)


class EmitTest(mojo_toolkit.ToolTestCase):
    tool = "mojoffi"

    def setUp(self) -> None:
        super().setUp()
        self.src = write(self.tmp / "kernels.mojo", CLEAN_MOJO)

    def test_bridge_is_valid_python(self) -> None:
        r = self.run_tool("--emit", "bridge", str(self.src))
        self.assertEqual(r.rc, 0, r.text)
        compile(r.out, "bridge.py", "exec")          # a broken bridge is the whole bug
        self.assertIn("def add_kernels(a, b):", r.out)
        self.assertIn("def scale(x, k):", r.out)
        self.assertIn("ctypes.c_int64", r.out)

    def test_bridge_restypes_the_return_value(self) -> None:
        """A wrong restype silently turns an Int status code into None."""
        r = self.run_tool("--emit", "bridge", str(self.src))
        self.assertIn('"add_kernels": ([ctypes.c_int64, ctypes.c_int64], ctypes.c_int64)',
                      r.out)
        self.assertIn('"scale": ([ctypes.c_double, ctypes.c_double], ctypes.c_double)',
                      r.out)

    def test_bridge_lib_name_is_derived(self) -> None:
        r = self.run_tool("--emit", "bridge", str(self.src))
        self.assertIn("libkernels.so", r.out)

    def test_bridge_lib_name_can_be_overridden(self) -> None:
        r = self.run_tool("--emit", "bridge", "--lib", "libcustom.so", str(self.src))
        self.assertIn("libcustom.so", r.out)

    def test_test_skeleton_is_valid_python(self) -> None:
        r = self.run_tool("--emit", "test", str(self.src))
        self.assertEqual(r.rc, 0, r.text)
        compile(r.out, "test_native.py", "exec")
        self.assertIn("def test_all_symbols_resolve():", r.out)
        self.assertIn("EXPORTS = ['add_kernels', 'scale']", r.out)


requires_nm = unittest.skipUnless(have("nm"), "nm missing (binutils; mojoffi --check)")


class CheckTest(mojo_toolkit.ToolTestCase):
    """`--check` compares the parsed export names against a built .so."""

    tool = "mojoffi"

    def setUp(self) -> None:
        super().setUp()
        if not CC:
            self.skipTest("no C compiler for the .so fixture")
        self.src = write(self.tmp / "kernels.mojo", CLEAN_MOJO)
        c = write(self.tmp / "lib.c",
                  "int add_kernels(int a, int b) { return a + b; }\n"
                  "double scale(double x, double k) { return x * k; }\n")
        self.so = self.tmp / "libkernels.so"
        r = subprocess.run([CC, "-shared", "-fPIC", "-O0", "-o", str(self.so), str(c)],
                           capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.partial = write(self.tmp / "lib.c",
                             "int add_kernels(int a, int b) { return a + b; }\n")
        self.partial_so = self.tmp / "libpartial.so"
        r = subprocess.run([CC, "-shared", "-fPIC", "-O0", "-o", str(self.partial_so),
                            str(self.partial)], capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)

    @requires_nm
    def test_all_symbols_present(self) -> None:
        r = self.run_tool(str(self.src), "--check", str(self.so))
        self.assertEqual(r.rc, 0, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertIn("## link check", r.out)
        self.assertIn("ok   `add_kernels`", r.out)
        self.assertIn("all 2 symbols present", r.out)

    @requires_nm
    def test_missing_symbol_is_reported_and_blocks(self) -> None:
        r = self.run_tool(str(self.src), "--check", str(self.partial_so))
        self.assertEqual(r.rc, 1, r.text)
        self.assertIn("MISS `scale`", r.out)
        self.assertIn("symbol(s) missing", r.out)

    def test_missing_library_is_explained(self) -> None:
        r = self.run_tool(str(self.src), "--check", str(self.tmp / "nope.so"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such library", r.text)
        self.assertNotIn("Traceback", r.text)

    def test_missing_nm_is_explained(self) -> None:
        empty = self.tmp / "emptybin"
        empty.mkdir(exist_ok=True)
        r = self.run_tool(str(self.src), "--check", str(self.so),
                          env={"PATH": str(empty)}, timeout=60)
        self.assertEqual(r.rc, 2, r.text)
        self.assertNotIn("Traceback", r.text)
        if not have("nm"):
            self.assertIn("nm not found", r.text)


if __name__ == "__main__":
    unittest.main()