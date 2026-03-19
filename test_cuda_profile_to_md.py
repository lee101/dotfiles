#!/usr/bin/env python3
"""Tests for cuda_profile_to_md.py"""

import json
import os
import subprocess
import sys
import tempfile

import pytest

# Allow importing from the same directory
sys.path.insert(0, os.path.dirname(__file__))

from cuda_profile_to_md import (
    _event_bytes,
    _event_dur_ms,
    _fmt_mb,
    _fmt_ms,
    _generate_markdown,
    _is_kernel_event,
    _is_memcpy_event,
    _is_sync_event,
    _is_mem_event,
    _load_trace,
    _memcpy_direction,
    analyze_trace,
    main,
    trace_to_markdown,
)


# ---------------------------------------------------------------------------
# Fixtures: synthetic Chrome trace events
# ---------------------------------------------------------------------------

def _make_kernel_event(name="volta_sgemm_128x128", dur_us=500, cat="kernel"):
    return {"ph": "X", "cat": cat, "name": name, "dur": dur_us, "ts": 1000, "args": {}}


def _make_memcpy_event(name="Memcpy HtoD", dur_us=100, nbytes=1048576, cat="gpu_memcpy"):
    return {
        "ph": "X", "cat": cat, "name": name, "dur": dur_us, "ts": 2000,
        "args": {"bytes": nbytes},
    }


def _make_sync_event(name="cudaDeviceSynchronize", dur_us=200):
    return {"ph": "X", "cat": "cuda_runtime", "name": name, "dur": dur_us, "ts": 3000, "args": {}}


def _make_mem_event(name="[memory]", nbytes=4194304, dur_us=10):
    return {
        "ph": "X", "cat": "memory", "name": name, "dur": dur_us, "ts": 4000,
        "args": {"bytes": nbytes},
    }


def _make_cpu_event(name="aten::mm", dur_us=300):
    return {"ph": "X", "cat": "cpu_op", "name": name, "dur": dur_us, "ts": 5000, "args": {}}


def _build_sample_trace():
    """Build a realistic sample trace with multiple event types."""
    return [
        _make_kernel_event("volta_sgemm_128x128_nn", 500),
        _make_kernel_event("volta_sgemm_128x128_nn", 600),
        _make_kernel_event("volta_sgemm_128x128_nn", 450),
        _make_kernel_event("void at::native::vectorized_elementwise_kernel", 100, cat="kernel"),
        _make_kernel_event("void at::native::vectorized_elementwise_kernel", 120, cat="kernel"),
        _make_kernel_event("void cutlass::reduce_kernel", 80, cat="kernel"),
        _make_memcpy_event("Memcpy HtoD (Pageable -> Device)", 50, 2097152),
        _make_memcpy_event("Memcpy HtoD (Pageable -> Device)", 60, 1048576),
        _make_memcpy_event("Memcpy DtoH (Device -> Pageable)", 30, 524288),
        _make_sync_event("cudaDeviceSynchronize", 200),
        _make_sync_event("cudaDeviceSynchronize", 150),
        _make_mem_event("[memory]", 4194304, 5),
        _make_mem_event("[memory]", 8388608, 8),
        _make_cpu_event("aten::mm", 300),
        _make_cpu_event("aten::add", 50),
        # Non-complete events should be ignored
        {"ph": "B", "cat": "kernel", "name": "begin_only", "ts": 100},
        {"ph": "M", "cat": "metadata", "name": "process_name", "ts": 0},
    ]


# ---------------------------------------------------------------------------
# Tests: Event classification
# ---------------------------------------------------------------------------

class TestEventClassification:
    def test_is_kernel_event_by_cat(self):
        assert _is_kernel_event({"ph": "X", "cat": "kernel", "name": "foo"})
        assert _is_kernel_event({"ph": "X", "cat": "Kernel", "name": "foo"})
        assert _is_kernel_event({"ph": "X", "cat": "gpu_kernel", "name": "foo"})

    def test_is_kernel_event_by_name_hints(self):
        assert _is_kernel_event({"ph": "X", "cat": "other", "name": "volta_sgemm_128x128"})
        assert _is_kernel_event({"ph": "X", "cat": "other", "name": "cutlass_gemm_kernel"})
        assert _is_kernel_event({"ph": "X", "cat": "other", "name": "at::native::reduce"})
        assert _is_kernel_event({"ph": "X", "cat": "other", "name": "void softmax_kernel<>"})
        assert _is_kernel_event({"ph": "X", "cat": "other", "name": "elementwise_add"})
        assert _is_kernel_event({"ph": "X", "cat": "other", "name": "ampere_sgemm"})

    def test_is_kernel_event_rejects_non_kernels(self):
        assert not _is_kernel_event({"ph": "X", "cat": "cpu_op", "name": "aten::mm"})
        assert not _is_kernel_event({"ph": "M", "cat": "kernel", "name": "foo"})  # wrong phase

    def test_is_memcpy_event(self):
        assert _is_memcpy_event({"cat": "gpu_memcpy", "name": "Memcpy HtoD"})
        assert _is_memcpy_event({"cat": "other", "name": "cudaMemcpy"})
        assert not _is_memcpy_event({"cat": "cpu_op", "name": "aten::copy_"})

    def test_memcpy_direction(self):
        assert _memcpy_direction({"name": "Memcpy HtoD"}) == "H->D"
        assert _memcpy_direction({"name": "Memcpy DtoH"}) == "D->H"
        assert _memcpy_direction({"name": "Memcpy DtoD"}) == "D->D"
        assert _memcpy_direction({"name": "cudaMemcpy", "args": {"src": "Host", "dst": "Device"}}) == "H->D"
        assert _memcpy_direction({"name": "cudaMemcpy", "args": {}}) == "Unknown"

    def test_is_sync_event(self):
        assert _is_sync_event({"name": "cudaDeviceSynchronize"})
        assert _is_sync_event({"name": "Synchronize"})
        assert not _is_sync_event({"name": "aten::mm"})

    def test_is_mem_event(self):
        assert _is_mem_event({"name": "[memory]", "cat": ""})
        assert _is_mem_event({"name": "cudaMalloc", "cat": ""})
        assert _is_mem_event({"name": "foo", "cat": "memory"})
        assert not _is_mem_event({"name": "aten::mm", "cat": "cpu_op"})


# ---------------------------------------------------------------------------
# Tests: Helper functions
# ---------------------------------------------------------------------------

class TestHelpers:
    def test_event_dur_ms(self):
        assert _event_dur_ms({"dur": 1000}) == 1.0
        assert _event_dur_ms({"dur": 500}) == 0.5
        assert _event_dur_ms({}) == 0.0

    def test_event_bytes(self):
        assert _event_bytes({"args": {"bytes": 1024}}) == 1024.0
        assert _event_bytes({"args": {"Bytes": 2048}}) == 2048.0
        assert _event_bytes({"args": {"size": 512}}) == 512.0
        assert _event_bytes({"args": {}}) == 0.0
        assert _event_bytes({}) == 0.0

    def test_fmt_ms(self):
        assert _fmt_ms(1000000) == "1,000.0"  # 1000ms
        assert _fmt_ms(5000) == "5.00"  # 5ms
        assert _fmt_ms(500) == "0.500"  # 0.5ms

    def test_fmt_mb(self):
        assert _fmt_mb(1048576) == "1.000"  # 1MB
        assert _fmt_mb(10485760) == "10.0"  # 10MB
        assert _fmt_mb(0) == "0.000"


# ---------------------------------------------------------------------------
# Tests: Trace loading
# ---------------------------------------------------------------------------

class TestLoadTrace:
    def test_load_list_format(self):
        events = [{"ph": "X", "name": "test"}]
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(events, f)
            f.flush()
            path = f.name
        try:
            loaded = _load_trace(path)
            assert len(loaded) == 1
            assert loaded[0]["name"] == "test"
        finally:
            os.unlink(path)

    def test_load_dict_format(self):
        data = {"traceEvents": [{"ph": "X", "name": "test2"}], "metadata": {}}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(data, f)
            f.flush()
            path = f.name
        try:
            loaded = _load_trace(path)
            assert len(loaded) == 1
            assert loaded[0]["name"] == "test2"
        finally:
            os.unlink(path)

    def test_load_empty(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump([], f)
            f.flush()
            path = f.name
        try:
            loaded = _load_trace(path)
            assert loaded == []
        finally:
            os.unlink(path)


# ---------------------------------------------------------------------------
# Tests: Analysis
# ---------------------------------------------------------------------------

class TestAnalyze:
    def test_analyze_sample_trace(self):
        events = _build_sample_trace()
        result = analyze_trace(events, top_n=10)

        # Should find 3 distinct kernel names
        assert len(result["kernels"]) == 3
        # First kernel should be the sgemm (highest total time)
        top_name, top_stats = result["kernels"][0]
        assert "sgemm" in top_name
        assert top_stats["calls"] == 3
        assert top_stats["total_us"] == 500 + 600 + 450

    def test_analyze_memcpy(self):
        events = _build_sample_trace()
        result = analyze_trace(events)

        assert "H->D" in result["memcpy"]
        assert result["memcpy"]["H->D"]["count"] == 2
        assert result["memcpy"]["H->D"]["total_bytes"] == 2097152 + 1048576

        assert "D->H" in result["memcpy"]
        assert result["memcpy"]["D->H"]["count"] == 1

    def test_analyze_sync(self):
        events = _build_sample_trace()
        result = analyze_trace(events)

        assert "cudaDeviceSynchronize" in result["sync"]
        assert result["sync"]["cudaDeviceSynchronize"]["count"] == 2
        assert result["sync"]["cudaDeviceSynchronize"]["total_us"] == 350

    def test_analyze_memory(self):
        events = _build_sample_trace()
        result = analyze_trace(events)

        assert len(result["mem_allocs"]) == 2

    def test_analyze_total_gpu_time(self):
        events = _build_sample_trace()
        result = analyze_trace(events)

        # GPU time = kernels + memcpy
        # Kernels: sgemm(500+600+450) + elementwise(100+120) + reduce(80) = 1850
        kernel_time = 500 + 600 + 450 + 100 + 120 + 80  # 1850
        # Memcpy: HtoD(50+60) + DtoH(30) = 140
        memcpy_time = 50 + 60 + 30  # 140
        assert result["total_gpu_us"] == kernel_time + memcpy_time  # 1990

    def test_analyze_total_cpu_time(self):
        events = _build_sample_trace()
        result = analyze_trace(events)

        # CPU time = sync + general cpu events (aten::mm=300, aten::add=50)
        sync_time = 200 + 150  # 350
        cpu_time = 300 + 50  # 350
        assert result["total_cpu_us"] == sync_time + cpu_time  # 700

    def test_analyze_top_n_limits(self):
        events = _build_sample_trace()
        result = analyze_trace(events, top_n=2)
        assert len(result["kernels"]) == 2

    def test_analyze_empty(self):
        result = analyze_trace([], top_n=10)
        assert result["kernels"] == []
        assert result["memcpy"] == {}
        assert result["sync"] == {}
        assert result["total_gpu_us"] == 0.0
        assert result["total_cpu_us"] == 0.0

    def test_non_complete_events_ignored(self):
        """Events with ph != 'X' should be ignored."""
        events = [
            {"ph": "B", "cat": "kernel", "name": "begin_event", "dur": 999, "ts": 0},
            {"ph": "E", "cat": "kernel", "name": "end_event", "dur": 999, "ts": 0},
            {"ph": "M", "cat": "kernel", "name": "metadata", "dur": 999, "ts": 0},
        ]
        result = analyze_trace(events)
        assert result["kernels"] == []
        assert result["total_gpu_us"] == 0.0


# ---------------------------------------------------------------------------
# Tests: Markdown generation
# ---------------------------------------------------------------------------

class TestMarkdownGeneration:
    def test_generate_has_all_sections(self):
        events = _build_sample_trace()
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)

        assert "# CUDA Profiling Report" in md
        assert "## GPU Kernel Hotspots" in md
        assert "## Host <-> Device Transfers" in md
        assert "## Memory Timeline" in md
        assert "## Sync Points" in md
        assert "## Summary" in md

    def test_generate_kernel_table(self):
        events = _build_sample_trace()
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)

        # The top kernel should be sgemm
        assert "sgemm" in md
        assert "| Rank |" in md
        assert "| 1 |" in md

    def test_generate_memcpy_table(self):
        events = _build_sample_trace()
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)

        assert "H->D" in md
        assert "D->H" in md

    def test_generate_sync_table(self):
        events = _build_sample_trace()
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)

        assert "cudaDeviceSynchronize" in md

    def test_generate_summary(self):
        events = _build_sample_trace()
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)

        assert "Total GPU Time" in md
        assert "Total CPU Time" in md
        assert "GPU Utilization" in md

    def test_generate_empty_trace(self):
        analysis = analyze_trace([])
        md = _generate_markdown(analysis)

        assert "# CUDA Profiling Report" in md
        assert "_No GPU kernel events found._" in md
        assert "_No memory transfer events found._" in md
        assert "_No synchronization events found._" in md

    def test_long_kernel_name_truncated(self):
        events = [_make_kernel_event("a" * 100, 500)]
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)
        # Name should be truncated to 60 chars
        assert "..." in md

    def test_kernel_percentage(self):
        events = [
            _make_kernel_event("kernel_a", 1000),
            _make_kernel_event("kernel_b", 1000),
        ]
        analysis = analyze_trace(events)
        md = _generate_markdown(analysis)
        # Each kernel is 50% of GPU time (ignoring memcpy)
        assert "50.0%" in md


# ---------------------------------------------------------------------------
# Tests: End-to-end trace_to_markdown
# ---------------------------------------------------------------------------

class TestTraceToMarkdown:
    def test_e2e_with_file(self):
        events = _build_sample_trace()
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(events, f)
            path = f.name
        try:
            md = trace_to_markdown(path, top_n=5)
            assert "# CUDA Profiling Report" in md
            assert "sgemm" in md
        finally:
            os.unlink(path)

    def test_e2e_dict_format(self):
        events = _build_sample_trace()
        data = {"traceEvents": events}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(data, f)
            path = f.name
        try:
            md = trace_to_markdown(path, top_n=5)
            assert "sgemm" in md
        finally:
            os.unlink(path)


# ---------------------------------------------------------------------------
# Tests: CLI
# ---------------------------------------------------------------------------

class TestCLI:
    def test_cli_trace_mode(self):
        events = _build_sample_trace()
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(events, f)
            trace_path = f.name

        with tempfile.NamedTemporaryFile(suffix=".md", delete=False) as out:
            output_path = out.name

        try:
            main(["--trace", trace_path, "--output", output_path, "--top", "5"])
            with open(output_path) as f:
                md = f.read()
            assert "# CUDA Profiling Report" in md
            assert "sgemm" in md
        finally:
            os.unlink(trace_path)
            os.unlink(output_path)

    def test_cli_trace_file_not_found(self):
        with pytest.raises(SystemExit):
            main(["--trace", "/nonexistent/file.json"])

    def test_cli_no_args(self):
        with pytest.raises(SystemExit):
            main([])

    def test_cli_mutual_exclusion(self):
        with pytest.raises(SystemExit):
            main(["--trace", "a.json", "--run", "echo hi"])

    def test_cli_stdout_output(self, capsys):
        events = _build_sample_trace()
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(events, f)
            trace_path = f.name
        try:
            main(["--trace", trace_path])
            captured = capsys.readouterr()
            assert "# CUDA Profiling Report" in captured.out
        finally:
            os.unlink(trace_path)

    def test_cli_custom_top_n(self):
        # Create trace with many kernels
        events = [_make_kernel_event(f"kernel_{i}", 100 + i) for i in range(30)]
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(events, f)
            trace_path = f.name

        with tempfile.NamedTemporaryFile(suffix=".md", delete=False) as out:
            output_path = out.name

        try:
            main(["--trace", trace_path, "--output", output_path, "--top", "3"])
            with open(output_path) as f:
                md = f.read()
            # Should have ranks 1-3 but not 4+
            assert "| 1 |" in md
            assert "| 3 |" in md
            assert "| 4 |" not in md
        finally:
            os.unlink(trace_path)
            os.unlink(output_path)


# ---------------------------------------------------------------------------
# Tests: Edge cases
# ---------------------------------------------------------------------------

class TestEdgeCases:
    def test_zero_duration_events(self):
        events = [_make_kernel_event("zero_dur_kernel", 0)]
        result = analyze_trace(events)
        assert len(result["kernels"]) == 1
        _, stats = result["kernels"][0]
        assert stats["calls"] == 1
        assert stats["total_us"] == 0

    def test_single_event(self):
        events = [_make_kernel_event("only_kernel", 42)]
        result = analyze_trace(events)
        md = _generate_markdown(result)
        assert "100.0%" in md  # Single kernel = 100% GPU

    def test_no_kernel_events(self):
        events = [_make_sync_event("cudaDeviceSynchronize", 100)]
        result = analyze_trace(events)
        assert result["kernels"] == []
        md = _generate_markdown(result)
        assert "_No GPU kernel events found._" in md

    def test_only_memcpy(self):
        events = [_make_memcpy_event("Memcpy HtoD", 100, 1024)]
        result = analyze_trace(events)
        assert result["kernels"] == []
        assert "H->D" in result["memcpy"]

    def test_event_bytes_string_value(self):
        assert _event_bytes({"args": {"bytes": "1024"}}) == 1024.0

    def test_event_bytes_invalid_string(self):
        assert _event_bytes({"args": {"bytes": "not_a_number"}}) == 0.0

    def test_duplicate_kernel_names_aggregated(self):
        events = [
            _make_kernel_event("same_kernel", 100),
            _make_kernel_event("same_kernel", 200),
            _make_kernel_event("same_kernel", 300),
        ]
        result = analyze_trace(events)
        assert len(result["kernels"]) == 1
        _, stats = result["kernels"][0]
        assert stats["calls"] == 3
        assert stats["total_us"] == 600

    def test_many_kernels_sorted_by_total(self):
        events = [
            _make_kernel_event("slow_kernel", 1000),
            _make_kernel_event("fast_kernel", 10),
            _make_kernel_event("medium_kernel", 500),
        ]
        result = analyze_trace(events, top_n=10)
        names = [name for name, _ in result["kernels"]]
        assert names[0] == "slow_kernel"
        assert names[1] == "medium_kernel"
        assert names[2] == "fast_kernel"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
