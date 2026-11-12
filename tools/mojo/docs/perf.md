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

* `mojo build` costs ~1-2s once the compiler is warm, and that cost is essentially
  **fixed**: 2-line file 1.1-1.2s, 1600-line file 1.3-1.4s. The *first* build of a
  session is ~5s (compiler warm-up) — time a warm build. Optimisation level barely
  moves it. Batch many functions into ONE compilation unit rather than compiling
  files separately.
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
* `Span(unsafe_ptr=p, length=n)` for a non-owning view (`Span` takes no `[T]`
  parameter, and `ptr=` is not a keyword). Pass `Span`, not `List`, to
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

## Sweeps: one function called per configuration (pm-simfast, 2026-11-12)

Measured on a market simulator that went from 42.9 ms to about 1 ms of CPU per configuration with byte-identical outputs
(predictionmojo `tests/simfast`). None of it was arithmetic; in order of size:

* **Scattered gathers.** `A[t * S + j]` with `j` from an index list, over 5-9 arrays of 40-160 MB, is a cache miss per read:
  0.7 M misses per call. When the index lists and arrays are fixed across calls, gather the columns once into one contiguous
  table in walk order and stream it (23 ms -> 1 ms). Next step if a memo fixes the visited rows: copy those rows into the memo
  itself (7 values per name, one stream per night) so that not even the table is walked.
* **Recomputed constants.** Key every expensive intermediate on the knobs it actually reads (here 9 of 35, one of them swept) and build it once per
  key; validate a memo against its real inputs (the held names), never against a guess about them.
* **Copy getters.** `def lab(self, name) -> List[T]: return self.cache[name].copy()` copied 20 MB per call. Offer take / put.
* **Fresh lists from helpers.** 53 k allocations per call came from helpers that `return w^` per row or per night; mojomem's
  size histogram shows it, MA301 does not (the constructor is in the callee). Kernels take pointers into a per-thread scratch.
* **List indexing is bounds-checked in `-O3` builds**: `std.collections.check_bounds` was 15% of mojoflame samples. Take
  `unsafe_ptr()` once outside the loop.
* **Do not trade a sort for an O(n^2) count.** Counting smaller / equal values to avoid `sort` on 40 elements was 2x slower than
  the sort; insertion sort into scratch plus a walk over runs of equal values gave the same ranks without allocating.
* **Exact shortcuts beat fast-math.** `Int(per / pc + 0.5) < 1` needs the division only when `pc > per`; with
  `--fp-mode contract=off` every such rewrite can be checked with `cmp` on the output files.
* **Division-bound loops do not vectorise on Haswell / Broadwell**: `vdivpd ymm` has the per-element throughput of `divsd`.
  Check the divider before writing SIMD lanes for a loop that is 3 divisions and a square root per element.
* **FMA chains.** `acc = x.fma(w, acc)` is a 4-5 cycle dependency; with two FMA ports a block needs 8+ independent accumulators
  to fill them. Four accumulators measured 15% of a trainer's time where an 8-wide block is bit-identical.

Threads: build the shared tables in a serial pass (first cell of every key), then `parallelize` over blocks of cells that only
read them, with one scratch object per task. 1 thread == 12 threads byte for byte, and no lock is needed.

Tool notes: `mojoflame --threads all` on a binary with 72 runtime threads took 9 samples in 7 s (every sample dumps every
thread); set the worker count to 1 and use the default `--threads main` (`parallelize(..., 1)` runs on the main thread). In
wait loops, `pgrep -f pattern` matches the waiting shell itself whenever the pattern text appears anywhere in its own command
line, including a later command of the same line: wait on an output file or a pid instead.

## Numbers to keep in your head (this box)

| op | cost |
|---|---|
| L1 hit | ~1ns |
| L3 hit | ~15ns |
| DRAM | ~80ns |
| `mojo run` JIT | ~1.2s |
| `mojo build` (warm) | ~1-2s, ~flat in file size |
| ctypes call into built .so | ~0.9us |
| scalar f32 accumulate, 1M elems | ~2.2ms |
| same loop with `fma` over `simd_width_of` chunks | ~0.44ms (**4.95x**, measured) |
| host<->GPU roundtrip | ~10-50us + bandwidth |

## Anti-patterns `mojolint` flags

`String` `+=` in a loop; `List.append` without `reserve`; `alloc` inside a loop;
`print` in a hot loop; scalar loop over a contiguous buffer with no `load[width=]`;
`.reduce_*()` inside the accumulation loop; `synchronize()` per kernel launch;
`len()` recomputed in the loop condition; missing `^` on a large owned value.
