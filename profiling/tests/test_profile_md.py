from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import profile_md  # noqa: E402


def test_parse_nsys_bundle_and_render_contains_hotspots():
    text = """Processing [/tmp/e2e_profile.nsys-rep] with [/opt/reports/cuda_api_sum.py]...
Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name
60.0,6000,6,1000,1000,900,1100,10,cudaMalloc
40.0,4000,4,1000,1000,900,1100,10,cudaMemcpyAsync
Processing [/tmp/e2e_profile.nsys-rep] with [/opt/reports/cuda_gpu_kern_sum.py]...
Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name
80.0,8000,8,1000,1000,900,1100,10,attention_kernel
20.0,2000,2,1000,1000,900,1100,10,layernorm_kernel
Processing [/tmp/e2e_profile.nsys-rep] with [/opt/reports/cuda_gpu_mem_time_sum.py]...
Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name
75.0,7500,3,2500,2500,2000,3000,10,HtoD memcpy
25.0,2500,1,2500,2500,2500,2500,10,DtoH memcpy
Processing [/tmp/e2e_profile.nsys-rep] with [/opt/reports/cuda_gpu_mem_size_sum.py]...
Total Size (bytes),Total Bytes,Name
4096,4096,HtoD memcpy
1024,1024,DtoH memcpy
Processing [/tmp/e2e_profile.nsys-rep] with [/opt/reports/nvtx_sum.py]...
Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Style,Range
80.0,8000,8,1000,1000,900,1100,10,Push/Pop,forward_pass
20.0,2000,2,1000,1000,900,1100,10,Push/Pop,data_prep
"""
    reports = profile_md.parse_nsys_stats_bundle(profile_md.NSYS_DEFAULT_REPORTS, text)

    assert reports["cuda_api_sum"].rows[0]["Name"] == "cudaMalloc"
    assert reports["cuda_gpu_kern_sum"].rows[0]["Name"] == "attention_kernel"
    assert reports["nvtx_sum"].rows[0]["Range"] == "forward_pass"

    md = profile_md.render_nsys_markdown(Path("e2e_profile.nsys-rep"), reports)
    assert "Nsight Systems Report" in md
    assert "Hottest CUDA API" in md
    assert "attention_kernel" in md
    assert "Total transfer volume" in md
    assert "## NVTX Ranges" in md
    assert "## Bottleneck Ranking" in md
    assert "forward_pass" in md


def test_parse_ncu_csv_blocks_and_render_attention_kernels():
    text = """==PROF== Connected to process 12345
ID,Process ID,Process Name,Kernel Name,Metric Name,Metric Value,Metric Unit,duration_ms
1,12345,python,attention_0,sm__throughput.avg.pct_of_peak_sustained_elapsed,82.3,%,0.400
1,12345,python,attention_0,gpu__compute_memory_throughput.avg.pct_of_peak_sustained_elapsed,43.1,%,0.400
1,12345,python,attention_0,sm__warps_active.avg.pct_of_peak_sustained_active,54.2,%,0.400
2,12345,python,attention_1,sm__throughput.avg.pct_of_peak_sustained_elapsed,91.0,%,0.200
2,12345,python,attention_1,launch__registers_per_thread,64,regs,0.200
2,12345,python,attention_1,launch__shared_mem_config_size,16384,bytes,0.200
"""
    rows = profile_md._ncu_parse_csv_blocks(text)
    kernels = profile_md._normalize_ncu_rows(rows)

    assert "attention_0" in kernels
    assert float(kernels["attention_0"]["metrics"]["sm__throughput.avg.pct_of_peak_sustained_elapsed"]) == 82.3

    md = profile_md.render_ncu_markdown(Path("attn_profile.ncu-rep"), kernels)
    assert "Nsight Compute Report" in md
    assert "Attention kernels" in md
    assert "attention_0" in md
    assert "Kernel Metrics" in md


def test_parse_trtexec_log_and_render_summary_and_layers():
    text = """[04/26/2024-00:31:43] [I] [TRT] Throughput: 1234.56 qps
[04/26/2024-00:31:43] [I] [TRT] Latency: min = 0.100 ms, max = 0.200 ms, mean = 0.150 ms, median = 0.140 ms, percentile(90%) = 0.180 ms
[04/26/2024-00:31:43] [I] [TRT] Enqueue Time: min = 0.050 ms, max = 0.080 ms, mean = 0.060 ms, median = 0.055 ms, percentile(90%) = 0.070 ms
[04/26/2024-00:31:43] [I] [TRT] GPU Compute Time: min = 0.040 ms, max = 0.070 ms, mean = 0.050 ms, median = 0.045 ms, percentile(90%) = 0.060 ms
[04/26/2024-00:31:43] [I] [TRT] conv1 0.123 ms
[04/26/2024-00:31:43] [I] [TRT] attention_block 0.456 ms
"""
    data = profile_md.parse_trtexec_log(text)
    assert data["summary"]["Throughput"]["throughput_qps"] == 1234.56
    assert len(data["layers"]) == 2

    md = profile_md.render_trtexec_markdown(Path("trtexec.log"), data)
    assert "TensorRT trtexec Report" in md
    assert "Per-Layer Runtime" in md
    assert "attention_block" in md
    assert "Throughput" in md


def test_detect_kind_from_suffix_and_content():
    assert profile_md.detect_kind(Path("e2e_profile.nsys-rep")) == "nsys"
    assert profile_md.detect_kind(Path("attn_profile.ncu-rep")) == "ncu"
    assert profile_md.detect_kind(Path("trtexec.log")) == "trtexec"
