---
name: mojo-ffi
description: Call Mojo kernels from Python (or accelerate a Python/NumPy/PyTorch hot loop with Mojo). Use when writing @export/abi("C") functions, building a shared library, wiring a ctypes bridge, deciding WHICH loop is worth porting, or debugging a kernel that disagrees with its reference. Triggers: "@export", "abi(C)", "shared-lib", "ctypes", "mojo kernel", "port this loop to Mojo", "why is my kernel slower", "numbers differ from numpy".
---

# Mojo <-> Python FFI

## Decide what to port first

Port a loop only if it is **sequential and hot**. NumPy already wins on anything
elementwise or reducible; the wins are where it structurally cannot go:

- iteration `t` depends on `t-1` (simulation state, path-dependent exits, cumulative rules)
- per-item control flow that vectorises into mostly-masked work
- many independent whole-path evaluations (a config grid, an RL reward sweep) —
  parallelise across the grid, never inside one short path

If the loop is a rolling mean, stop: `pandas.rolling` is already C.

## Write the kernel

```mojo
from std.math import isnan, nan, sqrt
comptime NAN = nan[DType.float64]()
comptime FPtr = UnsafePointer[Float64, AnyOrigin[mut=True]]

def fp(addr: Int) -> FPtr:
    return FPtr(unsafe_from_address=addr)

@export("pkg_kernel")
def pkg_kernel(x_addr: Int, out_addr: Int, n_rows: Int, n_cols: Int) abi("C") -> None:
    var x = fp(x_addr)
    var o = fp(out_addr)
    ...
```

Non-negotiable (each of these is a compile error or a silent wrong answer):

- buffers cross as `Int` addresses — a pointer parameter makes the export
  parametric and `@export` rejects it
- `abi("C")` is an effect **before** the arrow
- the body cannot raise: `Float64("nan")` raises, `nan[DType.float64]()` does not
- `out` is a reserved name
- take the whole matrix per call; per-row calls lose to the boundary cost
- pass an explicit `Int64` validity mask instead of relying on NaN conventions

Run `mojolint` for dialect/perf anti-patterns and `mojoffi src.mojo` for the
FFI-specific audit before building.

## Build and bridge

```bash
mojo build --emit shared-lib kernels/capi.mojo -o dist/libpkg.so
mojoffi --emit bridge kernels/capi.mojo > python/pkg/_lib.py
mojoffi --emit test   kernels/capi.mojo > tests/test_kernels.py
mojoffi --check dist/libpkg.so kernels/capi.mojo      # symbols really landed
```

Keep a **Python reference** for every kernel and let the bridge fall back to it
when the toolchain is absent. A fallback run must be slower, not different.

## Two tests that are always worth writing

1. **Parity** — native vs reference, tight tolerance, several seeds. Bit-identical
   is normal when both sides do the same ops in the same order; insist on it.
2. **The native path actually runs** — a silent fallback produces a 1.0x "speedup"
   that reads as noise. Assert a grid of N native evaluations beats ONE reference
   evaluation.

When parity fails: `mojoparity native.npz reference.npz`. Debug in this order —
NaN/inf disagreements (a masking bug, not precision), then a few huge ULP gaps
(different algorithm or a missing clamp), then uniform 1-2 ULP noise
(reassociation; pin the tolerance and move on).

## Measure

`mojobench` for A/B (it builds first — timing `mojo run` measures ~1.2s of JIT).
`mojoflame` for where the time goes, `mojomem` for allocation churn (valgrind is
blind to Mojo allocations), `mojoasm` to confirm the loop vectorised.

## Full contract

`docs/ffi.md` in this toolkit — every rule with the error message it produces.
