#include <cstdio>
#include <cuda_runtime.h>
#include <cuda_bf16.h>

__global__ void rd(const uint4* p, size_t n, unsigned* sink) {
  unsigned a = 0;
  for (size_t i = blockIdx.x * (size_t)blockDim.x + threadIdx.x; i < n; i += (size_t)gridDim.x * blockDim.x) {
    uint4 v = __ldcs(p + i);
    a ^= v.x ^ v.y ^ v.z ^ v.w;
  }
  if (a == 0x12345678u) *sink = a;
}
__global__ void cp(const uint4* s, uint4* d, size_t n) {
  for (size_t i = blockIdx.x * (size_t)blockDim.x + threadIdx.x; i < n; i += (size_t)gridDim.x * blockDim.x) __stcs(d + i, __ldcs(s + i));
}
// Cache-resident read: the buffer is sized to fit L2; repeat to amortize launch.
__global__ void l2_rd(const uint4* p, size_t n, int passes, unsigned* sink) {
  unsigned a = 0;
  size_t stride = (size_t)gridDim.x * blockDim.x;
#pragma unroll 1
  for (int pass = 0; pass < passes; pass++)
    for (size_t i = blockIdx.x * (size_t)blockDim.x + threadIdx.x; i < n; i += stride) {
      uint4 v = __ldcg(p + i);
      a ^= v.x ^ v.y ^ v.z ^ v.w;
    }
  if (a == 0x12345678u) *sink = a;
}
__global__ void fma_k(float* o, int iters) {
  float a0 = threadIdx.x, a1 = a0 + 1, a2 = a0 + 2, a3 = a0 + 3, a4 = a0 + 4, a5 = a0 + 5, a6 = a0 + 6, a7 = a0 + 7, b = 1.0001f, c = 0.5f;
  for (int i = 0; i < iters; i++) {
    a0 = fmaf(a0, b, c); a1 = fmaf(a1, b, c); a2 = fmaf(a2, b, c); a3 = fmaf(a3, b, c);
    a4 = fmaf(a4, b, c); a5 = fmaf(a5, b, c); a6 = fmaf(a6, b, c); a7 = fmaf(a7, b, c);
  }
  o[blockIdx.x * blockDim.x + threadIdx.x] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}
#if __CUDA_ARCH__ >= 800 || !defined(__CUDA_ARCH__)
__global__ void mma_k(float* o, int iters) {
  unsigned a0 = threadIdx.x, a1 = a0 + 1, a2 = a0 + 2, a3 = a0 + 3, b0 = a0 + 4, b1 = a0 + 5;
  float c[4][4] = {};
  for (int i = 0; i < iters; i++) {
#pragma unroll
    for (int j = 0; j < 4; j++)
      asm volatile("mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 {%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
        : "+f"(c[j][0]), "+f"(c[j][1]), "+f"(c[j][2]), "+f"(c[j][3]) : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(b0), "r"(b1));
  }
  float s = 0;
  for (int j = 0; j < 4; j++) s += c[j][0] + c[j][1] + c[j][2] + c[j][3];
  o[blockIdx.x * blockDim.x + threadIdx.x] = s;
}
#endif
__global__ void empty_k() {}

template <class F> float tm(F f, int reps) {
  cudaEvent_t a, b; cudaEventCreate(&a); cudaEventCreate(&b);
  f(); cudaDeviceSynchronize();
  float best = 1e30f;
  for (int r = 0; r < reps; r++) {
    cudaEventRecord(a); f(); cudaEventRecord(b); cudaEventSynchronize(b);
    float ms; cudaEventElapsedTime(&ms, a, b); if (ms < best) best = ms;
  }
  return best;
}

int main() {
  cudaDeviceProp pr; cudaGetDeviceProperties(&pr, 0);
  int sms = pr.multiProcessorCount, clk = 0, mclk = 0, bus = 0;
  cudaDeviceGetAttribute(&clk, cudaDevAttrClockRate, 0);
  cudaDeviceGetAttribute(&mclk, cudaDevAttrMemoryClockRate, 0);
  cudaDeviceGetAttribute(&bus, cudaDevAttrGlobalMemoryBusWidth, 0);
  size_t free_b, tot_b; cudaMemGetInfo(&free_b, &tot_b);
  size_t bytes = (size_t)256 << 20;
  if (free_b < 3 * bytes) bytes = free_b / 4 & ~(size_t)15;
  uint4 *s, *d; unsigned* sink; float* o;
  cudaMalloc(&s, bytes); cudaMalloc(&d, bytes); cudaMalloc(&sink, 4); cudaMalloc(&o, sms * 4096 * 4);
  cudaMemset(s, 1, bytes);
  size_t n = bytes / 16;
  int grid = sms * 8;
  float t_rd = tm([&] { rd<<<grid, 256>>>(s, n, sink); }, 30);
  float t_cp = tm([&] { cp<<<grid, 256>>>(s, d, n); }, 30);
  size_t l2b = pr.l2CacheSize ? (size_t)pr.l2CacheSize / 2 : (size_t)4 << 20;
  if (l2b < (size_t)2 << 20) l2b = (size_t)2 << 20;
  if (l2b > bytes) l2b = bytes;
  int l2passes = (int)(((size_t)256 << 20) / l2b);
  if (l2passes < 1) l2passes = 1;
  float t_l2 = tm([&] { l2_rd<<<grid, 256>>>(s, l2b / 16, l2passes, sink); }, 10);
  double l2_t = (double)l2b * l2passes / (t_l2 * 1e-3) / 1e9;
  int fi = 1 << 14;
  float t_fma = tm([&] { fma_k<<<sms * 4, 256>>>(o, fi); }, 10);
  double fma_t = 2.0 * 8 * fi * (double)sms * 4 * 256 / (t_fma * 1e-3) / 1e12;
  double mma_t = 0;
#if defined(__CUDA_ARCH__) || 1
  if (pr.major >= 8) {
    int mi = 1 << 13;
    float t_mma = tm([&] { mma_k<<<sms * 4, 256>>>(o, mi); }, 10);
    mma_t = 4096.0 * 4 * mi * (double)sms * 4 * 8 / (t_mma * 1e-3) / 1e12;
  }
#endif
  float t_l = tm([&] { for (int i = 0; i < 2000; i++) empty_k<<<1, 32>>>(); }, 10) / 2000 * 1e3f;
  cudaStream_t st; cudaStreamCreate(&st);
  auto gtime = [&](int nodes) {
    cudaGraph_t g; cudaGraphExec_t ge;
    cudaStreamBeginCapture(st, cudaStreamCaptureModeGlobal);
    for (int i = 0; i < nodes; i++) empty_k<<<1, 32, 0, st>>>();
    cudaStreamEndCapture(st, &g);
    cudaGraphInstantiate(&ge, g, 0);
    return tm([&] { cudaGraphLaunch(ge, st); cudaStreamSynchronize(st); }, 30);
  };
  float t_g = (gtime(1000) - gtime(200)) / 800 * 1e3f;
  printf("{\"name\":\"%s\",\"sm\":\"%d%d\",\"sms\":%d,\"l2_mb\":%.1f,\"smem_per_sm_kb\":%zu,\"clk_mhz\":%d,\"spec_gbs\":%.0f,"
         "\"rd_gbs\":%.1f,\"copy_gbs\":%.1f,\"l2_gbs\":%.1f,\"fp32_tflops\":%.2f,\"bf16_mma_tflops\":%.2f,\"launch_us\":%.2f,\"graph_node_us\":%.2f}\n",
         pr.name, pr.major, pr.minor, sms, pr.l2CacheSize / 1048576.0, pr.sharedMemPerMultiprocessor / 1024, clk / 1000,
         2.0 * mclk * 1e3 * (bus / 8) / 1e9,
         bytes / (t_rd * 1e-3) / 1e9, 2.0 * bytes / (t_cp * 1e-3) / 1e9, l2_t, fma_t, mma_t, t_l, t_g);
}
