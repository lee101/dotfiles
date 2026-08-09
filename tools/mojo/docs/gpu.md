# Mojo GPU

Needs the `max` conda package (libmax.so) alongside `mojo` in the pixi env.

```toml
[dependencies]
mojo = "==1.0.0b3.dev2026072406"
max  = "*"
```

## Minimal kernel

```mojo
from std.gpu.host import DeviceContext
from std.gpu import thread_idx, block_idx, block_dim, global_idx, barrier

def scale(p: UnsafePointer[Float32, AnyOrigin[mut=True]], n: Int, k: Float32):
    var i = global_idx.x
    if i < UInt(n):                 # ALWAYS bounds-check: grid is rounded up
        p[i] = p[i] * k

def main():
    try:
        var ctx = DeviceContext()
        var buf = ctx.enqueue_create_buffer[DType.float32](n)
        ctx.enqueue_copy(buf, host_ptr)
        var bs = 256
        ctx.enqueue_function[scale](buf, n, 2.0, grid_dim=(n + bs - 1) // bs, block_dim=bs)
        ctx.enqueue_copy(host_ptr, buf)
        ctx.synchronize()
    except e:
        print("gpu unavailable:", e)
```

`DeviceContext()` **raises** — including `CUDA_ERROR_OUT_OF_MEMORY` when another process
owns the card. An `@export ... abi("C")` function cannot be `raises`, so FFI wrappers must
`try:`/`except:` internally and return an error code.

## Decide before you port

GPU only wins at high arithmetic intensity. Below ~2 flops/byte it loses to CPU at **every**
array size — the PCIe round-trip alone costs more than the compute. Measure the ratio first:

```
flops/byte = (fma_count * 2) / (bytes_read + bytes_written)
```
* elementwise add/scale (0.25) — never worth it
* dot / axpy (~0.5) — never worth it standalone
* GEMM, conv, attention (10-100+) — worth it

Fusing many elementwise ops into one kernel raises intensity; that is the whole game for
memory-bound work.

## Occupancy and launch config

* `block_dim` a multiple of 32 (warp). 256 is the default that is right most of the time.
* Grid = `ceil(n / block_dim)`; the bounds check is mandatory, not optional.
* Registers per thread cap occupancy. Huge unrolled kernels silently drop to 25% occupancy —
  `mojogpu --occupancy` reports it from ncu.
* Prefer grid-stride loops over one-element-per-thread for large n: fewer blocks, better
  cache reuse, and the kernel works for any n.

## Memory hierarchy — the only four things that matter

1. **Coalescing.** Adjacent threads must touch adjacent addresses. `p[i * stride]` with
   stride > 1 costs `stride`x the transactions. Transpose the layout, not the loop.
2. **Shared memory** for data reused by >1 thread in a block. Tile it, `barrier()` after
   the fill and after the last read.
3. **Bank conflicts.** Shared arrays with a power-of-2 row pitch conflict 32 ways; pad the
   pitch by 1 element (`tile[32][33]`).
4. **Occupancy vs. ILP.** More work per thread often beats more threads. Try 2 and 4
   elements/thread before tuning block size.

## Async / overlap

`enqueue_*` calls are asynchronous on the context's stream; `synchronize()` is the barrier.
Batch enqueues then synchronize once — a `synchronize()` per kernel serialises host and
device and is the single most common Mojo GPU perf bug. Overlap H2D copies with compute by
splitting the input into chunks.

## Profiling

```
mojogpu ./mykernel                 # nsys timeline summary -> md
mojogpu --kernels ./mykernel       # ncu per-kernel: occupancy, mem throughput, stalls
```
Read in this order: (1) is the kernel even the hot part, or is it copies/launch overhead?
(2) achieved memory bandwidth vs. peak — if > 80%, you are memory-bound and only layout
changes help; (3) warp stall reasons; (4) occupancy last, it is a symptom not a cause.

UNVERIFIED on this box: GPU was at 31.8/32.6 GB used by other prod processes, so the API
names above come from earlier verified runs (see reference_mojo1_ffi notes), not a live
probe in this session. Re-probe with `mojogpu --check` when the card frees up.
