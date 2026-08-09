# Mojo performance

## Order of operations

1. **Measure.** `mojobench` or `perf_counter_ns` around the suspect region. No profile, no rewrite.
2. **Find the hot frame.** `mojoflame ./binary` — markdown flame tree, self% ranked.
3. **Find the allocations.** `mojomem ./binary` — call counts, size histogram, and the
   user source line via the inline chain.
   Note: valgrind/dhat is **blind** to Mojo allocations (List/String/`alloc[T]` go
   through `KGEN_CompilerRT_AlignedAlloc`, not libc malloc — a dhat report is
   byte-identical whether the loop runs 200 or 1000 times). `mojomem` intercepts that
   symbol; `--tool dhat` is only for the C/FFI side.
4. **Check codegen.** `mojoasm file.mojo sym` — did it vectorize / inline / spill?
5. Only then: algorithm, layout, SIMD, GPU.

## Build

* `mojo build` costs ~2-5s and that cost is essentially **fixed**: 1 fn 5.17s, 5 fns 4.98s,
  20 fns 4.96s. Optimisation level barely moves it. Batch many functions into ONE
  compilation unit rather than compiling files separately.
* `mojo run` JITs in ~1.2s per invocation. A built shared lib called via ctypes is ~0.9us
  per call. Anything measured with `mojo run` includes JIT — build first, then benchmark.
* `mojo build --emit shared-lib` errors if the file defines `main`, and errors if the `-o`
  directory does not already exist.
* Always profile a `mojo build` binary (with `-g` for symbols), never a `mojo run` JIT.

## Allocation

* `alloc[T](n)` / `p.free()` from `std.memory`. `UnsafePointer[T].alloc` no longer exists.
  It returns `Pointer[T, MutUntrackedOrigin]` — a helper declared
  `UnsafePointer[T, AnyOrigin[mut=True]]` will reject it.
* `unsafe_memset_zero(p, n)` (`memset_zero` is deprecated).
* `List[T](capacity=n)` or `l.reserve(n)` **before** the loop. `l.capacity()` is a method.
  An append loop without reserve is O(n) reallocs+copies; mojomem shows it as a
  doubling size histogram (4B, 8B, 16B ... one bucket per growth step).
* `InlineArray[T, N]` and `stack_allocation[N, T]()` for small fixed buffers — zero heap.
* `Span[T](unsafe_ptr=p, length=n)` for a non-owning view. Pass `Span`, not `List`, to
  helpers: passing an owned collection by value copies it.
* Allocate outside the hot loop, reuse the buffer across iterations. The single biggest
  real-world Mojo perf bug is a per-iteration `List` or `String` build.

## Ownership costs

* `var x = y` on a non-trivial type copies. Use `y^` (transfer) when you are done with `y`.
* Take arguments as `ref` / borrowed (default) when you only read; `mut` when you write in
  place; `var`/owned only when you genuinely take ownership.
* Returning a large struct by value is usually elided, but returning it out of a loop
  iteration is not — write into a caller-provided buffer.
* String concatenation in a loop is quadratic. Build into a `List[UInt8]` and construct once.

## Loops

* Hoist everything loop-invariant, including `len()` and any `.capacity()` call.
* Bounds checks: indexing `List` checks; `UnsafePointer` does not. In a proven-safe hot
  loop, take the pointer once outside and index that.
* `range(0, n, W)` with an explicit scalar tail beats a masked/predicated inner branch.
* Multi-dim: iterate so the **innermost** index is the contiguous one. A transposed inner
  loop costs a cache miss per element and no amount of SIMD fixes it.

## Parallelism

```mojo
from std.algorithm.functional import parallelize
@parameter
def work(i: Int):
    ...
parallelize[work](num_items, num_workers)
```
Closure goes in the **parameter** list (`parallelize[work](n, w)`), not the argument list.
36 physical / 72 logical cores here; `num_physical_cores()` is the right default worker
count for compute-bound work — hyperthreads help only latency-bound loops.
Chunk so each work item is >= ~50us, or scheduling overhead dominates.

## Numbers to keep in your head (this box)

| op | cost |
|---|---|
| L1 hit | ~1ns |
| L3 hit | ~15ns |
| DRAM | ~80ns |
| `mojo run` JIT | ~1.2s |
| `mojo build` | ~5s fixed |
| ctypes call into built .so | ~0.9us |
| scalar f32 accumulate, 1M elems | ~2.2ms |
| same loop with `fma` over `simd_width_of` chunks | ~0.44ms (**4.95x**, measured) |
| host<->GPU roundtrip | ~10-50us + bandwidth |

## Anti-patterns `mojolint` flags

`String` `+=` in a loop; `List.append` without `reserve`; `alloc` inside a loop;
`print` in a hot loop; scalar loop over a contiguous buffer with no `load[width=]`;
`.reduce_*()` inside the accumulation loop; `synchronize()` per kernel launch;
`len()` recomputed in the loop condition; missing `^` on a large owned value.
