# cuk: token-efficient CUDA diagnosis

Stdlib Python via `uv`, one file, compact output. Every command takes `--json`
when an agent or a history script needs the machine form.

| cmd | needs | answers |
|---|---|---|
| `cuk doctor [--json]` | smi | shared/busy/throttled? ncu permission, profile |
| `cuk plan [--gpu h200\|3090\|5090\|4090\|a100\|t4] [--workload decode\|prefill\|moe\|diffusion]` | — | what to try first, batch/KV/ctx, pitfalls |
| `cuk bw [--force --json]` | nvcc | DRAM, L2 (`cg`), copy, fp32, bf16-mma, launch/node |
| `cuk roof --bytes 50M --flops 2G [--us T] [--tc] [--l2] [--json]` | bw | floor, bound, intensity/ridge, % of floor |
| `cuk res <.cu/.o/.so/.cubin/dir> [--cc --block --dyn-smem --json]` | cuobjdump | regs, smem, spills, occupancy limiter |
| `cuk sass <.cu/.cubin> [--arch current\|all\|sm_80,sm_90,sm_120] [--filter RE]` | nvcc+cuobjdump | cross-arch regs/spills/static instruction mix |
| `cuk trace [--json] [--top N --filter RE --exclude RE --skip F] -- cmd` | nsys | per-kernel time/share, busy%, gaps, verdict |
| `cuk ncu -k RE [-n N -s S --stalls --full --metrics M] [--json] -- cmd` | ncu | sm/dram/l2/l1, occupancy, waves, CPI, stalls |
| `cuk diff a.json b.json [--threshold 5 --all --json]` | — | numeric deltas between two `--json` outputs |

## `cukbench`: cold-L2 graph timing

`cukbench.py` (needs torch) times a callable inside one CUDA graph over N
distinct weight copies. Each replay starts after a **read-only L2 flush**; the empty
graph replay is measured and subtracted (`net_*`). This is the judge-style
protocol: no launch overhead, no cache lies.

```python
from cukbench import bench, stats, show
mn, p50 = bench(lambda i: lambda: kernel(w[i]), copies=16)
s = stats(make, copies=16, reps=50, flush_mb=256)   # full record
show("attn", s)
```

CLI, with history and regression check:

```bash
./cukbench --script bench.py --tag attn --reps 50
./cukbench --script bench.py --tag attn --json
```

History: `~/.cache/cuk/bench.jsonl`. It compares `net_p50_us` to the last run
of the same tag (or `--baseline TAG`) and prints `REGRESSION >N%`.
`--no-flush` / `--no-empty` are for deliberate A/Bs only. A nonzero
`--flush-mb` is clamped to 64 MB so the empty-graph calibration runs at a hot
clock; the default is 256 MB.

## Workflow

`cuk plan` (what order) → `doctor` (trust timings?) → `bw`/`roof` (roof) →
`res`/`sass` (codegen) → `trace` (which kernel, gaps) → `ncu` (why) →
`diff` (did it improve?). Use `--json` for every step and `diff` in CI.

Examples:

```bash
cuk plan --gpu 5090 --workload moe
cuk bw --force
cuk roof --bytes 50M --flops 2G --us 120 --tc
cuk res build/kernel.cubin --block 256
cuk sass kernel.cu --arch all --filter my_kernel
cuk trace --exclude 'elementwise|Memcpy' --skip 0.5 -- python bench.py
cuk trace --json -- python bench.py > a.json
cuk diff a.json b.json --threshold 5
```

Notes:

- `bw` reports **L2 with `cg`** (bypasses L1) and DRAM with streaming loads.
  A plain cache-resident read can be faster because it hits L1 too.
- `sass` compiles `.cu` per arch; `--nvcc` passes extra include/define flags.
- `res`/`sass` occupancy is a model: cuobjdump smem + `--dyn-smem`, block size,
  arch limits. Verify with the runtime or Nsight.
- `ncu` counters need `NVreg_RestrictProfilingToAdminUsers=0` (or sudo).
  Everything else works unprivileged.
- `trace` under python/torch: `--exclude 'elementwise|Memcpy'` drops harness
  kernels; `--skip 0.5` drops warmup.
