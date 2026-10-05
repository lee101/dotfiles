#!/usr/bin/env python3
"""Tests for tools/mojo/bin/mojolint — the static perf + dialect scanner.

mojolint is the highest-value target here: it is the tool whose failure is silent.
If it stops firing (or starts firing on valid code), nothing crashes, the report
just quietly stops saying anything, and a compile-breaking Mojo 0.x idiom sails
through review. Every rule in RULES gets a fixture that must trip it, and a block
of valid Mojo 1.0 that must produce no findings at all.

The last test is the design test for the whole task: lint a real .mojo file in
this repository that is independently known to compile on Mojo 1.0, and require
zero dialect errors. A dialect error there is a false positive in the rules.
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import mojo_toolkit  # noqa: E402
from mojo_toolkit import REPO_DIR, write, write_mojo  # noqa: E402

# The reference file for this repository: verified to compile on
# mojo 1.0.0b3.dev2026072406, so any dialect "err" mojolint reports on it is wrong.
REAL_MOJO = REPO_DIR / "profiling" / "mojo" / "profile_md.mojo"

# (rule id, category, severity, fixture body). One violation per file so a rule
# that stops firing is blamed on itself and not on a neighbour.
# Derived from RULES at tools/mojo/bin/mojolint:15.
DIALECT_FIXTURES = [
    ("fn-removed", "dialect", "err", """
fn axpy(a, b):
    return a
"""),
    ("alias", "dialect", "err", """
alias W = 8
"""),
    ("bare-import", "dialect", "err", """
from sys.info import simd_width_of
"""),
    ("old-names", "dialect", "err", """
comptime W = simdwidthof[DType.float32]()
"""),
    ("ptr-alloc", "dialect", "err", """
def alloc4() -> UnsafePointer[Float32]:
    return UnsafePointer[Float32].alloc(4)
"""),
    ("memset", "dialect", "warn", """
def zero(p: UnsafePointer[Float32]):
    memset_zero(p, 0, 4)
"""),
    ("span-ptr", "dialect", "err", """
def view(p: UnsafePointer[Float32]):
    return Span[Float32](ptr=p, length=4)
"""),
    ("capacity-attr", "dialect", "err", """
def room(l: List[Int]) -> Int:
    return l.capacity
"""),
    ("simd-minmax", "dialect", "err", """
def clamp(a: Float32, b: Float32, c: Float32) -> Float32:
    return (a + b).min(c)
"""),
    ("mut-origin", "dialect", "err", """
def ptr() -> UnsafePointer[Float32, MutableAnyOrigin]:
    return UnsafePointer[Float32, MutableAnyOrigin]()
"""),
    # `out` is not reserved in Mojo 1.0 (verified on 1.0.0b3.dev2026072406), so the
    # rule only fires on the argument form the compiler actually rejects.
    ("out-name", "dialect", "err", """
def store(@parameter out: Int):
    pass
"""),
    ("fn-name", "dialect", "err", """
def reserved():
    var fn = 3
"""),
    ("simd-eq", "dialect", "err", """
def mask(cur: Float32, w: Int) -> Bool:
    return cur == SIMD[DType.float32, w](0)
"""),
    ("tuple-ret", "dialect", "err", """
def pair() -> (Int, Float64):
    return 1, 2.0
"""),
    ("vectorize", "dialect", "warn", """
def ramp(step: Int, n: Int):
    vectorize[step](n)
"""),
]

PERF_FIXTURES = [
    ("str-concat", "perf", "err", """
def build(n: Int) -> String:
    var s = String("")
    for i in range(n):
        s += "x"
    return s
"""),
    ("alloc-in-loop", "perf", "err", """
def per_iteration(n: Int):
    for i in range(n):
        var p = alloc[Float32](n)
        p[0] = 1
"""),
    ("print-hot", "perf", "warn", """
def chatty(n: Int):
    for i in range(n):
        print(i)
"""),
    ("reduce-in-loop", "perf", "err", """
from std.math import fma
from std.sys.info import simd_width_of

comptime W = simd_width_of[DType.float32]()

def dot(p: UnsafePointer[Float32, AnyOrigin[mut=True]], n: Int) -> Float32:
    var acc = SIMD[DType.float32, W](0)
    var total = Float32(0)
    for i in range(0, n, W):
        acc = fma(p.load[width=W](i), p.load[width=W](i), acc)
        total = acc.reduce_add()
    return total
"""),
    ("len-in-range", "perf", "warn", """
def total(x: List[Int]) -> Int:
    var t = 0
    for i in range(len(x)):
        t += x[i]
    return t
"""),
    ("sync-per-launch", "perf", "err", """
def launch_all(ctx: AnyOrigin, n: Int):
    for k in range(n):
        ctx.synchronize()
"""),
    ("hardcoded-width", "perf", "warn", """
def splat(x: Float32) -> SIMD[DType.float32, 8]:
    return SIMD[DType.float32, 8](x)
"""),
    ("copy-noxfer", "perf", "info", """
def dup(a: SIMD[DType.float32, 8]):
    for i in range(4):
        var b = a
"""),
    ("py-interop", "perf", "warn", """
def load_mod():
    var m = Python.import_module("math")
    return m
"""),
]

# contextual() rules — these need more than one line to express
CONTEXTUAL_FIXTURES = [
    ("export-abi", "dialect", "err", """
@export("capi_add")
def capi_add(a: Int, b: Int) -> Int:
    return a + b
"""),
    ("append-noreserve", "perf", "warn", """
def collect(n: Int) -> List[Int]:
    var out_list = List[Int]()
    for i in range(n):
        out_list.append(i)
    return out_list
"""),
    # three or more scalar `x[i]` in the body, no `load[width=` and no `store(`,
    # and no `def`/`struct` statement inside the body to disarm the check
    ("scalar-loop", "perf", "warn", """
def saxpy(a: UnsafePointer[Float32, AnyOrigin[mut=True]], b: UnsafePointer[Float32, AnyOrigin[mut=True]], c: UnsafePointer[Float32, AnyOrigin[mut=True]], n: Int):
    for i in range(n):
        b[i] = a[i] * 2.0 + c[i]
        b[i] = b[i] + a[i]
"""),
]

ALL_FIXTURES = DIALECT_FIXTURES + PERF_FIXTURES + CONTEXTUAL_FIXTURES

ROW_RE = re.compile(r"^\|\s*(?P<sev>\w+)(?P<loop>\s+L\d+)?\s*\|\s*`(?P<loc>[^`]+)`\s*\|"
                    r"\s*(?P<rule>[\w-]+)\s*\|")


def parse_rows(out: str):
    """[(sev, loop_depth, path, lineno, rule)] from the markdown table."""
    rows = []
    for line in out.splitlines():
        m = ROW_RE.match(line)
        if m:
            loc = m.group("loc")
            path, _, lineno = loc.rpartition(":")
            rows.append((m.group("sev"), int((m.group("loop") or " L0")[2:]),
                         path, int(lineno), m.group("rule")))
    return rows


class MojolintRuleTest(mojo_toolkit.ToolTestCase):
    tool = "mojolint"
    usage_token = "mojolint"

    # ---- one fixture per rule, each scanned alone ----------------------------

    def test_each_dialect_rule_fires_with_its_severity(self) -> None:
        for rid, cat, sev, body in DIALECT_FIXTURES:
            with self.subTest(rule=rid):
                p = write_mojo(self.tmp, f"{rid}.mojo", body)
                r = self.run_tool(str(p))
                self.assertNotIn("Traceback", r.text)
                rows = [x for x in parse_rows(r.out) if x[4] == rid]
                self.assertTrue(rows, f"{rid} did not fire on its own fixture:\n{r.out}")
                self.assertEqual(rows[0][0], sev, f"{rid} severity in:\n{r.out}")
                if sev == "err":
                    self.assertEqual(r.rc, 1, f"{rid} is an err rule, exit must be 1")

    def test_each_perf_rule_fires_with_its_severity(self) -> None:
        for rid, cat, sev, body in PERF_FIXTURES:
            with self.subTest(rule=rid):
                p = write_mojo(self.tmp, f"{rid}.mojo", body)
                r = self.run_tool(str(p))
                self.assertNotIn("Traceback", r.text)
                rows = [x for x in parse_rows(r.out) if x[4] == rid]
                self.assertTrue(rows, f"{rid} did not fire on its own fixture:\n{r.out}")
                self.assertEqual(rows[0][0], sev, f"{rid} severity in:\n{r.out}")
                if sev == "err":
                    self.assertEqual(r.rc, 1, f"{rid} is an err rule, exit must be 1")

    def test_each_contextual_rule_fires_with_its_severity(self) -> None:
        for rid, cat, sev, body in CONTEXTUAL_FIXTURES:
            with self.subTest(rule=rid):
                p = write_mojo(self.tmp, f"{rid}.mojo", body)
                r = self.run_tool(str(p))
                self.assertNotIn("Traceback", r.text)
                rows = [x for x in parse_rows(r.out) if x[4] == rid]
                self.assertTrue(rows, f"{rid} did not fire on its own fixture:\n{r.out}")
                self.assertEqual(rows[0][0], sev, f"{rid} severity in:\n{r.out}")

    def test_category_selects_the_right_rules(self) -> None:
        """`--only` is the only way the category is visible in the output."""
        tree = self.tmp / "mixed"
        for i, (rid, cat, sev, body) in enumerate(ALL_FIXTURES):
            write_mojo(tree, f"{i:02d}_{rid}.mojo", body)

        dialect = parse_rows(self.run_tool("--only", "dialect", str(tree)).out)
        perf = parse_rows(self.run_tool("--only", "perf", str(tree)).out)
        everything = parse_rows(self.run_tool(str(tree)).out)

        dialect_ids = {x[4] for x in dialect}
        perf_ids = {x[4] for x in perf}
        self.assertFalse(dialect_ids & perf_ids, "--only leaked across categories")
        self.assertEqual(dialect_ids | perf_ids, {x[4] for x in everything})
        self.assertEqual(len(everything), len(dialect) + len(perf))

        for rid, cat, sev, body in ALL_FIXTURES:
            with self.subTest(rule=rid):
                side = dialect_ids if cat == "dialect" else perf_ids
                self.assertIn(rid, side, f"{rid} is {cat} but --only put it elsewhere")

    # ---- valid Mojo 1.0 must stay quiet --------------------------------------

    CLEAN = """
from std.collections import List
from std.memory import alloc
from std.math import fma
from std.sys.info import simd_width_of, size_of

comptime W = simd_width_of[DType.float32]()

def axpy(a: UnsafePointer[Float32, AnyOrigin[mut=True]], n: Int, k: Float32) -> Float32:
    var acc = SIMD[DType.float32, W](0)
    var tail = n - (n % W)
    for i in range(0, tail, W):
        acc = fma(a.load[width=W](i), k, acc)
    var total = acc.reduce_add()
    for i in range(tail, n):
        total += a[i] * k
    return total

def room(l: List[Float32]) -> Int:
    l.reserve(64)
    return Int(l.capacity())

def pair() -> Tuple[Int, Float64]:
    return (1, 2.0)

@export("capi_axpy")
def capi_axpy(a_addr: Int, n: Int, k: Float64) abi("C") -> None:
    var a = UnsafePointer[Float32, AnyOrigin[mut=True]](unsafe_from_address=a_addr)
    axpy(a, n, Float32(k))

def masked(a: SIMD[DType.float32, W]) -> SIMD[DType.float32, W]:
    return min(a, SIMD[DType.float32, W](0))
"""

    def test_valid_mojo_1_0_produces_no_findings(self) -> None:
        p = write_mojo(self.tmp, "clean.mojo", self.CLEAN)
        r = self.run_tool(str(p))
        self.assertNotIn("Traceback", r.text)
        self.assertIn("clean", r.out)
        self.assertEqual(parse_rows(r.out), [], f"false positives on valid Mojo:\n{r.out}")
        self.assertEqual(r.rc, 0)

    def test_zero_x_priors_are_caught(self) -> None:
        """The four priors the dialect skill claims mojolint catches.

        Each pair is the same program written the two ways: the 1.0 form must be
        silent, the 0.x form must trip exactly the rule that names the rename.
        """
        alloc_good = (
            "from std.memory import alloc\n"
            "\n"
            "def f() -> Pointer[Float32, MutUntrackedOrigin]:\n"
            "    return alloc[Float32](4)\n"
        )
        cases = {
            "fn": ("def f() -> Int:\n    return 1\n", "fn f() -> Int:\n    return 1\n", "fn-removed"),
            "alias": ("comptime W = 8\n", "alias W = 8\n", "alias"),
            "simd_width_of": ("comptime W = simd_width_of[DType.float32]()\n",
                              "comptime W = simdwidthof[DType.float32]()\n", "old-names"),
            "alloc[T]": (alloc_good, "def f():\n    return UnsafePointer[Float32].alloc(4)\n",
                         "ptr-alloc"),
        }
        for name, (good, bad, rid) in cases.items():
            with self.subTest(prior=name):
                gp = write_mojo(self.tmp, f"good_{name}.mojo", good)
                bp = write_mojo(self.tmp, f"bad_{name}.mojo", bad)
                self.assertEqual(parse_rows(self.run_tool(str(gp)).out), [],
                                 f"{name}: 1.0 form flagged")
                self.assertIn(rid, {x[4] for x in parse_rows(self.run_tool(str(bp)).out)},
                              f"{name}: 0.x form not flagged")

    # ---- deliberate negatives, one per rule with a cheap near-miss -----------

    def test_near_misses_do_not_fire(self) -> None:
        cases = [
            ("capacity-method-is-legal", "def f(l: List[Int]) -> Int:\n    return l.capacity()\n"),
            ("reduce-outside-the-loop-is-legal",
             "from std.math import fma\nfrom std.sys.info import simd_width_of\n\n"
             "comptime W = simd_width_of[DType.float32]()\n\n"
             "def dot(p: UnsafePointer[Float32, AnyOrigin[mut=True]], n: Int) -> Float32:\n"
             "    var acc = SIMD[DType.float32, W](0)\n"
             "    for i in range(0, n, W):\n"
             "        acc = fma(p.load[width=W](i), p.load[width=W](i), acc)\n"
             "    return acc.reduce_add()\n"),
            ("reduce-in-a-chunk-loop-is-legal",
             "from std.math import fma\nfrom std.sys.info import simd_width_of\n\n"
             "comptime W = simd_width_of[DType.float32]()\n\n"
             "def dot(p: UnsafePointer[Float32, AnyOrigin[mut=True]], n: Int) -> Float32:\n"
             "    var acc = SIMD[DType.float32, W](0)\n"
             "    for i in range(0, n, W):\n"
             "        var v = p.load[width=W](i)\n"
             "        acc = fma(v, v, acc)\n"
             "    return acc.reduce_add()\n"),
            ("reserve-present-suppresses-append-noreserve",
             "def collect(n: Int) -> List[Int]:\n    var acc = List[Int]()\n"
             "    acc.reserve(n)\n    for i in range(n):\n        acc.append(i)\n"
             "    return acc\n"),
            ("abi-c-is-legal",
             "@export(\"capi_add\")\ndef capi_add(a: Int, b: Int) abi(\"C\") -> Int:\n"
             "    return a + b\n"),
            ("std-namespaced-import-is-legal",
             "from std.sys.info import simd_width_of\nfrom std.collections import List\n"),
            ("two-param-unsafe-pointer-alloc-is-still-the-old-api",
             "def f():\n    return UnsafePointer[Float32, AnyOrigin[mut=True]].alloc(4)\n"),
            ("narrow-loop-is-not-scalar-loop",
             "def f(n: Int) -> Int:\n    var t = 0\n    for i in range(n):\n"
             "        t += i\n    return t\n"),
        ]
        for name, body in cases:
            with self.subTest(case=name):
                p = write_mojo(self.tmp, f"{name}.mojo", body)
                r = self.run_tool(str(p))
                self.assertEqual(parse_rows(r.out), [], f"false positive in {name}:\n{r.out}")

    # ---- markdown shape and --top --------------------------------------------

    def test_markdown_shape_on_a_multi_file_tree(self) -> None:
        tree = self.tmp / "src" / "nested" / "deep"
        write_mojo(tree, "a.mojo", "fn a():\n    pass\n")
        write_mojo(tree, "b.mojo", "alias W = 8\n")
        write_mojo(self.tmp / "src", "top.mojo", "fn c():\n    pass\n")
        write(self.tmp / "src" / "README.md", "fn not_mojo():\n    pass\n")

        r = self.run_tool(str(self.tmp / "src"))
        lines = r.out.splitlines()
        self.assertTrue(lines[0].startswith("# mojolint — "))
        self.assertRegex(lines[0], r"3 files, 3 findings \(3 err\)")
        # heading, blank line, table header, table rule — in that order
        self.assertEqual(lines[1], "")
        self.assertEqual(lines[2], "| sev | loc | rule | what | fix |")
        self.assertEqual(lines[3], "|---|---|---|---|---|")
        self.assertIn("**by rule:**", r.out)
        self.assertEqual(r.rc, 1)
        # every .mojo found, nothing else
        self.assertIn("deep/a.mojo", r.out)
        self.assertIn("top.mojo", r.out)
        self.assertNotIn("README.md", r.out)

    def test_top_truncates_the_table_and_says_so(self) -> None:
        tree = self.tmp / "many"
        for i in range(6):
            write_mojo(tree, f"f{i}.mojo", f"fn f{i}():\n    pass\n")
        full = self.run_tool("--top", "40", str(tree))
        self.assertEqual(len(parse_rows(full.out)), 6)
        cut = self.run_tool("--top", "2", str(tree))
        rows = parse_rows(cut.out)
        self.assertEqual(len(rows), 2)
        self.assertIn("_4 more", cut.out)
        self.assertNotIn("_40 more", cut.out)

    def test_exit_codes_reserve_one_for_findings(self) -> None:
        """0 clean, 1 findings, 2 could-not-run — CI tells them apart."""
        write_mojo(self.tmp, "warn.mojo", "from sys.info import x\n")  # alias is an err
        warn_only = write_mojo(self.tmp, "w.mojo",
                               "for i in range(4):\n    print(i)\n")
        # print-hot is a warn at depth 1 -> 0 findings errors -> exit 0
        r = self.run_tool(str(warn_only))
        self.assertTrue(parse_rows(r.out), "print-hot fixture produced no findings")
        self.assertEqual(r.rc, 0, "a warn-only file must not fail CI")

        missing = self.run_tool(str(self.tmp / "nope.mojo"))
        self.assertEqual(missing.rc, 2)
        self.assertIn("no such path", missing.err)

        notmojo = write(self.tmp / "x.py", "fn x():\n    pass\n")
        self.assertEqual(self.run_tool(str(notmojo)).rc, 2)

        empty = self.tmp / "empty"
        empty.mkdir()
        r = self.run_tool(str(empty))
        self.assertEqual(r.rc, 2)
        self.assertIn("no .mojo files found", r.err)

    def test_scan_prunes_vcs_and_build_dirs(self) -> None:
        for junk in (".pixi", ".git", "build", "__pycache__"):
            write_mojo(self.tmp / "src" / junk, "junk.mojo", "fn junk():\n    pass\n")
        write_mojo(self.tmp / "src", "real.mojo", "fn real():\n    pass\n")
        r = self.run_tool(str(self.tmp / "src"))
        self.assertEqual(r.rc, 1)
        self.assertIn("1 files, 1 findings", r.out)

    # ---- the real repository -------------------------------------------------

    @unittest.skipUnless(REAL_MOJO.is_file(), f"{REAL_MOJO} is not in this checkout")
    def test_real_repo_mojo_has_no_dialect_errors(self) -> None:
        """The design test: this file compiles on Mojo 1.0, so no dialect err."""
        r = self.run_tool("--only", "dialect", str(REAL_MOJO))
        self.assertNotIn("Traceback", r.text)
        errs = [x for x in parse_rows(r.out) if x[0] == "err"]
        self.assertEqual(errs, [], f"false-positive dialect errors on {REAL_MOJO}:\n{r.out}")
        self.assertEqual(r.rc, 0, r.out)

    def test_lint_its_own_fixtures(self) -> None:
        """Every fixture that exists to be a violation does trip something."""
        tree = self.tmp / "fixtures"
        for rid, cat, sev, body in ALL_FIXTURES:
            write_mojo(tree, f"{rid}.mojo", body)
        r = self.run_tool(str(tree))
        fired = {x[4] for x in parse_rows(r.out)}
        expected = {rid for rid, _, _, _ in ALL_FIXTURES}
        self.assertEqual(expected - fired, set(), "fixture did not trip its own rule")


if __name__ == "__main__":
    unittest.main()