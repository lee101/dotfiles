---
name: mojo-perf
description: Profile and optimize Mojo code — find what is slow or allocating, prove a change actually helped. Use when asked to speed up, profile, benchmark, vectorize, SIMD-ify, reduce allocations, or GPU-port Mojo code, or when a Mojo program is slower than expected.
---

# Mojo performance

Tools live in `<toolkit>/bin` (this skill's `../../bin`). Reference docs in `../../docs/`.
All emit markdown. Never claim a speedup you did not measure with `mojobench`.

## Workflow

```
1. mojoflame ./bin              where does time go?          -> hot frame
2. mojomem   ./bin              what allocates, how often?   -> churn sites
3. mojoasm   src.mojo [pat]     did the loop vectorize?      -> codegen verdict
4. mojolint  src/               known anti-patterns          -> quick wins
5. <change one thing>
6. mojobench --label a=old --label b=new    did it help?
```

Steps 1-4 are cheap and independent — run them together before changing anything.
Step 6 is not optional: roughly half of "obvious" Mojo optimizations measure as noise.

## Rules that decide most cases

- **Build first.** `mojo run` JITs for ~1.2s; timing it measures the compiler.
  Profile `mojo build -g` output. `mojo build` costs ~5s flat regardless of file size.
- **Allocation churn beats byte totals.** 2000 small allocations from one loop hurts
  more than one 100MB buffer. Read mojomem's "by call count" table first.
- **Check the loop, not the function.** Mojo inlines everything into `main`; mojoasm's
  *loops* table is the one that matters.
- **Memory-bound work does not get faster from wider SIMD.** Below ~2 flops/byte you
  are at DRAM bandwidth already — change the layout or fuse, do not vectorize harder.
- **GPU below ~2 flops/byte loses to CPU at every size.** Run `mojogpu --ptx` for the
  intensity estimate before porting anything.

## Two facts that break the obvious approach

1. **valgrind/dhat cannot see Mojo allocations.** `List`, `String` and `alloc[T]` all go
   through `KGEN_CompilerRT_AlignedAlloc`, not libc malloc — a dhat report is
   byte-identical whether your loop runs 200 or 1000 times. `mojomem` LD_PRELOADs that
   symbol instead. Use `--tool dhat` only for the C/FFI side.
2. **`perf` is unavailable here** (not installed, `perf_event_paranoid=4`), and
   `ptrace_scope=1` blocks attaching to non-children. `mojoflame` therefore drives one
   gdb session that owns the process. Let it launch the binary; `--pid` needs
   `sudo sysctl -w kernel.yama.ptrace_scope=0`.

## Reading the output

| symptom | tool + signal | fix |
|---|---|---|
| loop is scalar | mojoasm: `**SCALAR**` or `vfmadd...ss %xmm` | chunked `load[width=W]` loop + scalar tail (docs/simd.md) |
| half width | mojoasm: `only 128-bit ops` | width from `simd_width_of`, not a literal |
| spilling | mojoasm: `>15% stack refs` | unroll less; 2xW is usually the sweet spot |
| alloc churn | mojomem: doubling size histogram | `reserve()` up front, hoist out of the loop |
| leak | mojomem: `N blocks never freed` | match `alloc`/`free`, or use `List`/`InlineArray` |
| all time in one frame | mojoflame + inlining | `-O0 -g` to separate, or `mojoasm --listing` |
| GPU slower than CPU | mojogpu: memcpy% > kernel% | fuse kernels, keep data resident, or stay on CPU |

## Docs

- `docs/perf.md` — allocation, ownership, loops, parallelism, cost table
- `docs/simd.md` — the reliable loop shape, API surface, verified widths
- `docs/gpu.md` — launch config, coalescing, occupancy, async
- `docs/dialect.md` — Mojo 1.0 renames (see the mojo-dialect skill)
