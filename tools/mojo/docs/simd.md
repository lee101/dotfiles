# Mojo SIMD

Toolchain: `mojo 1.0.0b3.dev2026072406`. Facts below are probe-verified unless marked UNVERIFIED.

## Width

```mojo
from std.sys.info import simd_width_of, size_of, align_of, num_physical_cores, CompilationTarget
comptime W = simd_width_of[DType.float32]()   # native width for the target
```
Measured on this box (Zen, AVX2, no AVX-512): f32=8, f64=4, u8=32, phys/log cores 36/72,
`CompilationTarget.has_avx512f()` False. Never hardcode 8/16 — always `simd_width_of`.

`2*W` unroll is usually the win on AVX2 (hides FMA latency, ~4-5 cycles, with 2 FMA ports).
Above `4*W` you spill.

## The reliable loop shape

`std.algorithm.functional.vectorize` exists but in this nightly the closure conversion
rejects capturing closures:
`value passed to 'closure' cannot be converted from 'def[w: Int](i: Int) capturing thin -> None'`.
The parameter form (`vectorize[W, size=N](step)`) fails with
`cannot use a dynamic value in a parameter list`. So hand-roll:

```mojo
comptime W = simd_width_of[DType.float32]()
var acc = SIMD[DType.float32, W](0)
var tail = n - (n % W)
for i in range(0, tail, W):
    acc = fma(a.load[width=W](i), b.load[width=W](i), acc)
var total = acc.reduce_add()
for i in range(tail, n):          # scalar tail, never a masked branch inside the hot loop
    total += a[i] * b[i]
```

Keep the reduce *outside* the loop. `acc.reduce_add()` per iteration serialises the whole thing.

## API surface that actually exists

| want | call |
|---|---|
| load/store | `p.load[width=W](i)` / `p.store(i, vec)` |
| fused multiply-add | `from std.math import fma` — `fma(a, b, acc)` |
| horizontal reduce | `vec.reduce_add()` `.reduce_max()` `.reduce_min()` `.reduce_and()` |
| min/max | free functions `min(a, b)` / `max(a, b)` — SIMD has **no** `.min()`/`.max()` methods |
| lane select | `mask.select(a, b)` |
| splat | `SIMD[DType.float32, W](x)` |
| slice/join | `v.slice[k](offset)`, `a.join(b)` |
| ramp | `from std.math import iota` |

## Rules

1. **Branchless.** A branch inside a vector loop kills it. Use `mask.select(a, b)` or
   arithmetic on the 0/1 mask.
2. **Align allocations.** `alloc[Float32](n)` is 64-byte aligned in practice, but if you
   partition a buffer, keep each partition offset a multiple of `W`, or every load is
   split across cache lines.
3. **AoS -> SoA.** `Point{x,y,z}` arrays cannot vectorize. Three parallel arrays can.
4. **One dtype per loop.** Mixed f32/f64 forces converts that halve throughput; `Int` is
   64-bit — using `Int32` indices doubles your index-vector density.
5. **Accumulate in >= source precision** for reductions over >1e5 elements — f32 pairwise
   error grows; use `Float64` accumulator or 4 partial accumulators (also breaks the
   dependency chain, which is the real speed win).
6. **`ord("=")` yields `Int`** and will not implicitly convert to `UInt8` — cast for byte work.
7. Check it actually vectorized: `mojoasm <file.mojo> <symbol>` (see ../README.md).

## Measured payoff

Sum of squares over 1M f32, 300 reps, this box (`mojobench --reps 7`):

| version | median | |
|---|---|---|
| `for i in range(n): t += p[i] * p[i]` | 651.3ms | 1.00x |
| `fma(p.load[width=W](i), ..., acc)` + tail | 131.6ms | **4.95x** |

`mojoasm --listing` shows the cause: the scalar version emits `vfmadd231ss %xmm`
(1 element/iteration) — LLVM will not reassociate an fp reduction on its own, so the
scalar loop stays scalar no matter the optimization level. The SIMD version emits
`vfmadd231ps %ymm3`, 8 elements/iteration.

## Verifying a rewrite

Never claim a speedup you did not measure:
```
mojobench --label old=old.mojo --label new=new.mojo --reps 20
mojoasm new.mojo my_kernel        # confirms vmovups/vfmadd width
```
Memory-bound kernels (< ~2 flops/byte) do not speed up from wider SIMD — they were already
at DRAM bandwidth. Check the arithmetic intensity before rewriting.
