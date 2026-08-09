# mojo tools

Performance tooling + reference docs for Mojo 1.0 nightly. Every tool prints markdown
sized for an LLM context: ranked tables, verdicts, no SVG, no scrollback dumps.

Verified against `mojo 1.0.0b3.dev2026072406` on this box (36c/72t, AVX2 no AVX-512,
RTX 5090).

## Tools

| tool | answers | backend |
|---|---|---|
| `mojoflame` | where does the time go? | gdb sampling (perf if permitted) -> flame tree |
| `mojomem` | what allocates, how often, does it leak? | LD_PRELOAD over `KGEN_CompilerRT_AlignedAlloc` |
| `mojoasm` | did the loop actually vectorize? | `--emit asm` / objdump, per-loop verdict |
| `mojolint` | known perf + dialect anti-patterns | static scan |
| `mojobench` | did the change actually help? | A/B with a noise gate |
| `mojogpu` | kernel vs copies, occupancy, PTX intensity | nsys / ncu / PTX |
| `mojoffi` | are my `@export`s callable, and did they link? | source audit + `nm -D` + codegen |
| `mojoparity` | does the kernel agree with its reference, and where not? | ULP / NaN / row-concentration diff |

```bash
mojoflame ./mybin                       # hot leaves + flame tree
mojomem ./mybin --stacks                # allocation churn with inline chains
mojoasm kernel.mojo dot --listing       # annotated asm of the hot loop
mojolint src/                           # exits 1 on errors — usable in CI
mojobench --label old=a.mojo --label new=b.mojo --reps 20
mojogpu --check                         # is the GPU usable right now?
mojoffi kernels/capi.mojo --check dist/lib.so   # export audit + link proof
mojoffi --emit bridge kernels/capi.mojo > python/pkg/_lib.py
mojoparity native.npz reference.npz      # exits 1 on divergence — usable in CI
```

## Install

```bash
./install.sh          # symlinks bin/* into ~/.local/bin and skills into ~/.claude/skills
```
Or just call them by path. Requires `python3`, `gcc` (mojomem shim), `gdb` (mojoflame),
`objdump`/`addr2line` (binutils). `valgrind` only for `mojomem --tool dhat|massif`.

Every tool needs a working `mojo` on PATH. Using one out of a pixi env *without* `pixi run`
also needs `MODULAR_HOME`, or the compiler fails with `'builtin' does not refer to a nested
package`:

```bash
export PATH=/path/to/proj/.pixi/envs/default/bin:$PATH
export MODULAR_HOME=/path/to/proj/.pixi/envs/default/share/max
```

Exit codes: `0` clean, `1` findings/divergence (mojolint, mojoparity, mojoffi --check),
`2` usage error — so CI can tell "the tool broke" from "the code is wrong".

## Docs

| file | contents |
|---|---|
| `docs/perf.md` | measurement order, allocation, ownership, loops, parallelism, cost table |
| `docs/simd.md` | the reliable SIMD loop shape, verified API surface, widths |
| `docs/gpu.md` | when GPU is worth it, launch config, coalescing, occupancy, async |
| `docs/dialect.md` | Mojo 1.0 renames and compile-blocking facts |
| `docs/ffi.md` | the whole C-ABI contract, what to port, proving the native path runs |

## Skills

`skills/mojo-perf` (profile and optimize), `skills/mojo-dialect` (write code that
compiles first try), and `skills/mojo-ffi` (call Mojo from Python, and pick the
loop that is actually worth porting). All are self-contained SKILL.md files.

## Two things that surprise everyone

**valgrind is blind to Mojo allocations.** `List`, `String` and `alloc[T]` route through
`KGEN_CompilerRT_AlignedAlloc` in libKGENCompilerRTShared.so, not libc malloc. A dhat
report is byte-identical whether the loop runs 200 or 1000 times — verified. `mojomem`
intercepts that symbol pair instead, and recovers user source lines from the inline
chain via `addr2line -i` (Mojo inlines user code into stdlib frames, so the raw symbol
is always something like `List::unsafe_ptr`).

**A bridge that falls back silently is the most expensive bug here.** The Python
reference runs, the numbers are right, and the "speedup" is 1.0x hidden in noise.
`mojoffi --check` proves the symbols linked; a test that asserts a 64-config native
grid beats ONE reference path proves they are being called.

**Mojo inlines everything into `main`.** Per-function profiles and asm dumps collapse.
`mojoasm` therefore analyses *loops* — spans between a label and a backward branch —
which is the granularity that answers "did this vectorize".

## Worked example

`slow_part` (scalar accumulate) vs `fast_part` (`fma` over `simd_width_of` chunks),
1M f32, 300 reps:

```
| target | median | speedup |
| scalar | 651.3ms | 1.00x   |
| simd   | 131.6ms | 4.95x   |
```

`mojoasm --listing` shows exactly why — `vfmadd231ss %xmm` (1 element/iter) versus
`vfmadd231ps %ymm3` (8 elements/iter).
