# Calling Mojo from Python — the whole contract

Verified against `mojo 1.0.0b3.dev2026072406`. Everything here was hit in a real
port, not read from docs.

## The shape that works

```mojo
from std.algorithm import parallelize
from std.math import isnan, nan, sqrt

comptime NAN = nan[DType.float64]()
comptime FPtr = UnsafePointer[Float64, AnyOrigin[mut=True]]
comptime IPtr = UnsafePointer[Int64, AnyOrigin[mut=True]]

def fp(addr: Int) -> FPtr:
    return FPtr(unsafe_from_address=addr)

@export("mb_scale")
def mb_scale(x_addr: Int, out_addr: Int, n: Int, k: Float64) abi("C") -> None:
    var x = fp(x_addr)
    var o = fp(out_addr)
    for i in range(n):
        o[i] = x[i] * k
```

```bash
mojo build --emit shared-lib kernels/capi.mojo -o dist/libmykernels.so
```

```python
lib = ctypes.CDLL("dist/libmykernels.so")
lib.mb_scale.argtypes = [ctypes.c_int64] * 3 + [ctypes.c_double]
lib.mb_scale.restype = None
lib.mb_scale(x.ctypes.data, out.ctypes.data, x.size, 2.0)   # x, out C-contiguous
```

`mojoffi` generates both the bridge and a parity-test skeleton from the source, and
`mojoffi --check dist/lib.so src.mojo` proves every `@export` actually landed in
the built library.

## The rules, and the error you get when you break them

| rule | symptom |
|---|---|
| `@export` rejects **parametric** functions | a pointer parameter makes it parametric (the origin is a parameter) — pass `Int` addresses instead |
| `abi("C")` goes **before** the arrow: `def f(a: Int) abi("C") -> None:` | after the return type is a parse error; omitting it only warns, and the symbol still exports with a Mojo ABI |
| an `abi("C")` export **cannot raise** | `cannot call function that may raise in a context that cannot raise` — wrap fallible work in `try:`/`except:` |
| `Float64("nan")` **raises** | use `nan[DType.float64]()` from `std.math`; same for any string parse |
| pointers are **non-nullable** | building one from address 0 fails a compile-time constraint; construct inside the branch that uses it |
| `out` is reserved | as a parameter name *and* as a local |
| the only mutable origin name is `AnyOrigin[mut=True]` | `MutableAnyOrigin` / `StaticMutableOrigin` do not exist; bare `AnyOrigin` is parametric over `mut` |

## Design rules that matter more than the syntax

**Batch at the call, not the element.** The cost of the boundary is per *call*.
A kernel that processes one row per call will lose to NumPy no matter how fast the
row is. Take `(n_bars, n_pairs)` and do the whole matrix.

**Give sequential loops to Mojo, keep vectorisable ones in NumPy.** The wins are
where NumPy structurally cannot go: a loop whose iteration t depends on t-1
(simulation state, cumulative rules, path-dependent exits). A rolling mean is not
that; a position rollout is.

**Parallelise the grid, not the path.** `parallelize[work](n_configs, workers)`
over independent whole-path evaluations scales; splitting one short path across
threads loses to the hand-off cost. Same lesson as the classic-control envs: thread
where the work per item is a loop, not a handful of flops.

**Pass validity explicitly.** NaN as "no data" works only if every kernel treats it
as "not a candidate" and never as a number. An `Int64` mask buffer alongside the
data makes that checkable, and it is what turns a masking bug into a test failure
instead of a plausible-looking number.

**Contiguity is not optional.** Every kernel indexes `t * n_pairs + j`. A strided
view has the wrong address for that, and reading the wrong memory produces numbers
that look fine. Check `flags.c_contiguous` in the bridge and raise.

## Prove the native path is actually running

A bridge that falls back silently gives you the reference implementation twice and
a speedup of 1.0x that reads as noise. Two tests, both cheap:

```python
def test_native_matches_reference(): ...      # same numbers, tight tolerance
def test_native_is_faster():                  # the grid must beat ONE python path
    assert native_grid_of_64 < one_python_rollout
```

`mojoparity native.npz reference.npz` reports max abs/rel error, ULP distance, and
whether failures are concentrated in a few rows (boundary bug) or spread across all
of them (algorithmic). Bit-identical is achievable and worth insisting on when both
sides do the same operations in the same order.

## Build cost

A shared-lib build of a few hundred lines is ~5-8s, and it is a fixed cost you pay
on every source change. Have the bridge rebuild on mtime, once, at import — and let
it raise the compiler's own message rather than surface a missing symbol later.

AOT Mojo embeds CPython 3.12, not 3.13; pin the pixi python accordingly if the
built artifact uses Python interop.
