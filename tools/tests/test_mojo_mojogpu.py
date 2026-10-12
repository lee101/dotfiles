#!/usr/bin/env python3
"""Tests for tools/mojo/bin/mojogpu — the GPU port feasibility estimator.

Two of its four modes are pure arithmetic over text and need no GPU:

  * ``--ptx``    builds a file, reads the .ptx sidecar, and derives a rough
                 arithmetic intensity from the fma/load/store counts. The
                 decision it makes — "below ~2 flops/byte, may lose to CPU" —
                 is the whole point of the tool, so the boundary is pinned here
                 from both sides.
  * ``--explain`` reads a .mojo source with regexes and reports launch geometry,
                 shared-memory budget and the hazards it knows about.

The other two (``--check``, and the nsys/ncu wrappers) are environment probes.
They are driven with a scrubbed PATH so their "no CUDA toolkit" behaviour is the
same on every machine instead of depending on whether the box has a GPU.
"""
from __future__ import annotations

import os
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

from mojo_toolkit import ToolTestCase, write  # noqa: E402

# How to say "no CUDA toolkit" to a probe: a PATH that holds every binary a tool or
# a /bin/sh wrapper might need, but none of the four things mojogpu looks for. NOT
# PATH="" and NOT PATH=/bin:/usr/bin — the first makes the tool's own
# `#!/usr/bin/env python3` unsatisfiable so nothing runs at all, and on a merged
# /usr/bin the second still finds nvidia-smi. So the box is built explicitly, from
# the same list style tests/test_mojo_install.py uses.
_STDLIB_SH = ("sh", "env", "cat", "dirname", "basename", "readlink", "cut", "find",
              "wc", "uname", "head", "tail", "ls", "tr", "sed", "grep", "sleep")
_PROBED = ("nvidia-smi", "ncu", "nsys", "mojo", "pixi")

# A PATH with nothing at all in it. Used where the probe is expected to miss and the
# probed binary is not supposed to run anyway; the tool itself is started by absolute
# path, so this only removes names, not the ability to exec.
EMPTY_DIR = "/nonexistent-no-tools-here"
NO_PATH_AT_ALL = {"PATH": EMPTY_DIR}


def ncu_resolvable() -> bool:
    """Whether mojogpu will find ncu at all.

    mojogpu falls back to /usr/local/cuda/bin/ncu when `ncu` is not on PATH, so on a
    box with the CUDA toolkit installed the "ncu not found" branch is unreachable no
    matter how hard a test scrubs PATH. Tests that need that branch have to skip.
    """
    return shutil.which("ncu") is not None or Path("/usr/local/cuda/bin/ncu").exists()


def coreutils_only_path() -> str:
    """A PATH with coreutils and nothing else: a working shell, no CUDA toolkit."""
    box = tempfile.mkdtemp(prefix="mojogpu-minbin-")
    for name in _STDLIB_SH:
        src = shutil.which(name)
        if src:
            (Path(box) / name).symlink_to(src)
    for name in _PROBED:
        assert shutil.which(name) is None or name not in _STDLIB_SH, name
    return box

# A kernel with a known fma / global-load / global-store mix. Each fma is two
# flops and each global access moves four bytes, which is the arithmetic the tool
# does; generating the text keeps the expected intensity a formula, not a number
# someone copied out of a previous run.
def ptx(fma: int = 0, ld: int = 0, st: int = 0, shared: int = 0,
        barriers: int = 0, regs: int = 8, name: str = "axpy") -> str:
    lines = [
        "//",
        ".version 7.0",
        ".target sm_80",
        ".visible .entry " + name + "(",
        ".param .u64 " + name + "_param_0",
        ")",
        "{",
    ]
    for i in range(regs):
        lines.append(f"\t.reg .b32 \t%r{i + 1};")
    for i in range(ld):
        lines.append(f"\tld.global.f32 \t%f{i + 1}, [%rd1];")
    for i in range(st):
        lines.append(f"\tst.global.f32 \t[%rd2], %f{i + 1};")
    for i in range(shared):
        lines.append(f"\tld.shared.f32 \t%f{i + 20}, [%r3];")
    for i in range(fma):
        lines.append(f"\tfma.rn.f32 \t%f{i + 40}, %f41, %f42, %f43;")
    for i in range(barriers):
        lines.append("\tbar.sync \t0;")
    lines += ["\tret;", "}", ""]
    return "\n".join(lines)


def fake_mojo(tmp: Path, ptx_text: str, rc: int = 0, emit: bool = True) -> Path:
    """A stand-in for the `mojo` binary that writes a .ptx beside the -o path.

    mojogpu only ever asks the compiler for the asm/ptx sidecars, so this keeps
    the whole --ptx path — argument parsing, failure handling, the kernel regexes
    and the intensity arithmetic — under test without a toolchain or a GPU.
    """
    body = [
        "#!/bin/sh",
        'out=""',
        'prev=""',
        'for a in "$@"; do',
        '  if [ "$prev" = "-o" ]; then out="$a"; fi',
        '  prev="$a"',
        "done",
        f'[ -n "$out" ] || {{ echo "fake mojo: no -o argument" >&2; exit 3; }}',
    ]
    if emit:
        body += [
            f'printf %s "$(cat "$FAKE_PTX_SRC")" > "${{out%.s}}.ptx"',
            f'printf "" > "$out"',
        ]
    if rc:
        body.append(f"echo 'fake mojo: compile error' >&2")
        body.append(f"exit {rc}")
    body.append("exit 0")
    p = write(tmp / "fake-mojo", "\n".join(body) + "\n")
    os.chmod(p, 0o755)
    (tmp / "k.ptx").write_text(ptx_text)
    return p


def with_fake_mojo(self, ptx_text: str, src: str = "def axpy():\n    pass\n",
                   rc: int = 0, emit: bool = True):
    src_path = write(self.tmp / "k.mojo", src)
    mojo = fake_mojo(self.tmp, ptx_text, rc=rc, emit=emit)
    return self.run_tool("--ptx", str(src_path),
                         env={"MOJO": str(mojo), "FAKE_PTX_SRC": str(self.tmp / "k.ptx")})


class MojogpuPtxTest(ToolTestCase):
    tool = "mojogpu"
    usage_token = "mojogpu"

    # ---- the intensity estimate ---------------------------------------------

    def test_intensity_is_two_flops_per_fma_over_four_bytes_per_access(self) -> None:
        """ai = fma*2 / (global ld+st)*4 — pinned to the tool's own formula."""
        for fma, ld, st, expected in [
            (10, 5, 5, 20 / 40),      # 0.50
            (20, 5, 5, 40 / 40),      # 1.00
            (40, 5, 5, 80 / 40),      # 2.00
            (80, 5, 5, 160 / 40),     # 4.00
            (10, 8, 2, 20 / 40),      # same denominator, different split
        ]:
            with self.subTest(fma=fma, ld=ld, st=st):
                r = with_fake_mojo(self, ptx(fma=fma, ld=ld, st=st))
                self.assertNotIn("Traceback", r.text)
                self.assertEqual(r.rc, 0, r.text)
                m = re.search(r"arithmetic intensity: \*\*([\d.]+) flops/byte\*\*", r.out)
                self.assertIsNotNone(m, r.out)
                self.assertAlmostEqual(float(m.group(1)), expected, places=2)

    def test_decision_boundary_crosses_at_two_flops_per_byte(self) -> None:
        """The skill's claim: under ~2 flops/byte the GPU loses to the CPU.

        Driven from both sides at the same memory traffic, so a threshold that
        drifts — or that is applied to the wrong quantity — fails here.
        """
        below = with_fake_mojo(self, ptx(fma=39, ld=5, st=5))   # 1.95
        above = with_fake_mojo(self, ptx(fma=41, ld=5, st=5))   # 2.05
        self.assertEqual(below.rc, 0, below.text)
        self.assertEqual(above.rc, 0, above.text)
        self.assertIn("1.95 flops/byte", below.out)
        self.assertIn("below ~2", below.out)
        self.assertIn("may lose to CPU", below.out)
        self.assertIn("2.05 flops/byte", above.out)
        self.assertIn("high enough for the GPU to be worth it", above.out)
        self.assertNotIn("below ~2", above.out)

    def test_exactly_two_is_not_called_a_loss(self) -> None:
        """The comparison is `ai < 2`, so the boundary value itself is a win."""
        r = with_fake_mojo(self, ptx(fma=40, ld=5, st=5))
        self.assertIn("2.00 flops/byte", r.out)
        self.assertNotIn("below ~2", r.out)

    def test_compute_only_kernel_does_not_divide_by_zero(self) -> None:
        """fma with no global traffic: the denominator is floored, not 0/0."""
        r = with_fake_mojo(self, ptx(fma=8, ld=0, st=0))
        self.assertNotIn("Traceback", r.text)
        self.assertEqual(r.rc, 0, r.text)
        m = re.search(r"arithmetic intensity: \*\*([\d.]+) flops/byte\*\*", r.out)
        self.assertIsNotNone(m, r.out)
        self.assertIn("high enough", r.out, "max(..., 1) must make this a high ratio")

    def test_zero_work_kernel_still_reports(self) -> None:
        r = with_fake_mojo(self, ptx(fma=0, ld=0, st=0))
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("0.00 flops/byte", r.out)
        self.assertIn("below ~2", r.out)

    # ---- the rest of the --ptx report ---------------------------------------

    def test_counts_registers_loads_stores_fmas_and_barriers(self) -> None:
        # `regs` is the number of DISTINCT `%rN` registers mentioned anywhere in the
        # body, which is exactly what the column claims. `%rd1`/`%rd2` are the 64-bit
        # address registers and do not match the `%r\d+` pattern the tool uses, so
        # they stay out of the count; the values in the generated PTX are:
        #   %r1..%r5 declared (5) + %r3 in the shared load + %r40..%r45 in the 6 fmas
        # = 7. The generator keeps every operand in a disjoint numeric range so no
        # two distinct roles collide on one register name, which is what makes this
        # a computable expectation instead of a copied one.
        r = with_fake_mojo(self, ptx(fma=6, ld=3, st=2, shared=1, barriers=2, regs=5))
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("## `axpy`", r.out)
        self.assertIn("| virtual regs | global ld | global st | shared ops | fma | barriers |", r.out)
        row = [ln for ln in r.out.splitlines()
               if ln.startswith("| ") and "---" not in ln and "virtual regs" not in ln]
        self.assertTrue(row, r.out)
        cells = [c.strip() for c in row[-1].strip("|").split("|")]
        self.assertEqual(cells, ["7", "3", "2", "1", "6", "2"], r.out)

    def test_many_global_loads_and_no_shared_memory_is_flagged(self) -> None:
        r = with_fake_mojo(self, ptx(fma=2, ld=9, st=0, shared=0))
        self.assertIn("No shared-memory use with many global loads", r.out)
        self.assertIn("tile it into shared memory", r.out)

    def test_shared_memory_use_is_not_flagged(self) -> None:
        r = with_fake_mojo(self, ptx(fma=2, ld=9, st=0, shared=4))
        self.assertNotIn("No shared-memory use", r.out)

    def test_kernel_names_are_listed(self) -> None:
        text = (ptx(fma=2, ld=1, st=1, name="axpy")
                + "\n" + ptx(fma=1, ld=1, st=1, name="dot"))
        r = with_fake_mojo(self, text)
        self.assertIn("kernels: axpy, dot", r.out)
        self.assertIn("## `axpy`", r.out)
        self.assertIn("## `dot`", r.out)

    def test_ptx_without_kernels_says_so(self) -> None:
        r = with_fake_mojo(self, "//\n.version 7.0\n.target sm_80\n")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("kernels: none", r.out)

    # ---- --ptx failure paths ------------------------------------------------

    def test_missing_file_is_a_usage_error(self) -> None:
        r = self.run_tool("--ptx", str(self.tmp / "nope.mojo"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such file", r.err)
        self.assertNotIn("Traceback", r.text)

    def test_failed_build_reports_the_compiler_error(self) -> None:
        r = with_fake_mojo(self, ptx(fma=1), rc=1)
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("build --emit asm failed", r.err)
        self.assertIn("compile error", r.err, "the compiler's own message is dropped")
        self.assertNotIn("Traceback", r.text)

    def test_build_without_a_ptx_sidecar_is_explained(self) -> None:
        r = with_fake_mojo(self, ptx(fma=1), emit=False)
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no .ptx sidecar emitted", r.err)
        self.assertNotIn("Traceback", r.text)

    def test_no_mojo_at_all_is_reported(self) -> None:
        src = write(self.tmp / "k.mojo", "def f():\n    pass\n")
        r = self.run_tool("--ptx", str(src), env={"PATH": EMPTY_DIR})
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("mojo not found", r.err)
        self.assertNotIn("Traceback", r.text)


class MojogpuExplainTest(ToolTestCase):
    tool = "mojogpu"
    usage_token = "mojogpu"

    KERNEL = """
comptime B = 256

def saxpy(a: UnsafePointer[Float32], b: UnsafePointer[Float32], n: Int):
    var tx = thread_idx.x
    var gx = global_idx.x
    stack_allocation[B, Float32, address_space = AddressSpace.SHARED]()
    if gx >= n:
        return
    b[gx] = a[gx] * 2.0
"""

    def explain(self, body: str, args=()):
        p = write(self.tmp / "k.mojo", body.lstrip("\n"))
        return self.run_tool("--explain", str(p), *args)

    def test_finds_kernels_and_reports_a_table(self) -> None:
        r = self.explain(self.KERNEL)
        self.assertNotIn("Traceback", r.text)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("# mojogpu --explain", r.out)
        self.assertIn("1 kernel(s)", r.out)
        self.assertIn("| kernel | launch (grid x block) | shared | flags |", r.out)
        self.assertIn("| `saxpy` |", r.out)
        self.assertIn("what to check next", r.out)

    def test_shared_allocation_is_sized_from_the_comptime_value(self) -> None:
        """B=256 Float32 = 1024 bytes = 1 KiB, and 48 KiB / 1 KiB allows 48 blocks.

        The tool spells a resolved `stack_allocation[B, Float32, ...]` as
        `BxFloat32` — the count exactly as written in the source, then the dtype —
        and appends the blocks-per-SM figure only when shared memory alone allows
        fewer than 8 blocks per SM. 48 does qualify, and 49152 // 1024 is 48.
        """
        r = self.explain(self.KERNEL)
        self.assertIn("1 KiB (BxFloat32)", r.out)

    def test_comptime_values_are_read_from_the_file(self) -> None:
        """`comptime B = 256` decides the shared-memory budget.

        The guarantee worth pinning is the number it produces, not the spelling of
        the allocation: mojogpu prints the count as written (`256xFloat32` for a
        literal, `BxFloat32` for the alias) and never echoes a comptime value it
        did not use. B=256 x 4 bytes is 1024 bytes, so seeing 1 KiB in the report is
        proof the 256 came out of the file; the sibling test pins the occupancy
        arithmetic that follows from it.
        """
        r = self.explain(self.KERNEL)
        self.assertIn("1 KiB", r.out, f"comptime B = 256 was not used:\n{r.out}")
        self.assertNotIn("unresolved", r.out)

    def test_launch_geometry_is_parsed_from_the_enqueue_call(self) -> None:
        src = self.KERNEL + """
def run():
    enqueue_function[saxpy](a.unsafe_ptr(), grid_dim=(n + B - 1) // B, block_dim=B)
"""
        r = self.explain(src)
        self.assertIn("(n + B - 1) // B x B", r.out,
                      "a parenthesised argument must not be cut at its own comma")

    def test_unlaunched_kernel_says_so(self) -> None:
        r = self.explain(self.KERNEL)
        self.assertIn("not launched here", r.out)

    def test_strided_global_read_is_flagged(self) -> None:
        src = """
def gather(x: UnsafePointer[Float32], n: Int):
    var tx = thread_idx.x
    var total = x[tx * n_cols + tx]
"""
        r = self.explain(src)
        self.assertIn("strided global read", r.out)
        self.assertIn("transpose for coalescing", r.out)

    def test_missing_early_return_is_flagged(self) -> None:
        src = """
def nobound(x: UnsafePointer[Float32], n: Int):
    var gx = global_idx.x
    x[gx] = 1.0
"""
        r = self.explain(src)
        self.assertIn("no early bounds return", r.out)
        self.assertIn("grid is rounded up", r.out)

    def test_global_atomics_are_counted_and_judged(self) -> None:
        src = """
def hist(x: UnsafePointer[Int32], n: Int):
    var gx = global_idx.x
    Atomic.fetch_add(x, 1)
    Atomic.fetch_add(x, 1)
"""
        r = self.explain(src)
        self.assertIn("2 atomic add(s)", r.out)
        self.assertIn("all global", r.out)

        good = """
def hist(x: UnsafePointer[Int32], s: UnsafePointer[Int32], n: Int):
    var gx = global_idx.x
    Atomic.fetch_add(s + gx, 1)
    Atomic.fetch_add(x, s[gx])
"""
        r2 = self.explain(good)
        self.assertIn("shared-first: good", r2.out)

    def test_shared_memory_without_a_barrier_is_flagged(self) -> None:
        src = """
def tile(x: UnsafePointer[Float32], n: Int):
    var tx = thread_idx.x
    stack_allocation[256, Float32, address_space = AddressSpace.SHARED]()
    if tx >= n:
        return
    x[tx] = 1.0
"""
        r = self.explain(src)
        self.assertIn("shared but no barrier", r.out)

    def test_oversized_shared_allocation_is_flagged_first(self) -> None:
        src = """
def huge(x: UnsafePointer[Float32], n: Int):
    var tx = thread_idx.x
    stack_allocation[65536, Float32, address_space = AddressSpace.SHARED]()
    barrier()
    if tx >= n:
        return
    x[tx] = 1.0
"""
        r = self.explain(src)
        self.assertIn("exceeds the 48 KiB default", r.out)
        self.assertIn("the launch fails unless the limit is raised", r.out)

    def test_barrier_inside_a_thread_dependent_branch_is_flagged(self) -> None:
        src = """
def skew(x: UnsafePointer[Float32], n: Int):
    var tx = thread_idx.x
    stack_allocation[256, Float32, address_space = AddressSpace.SHARED]()
    if tx < 32:
        barrier()
    x[tx] = 1.0
"""
        r = self.explain(src)
        self.assertIn("barrier inside a thread-dependent branch", r.out)

    def test_file_without_kernels_says_so_without_fake_findings(self) -> None:
        """A file with no GPU code gets a clean, empty report — not advice.

        The advice section ("coalescing", "shared memory caps occupancy", ...) is
        what makes `--explain` worth reading once there is a kernel table. With no
        kernels it is generic advice about a program the tool did not analyse, and
        printing it invites the reader to think something was checked. So this pins
        the report as it is: a correct, complete, empty result.
        """
        r = self.explain("def add(a: Int, b: Int) -> Int:\n    return a + b\n")
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("no device kernels found", r.out)
        self.assertNotIn("what to check next", r.out,
                         "advice about kernels the tool did not find is noise")
        self.assertNotIn("| kernel | launch", r.out)

    def test_missing_file_is_a_usage_error(self) -> None:
        r = self.run_tool("--explain", str(self.tmp / "nope.mojo"))
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("no such file", r.err)
        self.assertNotIn("Traceback", r.text)


class MojogpuEnvironmentTest(ToolTestCase):
    """The environment probes, driven against a PATH with no CUDA tooling on it.

    The minimal PATH is built per test and torn down with the temp dir, so one
    failing test cannot leave a PATH directory behind for the next one.
    """

    tool = "mojogpu"
    usage_token = "mojogpu"

    def setUp(self) -> None:
        super().setUp()
        self.minbin = Path(coreutils_only_path())

    def no_cuda(self) -> dict:
        """Env whose PATH holds coreutils only: no nvidia-smi, ncu, nsys, mojo, pixi."""
        self.assertNotIn("nvidia-smi", [p.name for p in self.minbin.iterdir()])
        for name in _PROBED:
            self.assertNotIn(name, [p.name for p in self.minbin.iterdir()],
                             f"{name} must not be in the scrubbed PATH")
        return {"PATH": str(self.minbin)}

    def test_check_runs_and_reports_the_toolchain(self) -> None:
        r = self.run_tool("--check", env=self.no_cuda())
        self.assertNotIn("Traceback", r.text)
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("# mojogpu --check", r.out)
        self.assertIn("nvidia-smi", r.out)
        self.assertIn("ncu", r.out)
        self.assertIn("nsys", r.out)

    def test_check_reports_every_tool_it_probes(self) -> None:
        """A report that stops at the first missing binary hides the other two.

        `--check` answers "can I profile here?", and the useful answer lists what is
        present and what is not. `nvidia-smi` being absent is reported on its own
        line; `ncu` and `nsys` must still be accounted for, because the fix for
        "no driver" is not the fix for "no CUDA toolkit" and a reader who sees one
        missing line cannot tell which of the two problems they have.
        """
        r = self.run_tool("--check", env=self.no_cuda())
        self.assertEqual(r.rc, 0, r.text)
        self.assertIn("- nvidia-smi: **missing**", r.out,
                      "PATH has no nvidia-smi, so it must be reported missing")
        self.assertIn("libmax.so", r.out, "the mojo-side dependency is probed too")
        # Whether ncu/nsys resolve depends on the host: mojogpu falls back to
        # /usr/local/cuda/bin, which survives any PATH a test can set. What is
        # asserted is the invariant — every probe is reported, on its own line, with
        # its true state — and not which of the two states a CUDA box lands in.
        for name, resolvable in (("ncu", ncu_resolvable()),
                                 ("nsys", shutil.which("nsys") is not None
                                  or Path("/usr/local/cuda/bin/nsys").exists())):
            line = next((ln for ln in r.out.splitlines() if ln.startswith(f"- {name}:")),
                        f"no line for {name}")
            self.assertRegex(line, rf"^- {name}: (ok \S+|\*\*missing\*\*)$")
            self.assertEqual(line.endswith("**missing**"), not resolvable, line)

    def test_missing_binary_is_a_usage_error_not_a_traceback(self) -> None:
        """A command that does not exist is a usage error, whatever else is missing.

        The CUDA tooling check comes first, so on a box with the toolkit installed
        the report gets one line further and complains about the command instead.
        Both are correct; neither may be a traceback, and neither may exit 0.
        """
        r = self.run_tool("some-binary", env=self.no_cuda())
        self.assertEqual(r.rc, 2, r.text)
        self.assertNotIn("Traceback", r.text)
        self.assertIn("no such command: some-binary", r.err)
        if not ncu_resolvable():
            self.assertIn("nsys not found", r.err,
                          "with no CUDA toolkit, the tooling check comes first")

    @unittest.skipIf(ncu_resolvable(), "ncu resolves on this host (ncu or "
                                        "/usr/local/cuda/bin/ncu), so mojogpu's "
                                        "fallback finds it however PATH is scrubbed")
    def test_kernels_without_ncu_says_so(self) -> None:
        # A scrubbed PATH has to stay scrubbed — that is what makes "no CUDA
        # toolkit" mean the same thing on every machine — but it may not be empty:
        # mojogpu falls back to /usr/local/cuda/bin/ncu when `which` finds nothing,
        # and a /bin/sh wrapper with no `dirname`/`readlink`/`basename`/`cut`/`find`
        # in PATH cannot start, so the tool reported that wrapper's failure instead
        # of the missing-binary one. coreutils_only_path() keeps the binaries a
        # wrapper needs to run and drops the four things mojogpu probes.
        r = self.run_tool("--kernels", "some-binary", env=self.no_cuda())
        self.assertEqual(r.rc, 2, r.text)
        self.assertIn("ncu not found", r.err)
        self.assertNotIn("Traceback", r.text)

    def test_bare_command_and_no_mode_is_a_usage_error(self) -> None:
        r = self.run_tool(env=self.no_cuda())
        self.assertNotEqual(r.rc, 0, r.text)
        self.assertIn("usage", r.text.lower())
        self.assertNotIn("Traceback", r.text)

    def test_top_is_accepted_by_the_static_modes(self) -> None:
        # `--explain` takes exactly one value, so `--top` has to be parsed before
        # it: `--explain --top 3 file` would make argparse read `--top` as the file.
        r = self.run_tool("--top", "3", "--explain",
                          str(write(self.tmp / "k.mojo", "def f() -> Int:\n    return 1\n")))
        self.assertEqual(r.rc, 0, r.text)


if __name__ == "__main__":
    unittest.main()