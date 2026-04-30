# Profiling toolset

A small bag of CLI tools that wrap heavyweight C/CUDA profilers and emit
**token-efficient markdown** so coding agents can read them and jump straight
to `file:line` instead of paging through 20MB of perf/ncu output.

## Tools (in `bin/`)

| Tool | What it wraps | Output |
|---|---|---|
| `lint-c-md` | cppcheck (+ optional clang-tidy) | severity-grouped findings, one line each |
| `valgrind-md` | valgrind memcheck/helgrind/drd (XML mode) | unique errors with deepest user frame |
| `perf-md` | `perf record` + `perf report` | top-N hot symbols, sorted by self-overhead |
| `ncu-md` | Nsight Compute | per-kernel SM%, mem%, occupancy, regs, smem |
| `nsys-md` | Nsight Systems | top kernels, memcpys, and NVTX ranges by total time |
| `profile-md` | saved `.nsys-rep` / `.ncu-rep` / `trtexec` logs | markdown analysis of offline profiler artifacts |
| `cuda-sanitize-md` | compute-sanitizer | per-error stacks, ERROR SUMMARY line |
| `asan-build` | clang ASan + UBSan | quick triage runner for single-file C |
| `c-inspect` | `find` + `awk` | source-tree map: per-file functions, types, TODOs |

All tools accept `--out PATH` to write a `.md` file (default: stdout).

## Install

```bash
# add bin/ to PATH
echo 'export PATH="$HOME/code/dotfiles/profiling/bin:$PATH"' >> ~/.bashrc

# linters (Ubuntu)
sudo apt-get install -y cppcheck clang-tidy clang-format clang valgrind linux-tools-generic

# CUDA tools come with the CUDA toolkit (already installed under /usr/local/cuda-12)
```

## Templates (in `templates/`)

- `.clang-format` — drop into a project root for `clang-format -i`.
- `.clang-tidy`   — conservative ruleset that doesn't fight production C.
- `ci-c-lint.yml` — copy to `.github/workflows/c-lint.yml`.

## Typical workflow

```bash
# 1. quick map of a tree (helps the agent decide where to read)
c-inspect --out /tmp/map.md pufferlib_market/src pufferlib_market/include

# 2. lint
lint-c-md --out /tmp/lint.md pufferlib_market/src

# 3. memory check
valgrind-md --out /tmp/vg.md -- ./pufferlib_market/build/test_env

# 4. CPU hotspots
perf-md --out /tmp/perf.md -- ./pufferlib_market/build/bench

# 5. CUDA kernel analysis (RTX 5090, sm_120)
ncu-md --out /tmp/ncu.md --kernels '.*kernel.*' -- ./build/cuda_bench
nsys-md --out /tmp/nsys.md -- ./build/cuda_bench
cuda-sanitize-md --out /tmp/cs.md -- ./build/cuda_bench

# 6. Offline analysis of saved profiler artifacts
profile-md /tmp/e2e_profile.nsys-rep
profile-md /tmp/attn_profile.ncu-rep
profile-md /tmp/trtexec.log --out /tmp/trtexec.md
```

The Nsight Systems markdown now includes:
- an executive summary,
- a bottleneck ranking across CUDA API, kernel, transfer, and NVTX stages,
- a dedicated NVTX range table when range tracing is present.

## RTX 5090 / Blackwell notes

- Compile CUDA with `-arch=sm_120` (Blackwell consumer).
- For maximum ncu detail, run as root or with `CAP_SYS_ADMIN`, or set
  `/proc/sys/kernel/perf_event_paranoid` to 0 and load `nvidia` with
  `NVreg_RestrictProfilingToAdminUsers=0` in `/etc/modprobe.d/`.
- CUTLASS 3.x kernels: prefer `--section MemoryWorkloadAnalysis_Tables`
  and add `--metrics smsp__pipe_tensor_op_hmma_cycles_active.avg.pct_of_peak_sustained_active`.
- For flash-attention/Hopper code paths, sm_90a is required (not sm_120).
