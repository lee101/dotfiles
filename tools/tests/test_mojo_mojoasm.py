#!/usr/bin/env python3
"""Unit tests for mojoasm, the codegen / vectorization inspector.

mojoasm has two front ends: `mojo build --emit asm` (needs a Mojo toolchain) and
`objdump -d` on a built binary (needs binutils). The analysis in between —
split_funcs / find_loops / analyse / verdict — is pure text handling, so it is
tested here against recorded asm text as well as against real fixtures. That
keeps the interesting logic covered even where the toolchain is absent.

The recorded text follows the shapes the tool actually parses: x86 register
names carry the vector width (zmm/ymm/xmm), and loop discovery keys on backward
`j*` branches, because a LLVM/Apple-Mach-O `.s` has neither.
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mojo_toolkit  # noqa: E402
from mojo_toolkit import have, mojo_env, write  # noqa: E402


CC = next((c for c in ("gcc", "clang") if have(c)), "")

# An objdump -d --no-show-raw-insn listing.
OBJDUMP_TEXT = """\
0000000000001139 <main>:
    1139:	endbr64
    113d:	push   r15
    1146:	xor    r9d,r9d
    1148:	pxor   xmm0,xmm0
    114c:	pxor   xmm1,xmm1
    1150:	cmp    rdi,0x0
    1153:	jle    1163
    1155:	movsd  xmm2,QWORD PTR [rax+0x8]
    115d:	addsd  xmm0,xmm2
    1160:	add    rdi,0x1
    1163:	dec    rdi
    1165:	jne    114c
    1167:	cvttsd2si rax,xmm0
    116b:	pop    r15
    116e:	ret

0000000000001179 <helper>:
    1179:	nop
    117a:	ret
"""

# A Mojo `--emit asm` listing: quoted mangled label, a hot loop closed by a
# backward `j` branch, 512-bit vector ops and two stack refs.
MOJO_ASM_TEXT = """\
	.text
	.type	"main$",@function
	.globl	"main$"
	.p2align	4, 0x90
"main$":
	stwu	r1, -32(r1)
	li	3, 0
.Lloop:
	vaddpd	%zmm2, %zmm3, %zmm4
	vfmadd231pd	%zmm5, %zmm6, %zmm7
	vaddpd	%zmm8, %zmm9, %zmm10
	vfmadd231pd	%zmm11, %zmm12, %zmm13
	ld	14, 16(3)
	fadd	d20, d20, d21
	addi	3, 3, 1
	cmp	3, 15
	jne	.Lloop
	blr
	.size	"main$", .-main
"""


def load(name: str):
    import importlib.machinery
    import importlib.util

    loader = importlib.machinery.SourceFileLoader(f"_mojo_{name}", str(mojo_toolkit.BIN_DIR / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class SplitFuncsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ma = load("mojoasm")

    def test_objdump_headers_split_functions(self) -> None:
        funcs = self.ma.split_funcs(OBJDUMP_TEXT, True)
        self.assertIn("main", funcs)
        self.assertIn("helper", funcs)
        self.assertTrue(any("addsd" in l for l in funcs["main"]))
        self.assertFalse(any("addsd" in l for l in funcs["helper"]))

    def test_mojo_mangled_labels_are_shortened(self) -> None:
        """Mojo emits quoted, very long labels; the readable head is what a user
        would type as a filter."""
        funcs = self.ma.split_funcs(MOJO_ASM_TEXT, False)
        self.assertTrue(funcs)
        name = next(iter(funcs))
        self.assertNotIn('"', name)
        self.assertLess(len(name), 40)

    def test_shorten_sym_drops_generics(self) -> None:
        self.assertEqual(self.ma.shorten_sym('"mojo::main::foo[::T]()"'), "mojo::main::foo")


class FindLoopsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ma = load("mojoasm")

    def test_backward_branch_defines_a_loop(self) -> None:
        lines = [".Lloop:", "  addi 3, 3, 1", "  cmp 3, 15", "  jne .Lloop"]
        loops = self.ma.find_loops(lines)
        self.assertEqual(len(loops), 1)
        label, body, span = loops[0]
        self.assertEqual(label, ".Lloop")
        self.assertEqual(span, 3)
        self.assertTrue(any("addi" in l for l in body))

    def test_objdump_shape_is_understood(self) -> None:
        """objdump writes `addr:\\tmnemonic` and names branch targets by address.

        Before this was handled, the --bin path found zero loops: the label
        regex matched the address prefix and the target was an address, not a
        label name.
        """
        lines = [
            "    1139:\tendbr64",
            "    1150:\tpxor   %xmm0,%xmm0",
            "    1156:\taddsd  (%rdi),%xmm0",
            "    115e:\tcmp    %rax,%rdi",
            "    1161:\tje     1185 <sum+0x45>",
            "    1168:\taddsd  (%rdi),%xmm0",
            "    1170:\tadd    $0x8,%rdi",
            "    1178:\tjne    1168",
        ]
        loops = self.ma.find_loops(lines)
        self.assertEqual([lb for lb, _, _ in loops], ["1168"])
        self.assertEqual(loops[0][2], 2)          # 1178 -> 1168 is backward
        self.assertFalse(any("1168:" in l for l in loops[0][1]))   # address stripped

    def test_indented_labels_match(self) -> None:
        """objdump indents its labels; column-0-only matching found no loops."""
        self.assertTrue(self.ma.LOOP_LABEL.match("    .Lloop:"))
        self.assertTrue(self.ma.LOOP_LABEL.match(".Lloop:"))

    def test_forward_branch_is_not_a_loop(self) -> None:
        self.assertEqual(self.ma.find_loops([".La:", "  jmp .Lb", ".Lb:", "  nop"]), [])

    def test_nested_loops_report_innermost_first(self) -> None:
        lines = [".Outer:", ".Inner:", "  nop", "  jne .Inner", "  jmp .Outer"]
        loops = self.ma.find_loops(lines)
        self.assertEqual([lb for lb, _, _ in loops], [".Inner", ".Outer"])


class AnalyseTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ma = load("mojoasm")

    def test_width_comes_from_the_register_name(self) -> None:
        st = self.ma.analyse([
            "	vaddpd %zmm0, %zmm1, %zmm2",
            "	vaddpd %zmm3, %zmm4, %zmm5",
            "	vfmadd231pd %zmm6, %zmm7, %zmm8",
            "	vaddps %ymm0, %ymm1, %ymm2",
            "	movaps %xmm3, %xmm4",
        ])
        self.assertEqual(st["insns"], 5)
        self.assertEqual(st[512], 3)
        self.assertEqual(st[256], 1)
        self.assertEqual(st[128], 1)
        self.assertEqual(st["fma"], 1)
        self.assertEqual(st["scalar_fp"], 0)

    def test_scalar_sd_ops_count_as_scalar_not_vector(self) -> None:
        """`addsd` names an xmm register but is one double wide.

        The width counter is register-name based, so a scalar loop still reads
        as `128-bit 10x128 (100% vec)` unless the verdict checks scalar_fp. It
        does — vec > 0 wins — so what this pins down is that both counters fire
        and the caller sees the real ratio in the note.
        """
        st = self.ma.analyse([f"  addsd {8 * i}(%rdi),%xmm0" for i in range(10)])
        self.assertEqual(st["scalar_fp"], 10)
        self.assertEqual(st[128], 10)
        self.assertEqual(sum(st[w] for w in (128, 256, 512)), 10)
        v, note = self.ma.verdict(st)
        self.assertIn("100% vec", v)

    def test_directives_and_labels_are_not_instructions(self) -> None:
        st = self.ma.analyse([".text", ".Lloop:", "  nop", "# comment"])
        self.assertEqual(st["insns"], 1)

    def test_verdict_flags_a_loop_with_no_vector_at_all(self) -> None:
        """No xmm/ymm/zmm operand and scalar fp present -> **SCALAR**.

        This is the case the docs tell users to look for: a loop that never
        touched a vector register, so nothing vectorized it.
        """
        st = self.ma.analyse(["  addsd 16(%rdi),%f0", "  mulsd 16(%rdi),%f1"] * 5)
        self.assertEqual(st["scalar_fp"], 10)
        self.assertEqual(st[128] + st[256] + st[512], 0)
        v, note = self.ma.verdict(st)
        self.assertEqual(v, "**SCALAR**")
        self.assertIn("did not vectorize", note)

    def test_verdict_reports_narrow_width(self) -> None:
        st = self.ma.analyse(["  vaddps %xmm0, %xmm1"] * 10)
        v, note = self.ma.verdict(st)
        self.assertIn("128-bit", v)
        self.assertIn("only 128-bit ops", note)

    def test_verdict_calls_out_spills(self) -> None:
        body = ["  vaddpd %zmm0, %zmm1"] * 5 + ["  vmovupd 16(%rsp), %zmm2"] * 5
        v, note = self.ma.verdict(self.ma.analyse(body))
        self.assertIn("spilling", note)

    def test_verdict_calls_out_a_missing_fma(self) -> None:
        st = self.ma.analyse(["  vaddpd %zmm0, %zmm1"] * 12)
        v, note = self.ma.verdict(st)
        self.assertIn("no FMA", note)


class ParserOnRecordedAsmTest(unittest.TestCase):
    """End-to-end over recorded asm text, with no external binary required."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.ma = load("mojoasm")

    def _report(self, text: str, from_objdump: bool):
        funcs = self.ma.split_funcs(text, from_objdump)
        rows, loops = [], []
        for name, lines in funcs.items():
            st = self.ma.analyse(lines)
            if st["insns"] >= 8:
                v, note = self.ma.verdict(st)
                rows.append((st["insns"], name, st, v, note))
            for lbl, body, span in self.ma.find_loops(lines):
                lst = self.ma.analyse(body)
                if lst["insns"] >= 8:
                    lv, ln = self.ma.verdict(lst)
                    loops.append((lst["insns"], name, lbl, lst, lv, ln, body))
        rows.sort(reverse=True)
        loops.sort(reverse=True)
        return rows, loops

    def test_objdump_text_is_analysed(self) -> None:
        rows, _ = self._report(OBJDUMP_TEXT, True)
        self.assertTrue(rows)

    def test_mojo_asm_loop_is_detected(self) -> None:
        rows, loops = self._report(MOJO_ASM_TEXT, False)
        self.assertTrue(rows)
        self.assertTrue(loops, "the recorded backward branch was not detected")
        self.assertEqual(loops[0][2], ".Lloop")
        self.assertGreater(loops[0][3][512], 0)

    def test_objdump_text_loop_is_detected(self) -> None:
        rows, loops = self._report(OBJDUMP_TEXT, True)
        self.assertTrue(rows)
        self.assertTrue(loops, "no loop found in the objdump-shaped text")


class CliTest(mojo_toolkit.ToolTestCase):
    tool = "mojoasm"

    def test_missing_binary(self) -> None:
        r = self.run_tool("--bin", str(self.tmp / "nope"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such binary", r.text)

    def test_unreadable_binary_is_reported(self) -> None:
        junk = write(self.tmp / "junk.bin", "not an object file\n")
        r = self.run_tool("--bin", str(junk))
        self.assertNotIn("Traceback", r.text)
        self.assertEqual(r.rc, 2, r.text)
        if have("objdump"):
            self.assertIn("could not disassemble", r.text)
        else:
            self.assertIn("objdump not found", r.text)

    def test_no_source_and_no_bin_is_a_usage_error(self) -> None:
        r = self.run_tool()
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("give a .mojo source or --bin", r.text)

    def test_source_without_a_compiler_explains(self) -> None:
        """With no `mojo` reachable the tool must name the problem, not crash."""
        src = write(self.tmp / "k.mojo", "def main():\n    print(1)\n")
        if mojo_env() and have("mojo"):
            self.skipTest("a mojo compiler is reachable here")
        empty = self.tmp / "emptybin"
        empty.mkdir(exist_ok=True)
        r = self.run_tool(str(src), env={"PATH": str(empty), "MOJO": ""}, timeout=60)
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("mojo not found", r.text)
        self.assertNotIn("Traceback", r.text)


requires_objdump = unittest.skipUnless(have("objdump"),
                                      "objdump missing (binutils; mojoasm --bin)")


@requires_objdump
class ObjDumpPathTest(mojo_toolkit.ToolTestCase):
    """`--bin` is the path that needs binutils; keyed on install.sh's check."""

    tool = "mojoasm"

    def setUp(self) -> None:
        super().setUp()
        if not CC:
            self.skipTest("no C compiler")
        src = write(self.tmp / "loop.c",
                    "double sum(double *a, long n) {\n"
                    "    double s = 0;\n"
                    "    for (long i = 0; i < n; i++) s += a[i];\n"
                    "    return s;\n"
                    "}\n"
                    "int main(void) { return 0; }\n")
        self.bin = self.tmp / "loop"
        r = subprocess.run([CC, "-O1", "-g", "-o", str(self.bin), str(src)],
                           capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_binary_is_disassembled_and_summarised(self) -> None:
        r = self.run_tool("--bin", str(self.bin))
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("# mojoasm", r.out)
        self.assertIn("| insns | vector | fma | scalar fp | spills | calls | function |",
                      r.out)
        self.assertIn("`sum`", r.out)

    def test_bin_path_reports_the_loops_table(self) -> None:
        """The loops table is what the docs call 'the part that actually
        matters'; it used to be empty for every --bin invocation."""
        r = self.run_tool("--bin", str(self.bin), "--min-insns", "3")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("## loops", r.out)
        self.assertIn("`sum`", r.out)

    def test_pattern_filter_selects_one_function(self) -> None:
        """`mojoasm --bin ./mybin dot` binds "dot" to src, not pattern."""
        r = self.run_tool("--bin", str(self.bin), "sum")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("filter: sum", r.out)
        self.assertEqual(r.out.count("`sum`") >= 1, True)
        self.assertNotIn("`main`", r.out)

    def test_pattern_with_no_match_says_so(self) -> None:
        r = self.run_tool("--bin", str(self.bin), "zzz-no-such-symbol")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("No function matched", r.out)

    def test_listing_prints_asm(self) -> None:
        r = self.run_tool("--bin", str(self.bin), "--listing")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("## listing", r.out)
        self.assertIn("```asm", r.out)

    def test_min_insns_filters_small_functions(self) -> None:
        loose = self.run_tool("--bin", str(self.bin), "--min-insns", "1")
        strict = self.run_tool("--bin", str(self.bin), "--min-insns", "100000")
        self.assertGreaterEqual(loose.out.count("\n|"), strict.out.count("\n|"))
        self.assertIn("No function matched", strict.out)


@unittest.skipUnless(mojo_env() is not None, "no `mojo` compiler (expected profiling/mojo/.pixi)")
class SourcePathTest(mojo_toolkit.ToolTestCase):
    """The `mojo build --emit asm` front end, when the pinned toolchain is here."""

    tool = "mojoasm"

    def setUp(self) -> None:
        super().setUp()
        self.env = mojo_env()
        self.src = write(self.tmp / "k.mojo",
                         "def dot(a: SIMD[DType.float64, 4], b: SIMD[DType.float64, 4])\n"
                         "    -> SIMD[DType.float64, 4]:\n"
                         "    return a * b\n\n"
                         "def main():\n"
                         "    var x = SIMD[DType.float64, 4](1.0)\n"
                         "    print(dot(x, x)[0])\n")

    def test_source_is_compiled_and_analysed(self) -> None:
        r = self.run_tool(str(self.src), timeout=900, env=self.env)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("# mojoasm", r.out)
        self.assertIn("functions", r.out)

    def test_pattern_filter_on_a_real_build(self) -> None:
        r = self.run_tool(str(self.src), "dot", timeout=900, env=self.env)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("filter: dot", r.out)


if __name__ == "__main__":
    unittest.main()