#!/usr/bin/env python3
"""Unit tests for cuda_prof_report."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
import argparse
import errno
from contextlib import redirect_stdout
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
from unittest.mock import patch


TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

from cuda_prof_report import (
    ProfileArtifacts,
    PolicyCheck,
    _artifact_path,
    _link_or_copy,
    _positive_float,
    _report_section,
    _resolve_report_sections,
    _processing_report_name,
    _top_rows,
    _default_prefix_path,
    _normalize_path,
    _api_pct_limit,
    _positive_int,
    _sync_optional_link,
    evaluate_policy_checks,
    main,
    overall_status,
    parse_nsys_csv_output,
    parse_nsys_stats_bundle,
    profile_command,
    render_markdown,
)


API_OUTPUT = """Generating SQLite file /tmp/sample.sqlite from /tmp/sample.nsys-rep
Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]...
Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name
99.3,494092651,3,164697550.3,3870.0,2020,494086761,285259424.2,cudaMalloc
0.6,3188157,12,265679.8,995.0,930,3175897,916480.8,cudaLaunchKernel
0.1,1000,1,1000.0,1000.0,1000,1000,0.0,cudaFree
"""

KERNEL_SKIPPED = """Generating SQLite file /tmp/sample.sqlite from /tmp/sample.nsys-rep
Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_kern_sum.py]...
SKIPPED: /tmp/sample.sqlite does not contain CUDA kernel data.
"""

MEM_TIME_OUTPUT = """Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_mem_time_sum.py]...
Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Operation
70.0,7000,7,1000.0,1000.0,500,1500,100.0,[CUDA memcpy HtoD]
30.0,3000,3,1000.0,1000.0,500,1500,100.0,[CUDA memcpy DtoH]
"""

MEM_SIZE_OUTPUT = """Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_mem_size_sum.py]...
Time (%),Total Size (bytes),Instances,Avg (bytes),Med (bytes),Min (bytes),Max (bytes),StdDev (bytes),Operation
70.0,1048576,7,149796.6,131072.0,1024,524288,0.0,[CUDA memcpy HtoD]
30.0,262144,3,87381.3,65536.0,1024,131072,0.0,[CUDA memcpy DtoH]
"""

NVTX_OUTPUT = """Processing [/tmp/sample.sqlite] with [/opt/reports/nvtx_sum.py]...
Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Style,Range
80.0,8000,8,1000.0,1000.0,900,1100,0.0,Push/Pop,forward_pass
20.0,2000,2,1000.0,1000.0,900,1100,0.0,Push/Pop,data_prep
"""

STATS_BUNDLE_OUTPUT = """Generating SQLite file /tmp/sample.sqlite from /tmp/sample.nsys-rep
Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]...
Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name
99.3,494092651,3,164697550.3,3870.0,2020,494086761,285259424.2,cudaMalloc

Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_kern_sum.py]...
SKIPPED: /tmp/sample.sqlite does not contain CUDA kernel data.

Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_mem_time_sum.py]...
Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Operation
70.0,7000,7,1000.0,1000.0,500,1500,100.0,[CUDA memcpy HtoD]
"""

OUT_OF_ORDER_STATS_BUNDLE_OUTPUT = """Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_mem_time_sum.py]...
Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Operation
70.0,7000,7,1000.0,1000.0,500,1500,100.0,[CUDA memcpy HtoD]

Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]...
Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name
99.3,494092651,3,164697550.3,3870.0,2020,494086761,285259424.2,cudaMalloc
"""


def _fake_nsys_script(exit_code: int = 0, emit_sqlite: bool = False) -> str:
    sqlite_line = ""
    if emit_sqlite:
        sqlite_line = 'pathlib.Path(str(out_prefix) + ".sqlite").write_text("fake sqlite")'

    return textwrap.dedent(
        f"""\
        #!/usr/bin/env python3
        import pathlib
        import sys

        argv = sys.argv[1:]
        if argv[0] == "profile":
            out_prefix = pathlib.Path(argv[argv.index("-o") + 1])
            out_prefix.with_suffix(".nsys-rep").write_text("fake report")
            {sqlite_line}
            print("WARNING: fake profiler warning")
            raise SystemExit({exit_code})
        if argv[0] == "stats":
            report = argv[argv.index("--report") + 1]
            reports = report.split(",")
            for name in reports:
                print(f"Processing [/tmp/sample.sqlite] with [/opt/reports/{{name}}.py]...")
                if name == "cuda_api_sum":
                    print("Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name")
                    print("90.0,9000,3,3000.0,3000.0,1000,5000,0.0,cudaMalloc")
                elif name == "cuda_gpu_mem_time_sum":
                    print("Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Operation")
                    print("100.0,5000,2,2500.0,2500.0,2000,3000,0.0,[CUDA memcpy HtoD]")
                elif name == "cuda_gpu_mem_size_sum":
                    print("Time (%),Total Size (bytes),Instances,Avg (bytes),Med (bytes),Min (bytes),Max (bytes),StdDev (bytes),Operation")
                    print("100.0,1048576,2,524288.0,524288.0,524288,524288,0.0,[CUDA memcpy HtoD]")
                elif name == "nvtx_sum":
                    print("Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Style,Range")
                    print("80.0,8000,8,1000.0,1000.0,900,1100,0.0,Push/Pop,forward_pass")
                    print("20.0,2000,2,1000.0,1000.0,900,1100,0.0,Push/Pop,data_prep")
                else:
                    print(f"SKIPPED: no data for {{name}}")
                print()
            raise SystemExit(0)
        raise SystemExit(1)
        """
    )


def _write_fake_nsys(tmp: Path, exit_code: int = 0, emit_sqlite: bool = False) -> Path:
    fake_nsys = tmp / "fake-nsys"
    fake_nsys.write_text(_fake_nsys_script(exit_code=exit_code, emit_sqlite=emit_sqlite))
    fake_nsys.chmod(0o755)
    return fake_nsys


def _write_profile_fail_nsys(tmp: Path, name: str = "fake-nsys-profile-fail") -> Path:
    fake_nsys = tmp / name
    fake_nsys.write_text(
        textwrap.dedent(
            """\
            #!/usr/bin/env python3
            import sys

            argv = sys.argv[1:]
            if argv[0] == "profile":
                print("ERROR: synthetic profile failure", file=sys.stderr)
                raise SystemExit(1)
            raise SystemExit(99)
            """
        )
    )
    fake_nsys.chmod(0o755)
    return fake_nsys


def _write_stats_fail_nsys(tmp: Path, name: str = "fake-nsys-stats-fail") -> Path:
    fake_nsys = tmp / name
    fake_nsys.write_text(
        textwrap.dedent(
            """\
            #!/usr/bin/env python3
            import pathlib
            import sys

            argv = sys.argv[1:]
            if argv[0] == "profile":
                out_prefix = pathlib.Path(argv[argv.index("-o") + 1])
                out_prefix.with_suffix(".nsys-rep").write_text("fake report")
                raise SystemExit(0)
            if argv[0] == "stats":
                print("Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]...")
                print("SKIPPED: synthetic stats failure")
                raise SystemExit(9)
            raise SystemExit(1)
            """
        )
    )
    fake_nsys.chmod(0o755)
    return fake_nsys


def _write_sleepy_nsys(
    tmp: Path,
    *,
    name: str = "fake-nsys-sleepy",
    profile_sleep_s: float = 0.0,
    stats_sleep_s: float = 0.0,
) -> Path:
    fake_nsys = tmp / name
    fake_nsys.write_text(
        textwrap.dedent(
            f"""\
            #!/usr/bin/env python3
            import pathlib
            import sys
            import time

            argv = sys.argv[1:]
            if argv[0] == "profile":
                time.sleep({profile_sleep_s})
                out_prefix = pathlib.Path(argv[argv.index("-o") + 1])
                out_prefix.with_suffix(".nsys-rep").write_text("fake report")
                raise SystemExit(0)
            if argv[0] == "stats":
                time.sleep({stats_sleep_s})
                print("Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]...")
                print("Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name")
                print("90.0,9000,3,3000.0,3000.0,1000,5000,0.0,cudaMalloc")
                raise SystemExit(0)
            raise SystemExit(1)
            """
        )
    )
    fake_nsys.chmod(0o755)
    return fake_nsys


def _make_artifacts(
    *,
    command: list[str] | None = None,
    exit_code: int = 0,
    stats_exit_code: int | None = None,
    reports: dict[str, object] | None = None,
    profile_stderr: str = "",
) -> ProfileArtifacts:
    return ProfileArtifacts(
        command=command or ["/tmp/app"],
        exit_code=exit_code,
        stats_exit_code=stats_exit_code,
        wall_time_s=0.25,
        generated_at="2026-03-29T00:00:00+00:00",
        prefix=Path("/tmp/sample"),
        rep_path=Path("/tmp/sample.nsys-rep"),
        sqlite_path=None,
        reports=reports or {},
        profile_stderr=profile_stderr,
    )


class ParseTests(unittest.TestCase):
    def test_processing_report_name(self) -> None:
        self.assertEqual(
            _processing_report_name(
                "Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]..."
            ),
            "cuda_api_sum",
        )
        self.assertIsNone(_processing_report_name("Processing without a report filename"))

    def test_api_pct_limit_validation(self) -> None:
        self.assertEqual(_api_pct_limit("cudaMalloc=12.5"), ("cudaMalloc", 12.5))
        with self.assertRaises(argparse.ArgumentTypeError):
            _api_pct_limit("cudaMalloc")
        with self.assertRaises(argparse.ArgumentTypeError):
            _api_pct_limit("=10")
        with self.assertRaises(argparse.ArgumentTypeError):
            _api_pct_limit("cudaMalloc=-1")

    def test_report_section_validation(self) -> None:
        self.assertEqual(_report_section("api"), "api")
        self.assertEqual(_report_section("Kernels"), "kernels")
        with self.assertRaises(argparse.ArgumentTypeError):
            _report_section("bogus")

    def test_resolve_report_sections_adds_policy_dependencies(self) -> None:
        self.assertEqual(
            _resolve_report_sections(["api"], require_kernels=True),
            ("api", "kernels"),
        )
        self.assertEqual(
            _resolve_report_sections(["kernels"], max_api_time_pct=[("cudaMalloc", 10.0)]),
            ("kernels", "api"),
        )

    def test_positive_float_validation(self) -> None:
        self.assertEqual(_positive_float("0.25"), 0.25)
        with self.assertRaises(argparse.ArgumentTypeError):
            _positive_float("0")
        with self.assertRaises(argparse.ArgumentTypeError):
            _positive_float("abc")

    def test_positive_int_validation(self) -> None:
        self.assertEqual(_positive_int("3"), 3)
        with self.assertRaises(argparse.ArgumentTypeError):
            _positive_int("0")

    def test_normalize_path_expands_user(self) -> None:
        self.assertEqual(
            _normalize_path(Path("~/tmp-test-path")),
            Path.home() / "tmp-test-path",
        )

    def test_artifact_path_resolves_relative_prefix_against_cwd(self) -> None:
        self.assertEqual(
            _artifact_path(Path("reports/sample"), Path("/tmp/workdir")),
            Path("/tmp/workdir/reports/sample"),
        )
        self.assertEqual(
            _artifact_path(Path("/tmp/absolute/sample"), Path("/tmp/workdir")),
            Path("/tmp/absolute/sample"),
        )

    def test_link_or_copy_falls_back_to_copy_when_symlinks_are_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            src = tmp / "source.txt"
            dst = tmp / "nested" / "latest.txt"
            src.write_text("hello")

            def fake_symlink_to(self: Path, target: Path) -> None:
                raise OSError(errno.EPERM, "symlinks disabled")

            with patch.object(Path, "symlink_to", fake_symlink_to):
                _link_or_copy(src, dst)

            self.assertTrue(dst.exists())
            self.assertFalse(dst.is_symlink())
            self.assertEqual(dst.read_text(), "hello")

    def test_sync_optional_link_removes_stale_target_when_source_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            dst = tmp / "latest.sqlite"
            dst.write_text("stale")

            _sync_optional_link(None, dst)

            self.assertFalse(dst.exists())

    def test_parse_csv_report(self) -> None:
        report = parse_nsys_csv_output("cuda_api_sum", API_OUTPUT)
        self.assertIsNone(report.skipped)
        self.assertEqual(report.headers[0], "Time (%)")
        self.assertEqual(len(report.rows), 3)
        self.assertEqual(report.rows[0]["Name"], "cudaMalloc")

    def test_top_rows_uses_stable_partial_selection(self) -> None:
        report = parse_nsys_csv_output(
            "cuda_api_sum",
            """Time (%),Total Time (ns),Num Calls,Name
1.0,5,1,first
1.0,5,1,second
1.0,4,1,third
""",
        )
        top = _top_rows(report, 2)
        self.assertEqual([row["Name"] for row in top], ["first", "second"])

    def test_parse_skipped_report(self) -> None:
        report = parse_nsys_csv_output("cuda_gpu_kern_sum", KERNEL_SKIPPED)
        self.assertEqual(report.skipped, "/tmp/sample.sqlite does not contain CUDA kernel data.")
        self.assertEqual(report.rows, [])

    def test_parse_nsys_stats_bundle(self) -> None:
        reports = parse_nsys_stats_bundle(
            ["cuda_api_sum", "cuda_gpu_kern_sum", "cuda_gpu_mem_time_sum"],
            STATS_BUNDLE_OUTPUT,
        )
        self.assertEqual(reports["cuda_api_sum"].rows[0]["Name"], "cudaMalloc")
        self.assertEqual(
            reports["cuda_gpu_kern_sum"].skipped,
            "/tmp/sample.sqlite does not contain CUDA kernel data.",
        )
        self.assertEqual(
            reports["cuda_gpu_mem_time_sum"].rows[0]["Operation"],
            "[CUDA memcpy HtoD]",
        )

    def test_parse_nsys_stats_bundle_uses_report_names_not_position(self) -> None:
        reports = parse_nsys_stats_bundle(
            ["cuda_api_sum", "cuda_gpu_mem_time_sum"],
            OUT_OF_ORDER_STATS_BUNDLE_OUTPUT,
        )
        self.assertEqual(reports["cuda_api_sum"].rows[0]["Name"], "cudaMalloc")
        self.assertEqual(
            reports["cuda_gpu_mem_time_sum"].rows[0]["Operation"],
            "[CUDA memcpy HtoD]",
        )


class MarkdownTests(unittest.TestCase):
    def test_render_markdown_contains_useful_sections(self) -> None:
        artifacts = _make_artifacts(
            command=["/tmp/app", "--bench"],
            reports={
                "cuda_api_sum": parse_nsys_csv_output("cuda_api_sum", API_OUTPUT),
                "cuda_gpu_kern_sum": parse_nsys_csv_output("cuda_gpu_kern_sum", KERNEL_SKIPPED),
                "cuda_gpu_mem_time_sum": parse_nsys_csv_output("cuda_gpu_mem_time_sum", MEM_TIME_OUTPUT),
                "cuda_gpu_mem_size_sum": parse_nsys_csv_output("cuda_gpu_mem_size_sum", MEM_SIZE_OUTPUT),
                "nvtx_sum": parse_nsys_csv_output("nvtx_sum", NVTX_OUTPUT),
            },
            profile_stderr="WARNING: mock warning from profiler",
        )
        markdown = render_markdown(artifacts)
        self.assertIn("# CUDA Profile Report", markdown)
        self.assertIn("Overall status: `OK`", markdown)
        self.assertIn("cudaMalloc", markdown)
        self.assertIn("Allocation/setup overhead dominates", markdown)
        self.assertIn("DtoH", markdown)
        self.assertIn("HtoD", markdown)
        self.assertIn("forward_pass", markdown)
        self.assertIn("## NVTX Ranges", markdown)
        self.assertIn("## Bottleneck Ranking", markdown)
        self.assertIn("## Profiler Notes", markdown)
        self.assertIn("## Recommendations", markdown)
        self.assertIn("mock warning from profiler", markdown)
        self.assertIn("Reuse device buffers or add a persistent workspace", markdown)
        self.assertIn("No GPU kernels were captured.", markdown)
        self.assertIn("Stats exit code: `n/a`", markdown)

    def test_render_markdown_honors_top_limit(self) -> None:
        artifacts = _make_artifacts(
            reports={
                "cuda_api_sum": parse_nsys_csv_output("cuda_api_sum", API_OUTPUT),
                "cuda_gpu_kern_sum": parse_nsys_csv_output("cuda_gpu_kern_sum", KERNEL_SKIPPED),
                "cuda_gpu_mem_time_sum": parse_nsys_csv_output("cuda_gpu_mem_time_sum", MEM_TIME_OUTPUT),
                "cuda_gpu_mem_size_sum": parse_nsys_csv_output("cuda_gpu_mem_size_sum", MEM_SIZE_OUTPUT),
                "nvtx_sum": parse_nsys_csv_output("nvtx_sum", NVTX_OUTPUT),
            },
        )
        markdown = render_markdown(artifacts, top=1)
        self.assertIn("cudaMalloc", markdown)
        self.assertNotIn("cudaLaunchKernel", markdown)
        self.assertNotIn("cudaFree", markdown)

    def test_render_markdown_limits_visible_sections(self) -> None:
        artifacts = _make_artifacts(
            reports={
                "cuda_api_sum": parse_nsys_csv_output("cuda_api_sum", API_OUTPUT),
                "cuda_gpu_kern_sum": parse_nsys_csv_output("cuda_gpu_kern_sum", KERNEL_SKIPPED),
                "cuda_gpu_mem_time_sum": parse_nsys_csv_output("cuda_gpu_mem_time_sum", MEM_TIME_OUTPUT),
                "cuda_gpu_mem_size_sum": parse_nsys_csv_output("cuda_gpu_mem_size_sum", MEM_SIZE_OUTPUT),
                "nvtx_sum": parse_nsys_csv_output("nvtx_sum", NVTX_OUTPUT),
            },
        )
        markdown = render_markdown(artifacts, report_sections=["api"])
        self.assertIn("## CUDA API Hotspots", markdown)
        self.assertNotIn("## GPU Kernels", markdown)
        self.assertNotIn("## Device Transfers", markdown)
        self.assertIn("Report sections: `api`", markdown)
        self.assertNotIn("No GPU kernel activity was captured", markdown)
        self.assertNotIn("No GPU kernels were captured.", markdown)

    def test_render_markdown_shows_policy_checks(self) -> None:
        artifacts = _make_artifacts(reports={})
        markdown = render_markdown(
            artifacts,
            policy_checks=[
                PolicyCheck("require-kernels", False, "No GPU kernels were captured."),
                PolicyCheck("max-api-time-pct:cudaMalloc", True, "`cudaMalloc` used 10.0% CUDA API time (limit 20.0%)."),
            ],
        )
        self.assertIn("## Policy Checks", markdown)
        self.assertIn("[FAIL] `require-kernels`", markdown)
        self.assertIn("[PASS] `max-api-time-pct:cudaMalloc`", markdown)


class WrapperTests(unittest.TestCase):
    def _run_cldperf(self, command_name: str) -> tuple[subprocess.CompletedProcess[str], str]:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "report.md"
            prefix = tmp / "sample"
            env = os.environ.copy()
            env["PATH"] = f"{TOOLS_DIR}:{env['PATH']}"

            result = subprocess.run(
                [
                    str(TOOLS_DIR / "cldperf"),
                    command_name,
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--prefix",
                    str(prefix),
                    "--",
                    "/bin/echo",
                    "hello",
                ],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            markdown = out_path.read_text() if out_path.exists() else ""
            return result, markdown

    def test_cldperf_gpu_routes_to_cuda_report(self) -> None:
        result, markdown = self._run_cldperf("gpu")
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("# CUDA Profile Report", markdown)
        self.assertIn("cudaMalloc", markdown)
        self.assertIn("WARNING: fake profiler warning", markdown)
        self.assertIn("[CUDA memcpy HtoD]", markdown)

    def test_cldperf_cuda_alias_routes_to_cuda_report(self) -> None:
        result, markdown = self._run_cldperf("cuda")
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("# CUDA Profile Report", markdown)
        self.assertIn("cudaMalloc", markdown)


class ProfilingTests(unittest.TestCase):
    def test_overall_status(self) -> None:
        artifacts = _make_artifacts(command=["/bin/echo", "hello"], reports={})
        self.assertEqual(overall_status(artifacts, []), "OK")
        self.assertEqual(overall_status(artifacts, [PolicyCheck("x", True, "good")]), "PASS")
        self.assertEqual(overall_status(artifacts, [PolicyCheck("x", False, "bad")]), "FAIL")
        self.assertEqual(
            overall_status(
                ProfileArtifacts(**{**artifacts.__dict__, "stats_exit_code": 9}),
                [],
            ),
            "ERROR",
        )
        self.assertEqual(
            overall_status(
                ProfileArtifacts(**{**artifacts.__dict__, "exit_code": 7}),
                [],
            ),
            "ERROR",
        )

    def test_profile_command_uses_single_stats_invocation(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = tmp / "fake-nsys-count"
            count_file = tmp / "calls.txt"
            fake_nsys.write_text(
                textwrap.dedent(
                    f"""\
                    #!/usr/bin/env python3
                    import pathlib
                    import sys

                    count_file = pathlib.Path({str(count_file)!r})
                    count = int(count_file.read_text()) if count_file.exists() else 0
                    count_file.write_text(str(count + 1))

                    argv = sys.argv[1:]
                    if argv[0] == "profile":
                        out_prefix = pathlib.Path(argv[argv.index("-o") + 1])
                        out_prefix.with_suffix(".nsys-rep").write_text("fake report")
                        raise SystemExit(0)
                    if argv[0] == "stats":
                        print("Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_api_sum.py]...")
                        print("Time (%),Total Time (ns),Num Calls,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Name")
                        print("90.0,9000,3,3000.0,3000.0,1000,5000,0.0,cudaMalloc")
                        print()
                        print("Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_kern_sum.py]...")
                        print("SKIPPED: no kernel data")
                        print()
                        print("Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_mem_time_sum.py]...")
                        print("SKIPPED: no mem time data")
                        print()
                        print("Processing [/tmp/sample.sqlite] with [/opt/reports/cuda_gpu_mem_size_sum.py]...")
                        print("SKIPPED: no mem size data")
                        print()
                        print("Processing [/tmp/sample.sqlite] with [/opt/reports/nvtx_sum.py]...")
                        print("Time (%),Total Time (ns),Instances,Avg (ns),Med (ns),Min (ns),Max (ns),StdDev (ns),Style,Range")
                        print("80.0,8000,8,1000.0,1000.0,900,1100,0.0,Push/Pop,forward_pass")
                        raise SystemExit(0)
                    raise SystemExit(1)
                    """
                )
            )
            fake_nsys.chmod(0o755)

            artifacts = profile_command(
                command=["/bin/echo", "hello"],
                prefix=tmp / "sample",
                nsys_path=str(fake_nsys),
            )

            self.assertEqual(artifacts.exit_code, 0)
            self.assertEqual(int(count_file.read_text()), 2)
            self.assertEqual(artifacts.reports["cuda_api_sum"].rows[0]["Name"], "cudaMalloc")
            self.assertIn("nvtx_sum", artifacts.reports)

    def test_evaluate_policy_checks(self) -> None:
        artifacts = _make_artifacts(
            command=["/bin/echo", "hello"],
            reports={
                "cuda_api_sum": parse_nsys_csv_output("cuda_api_sum", API_OUTPUT),
                "cuda_gpu_kern_sum": parse_nsys_csv_output("cuda_gpu_kern_sum", KERNEL_SKIPPED),
            },
        )
        checks = evaluate_policy_checks(
            artifacts,
            require_kernels=True,
            max_api_time_pct=[("cudaMalloc", 95.0), ("cudaLaunchKernel", 1.0)],
        )
        self.assertEqual(len(checks), 3)
        self.assertFalse(checks[0].ok)
        self.assertFalse(checks[1].ok)
        self.assertTrue(checks[2].ok)

    def test_evaluate_policy_checks_fail_when_api_summary_missing(self) -> None:
        artifacts = _make_artifacts(
            command=["/bin/echo", "hello"],
            reports={
                "cuda_api_sum": parse_nsys_csv_output(
                    "cuda_api_sum",
                    "SKIPPED: no CUDA API data available.\n",
                ),
            },
        )
        checks = evaluate_policy_checks(
            artifacts,
            max_api_time_pct=[("cudaMalloc", 10.0)],
        )
        self.assertEqual(len(checks), 1)
        self.assertFalse(checks[0].ok)
        self.assertIn("No CUDA API summary was available", checks[0].message)

    def test_evaluate_policy_checks_fail_when_api_missing_from_summary(self) -> None:
        artifacts = _make_artifacts(
            command=["/bin/echo", "hello"],
            reports={
                "cuda_api_sum": parse_nsys_csv_output("cuda_api_sum", API_OUTPUT),
            },
        )
        checks = evaluate_policy_checks(
            artifacts,
            max_api_time_pct=[("cudaMemcpyAsync", 10.0)],
        )
        self.assertEqual(len(checks), 1)
        self.assertFalse(checks[0].ok)
        self.assertIn("was not present", checks[0].message)

    def test_profile_command_keeps_sqlite_when_requested(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp, emit_sqlite=True)

            prefix = tmp / "nested" / "sample"
            artifacts = profile_command(
                command=["/bin/echo", "hello"],
                prefix=prefix,
                nsys_path=str(fake_nsys),
                keep_sqlite=True,
            )

            self.assertEqual(artifacts.exit_code, 0)
            self.assertIsNotNone(artifacts.sqlite_path)
            self.assertTrue(artifacts.sqlite_path.exists())
            self.assertEqual(artifacts.reports["cuda_api_sum"].rows[0]["Name"], "cudaMalloc")

    def test_profile_command_rejects_empty_report_selection(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            with self.assertRaises(ValueError) as ctx:
                profile_command(
                    command=["/bin/echo", "hello"],
                    prefix=tmp / "sample",
                    nsys_path=str(fake_nsys),
                    report_names=[],
                )

            self.assertIn("at least one Nsight report must be selected", str(ctx.exception))

    def test_profile_command_resolves_relative_prefix_under_cwd(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            workdir = tmp / "workdir"
            workdir.mkdir()
            fake_nsys = _write_fake_nsys(tmp)

            artifacts = profile_command(
                command=["/bin/echo", "hello"],
                prefix=Path("nested/sample"),
                nsys_path=str(fake_nsys),
                cwd=workdir,
            )

            self.assertEqual(artifacts.exit_code, 0)
            self.assertEqual(artifacts.prefix, workdir / "nested" / "sample")
            self.assertTrue((workdir / "nested" / "sample.nsys-rep").exists())
            self.assertEqual(artifacts.reports["cuda_api_sum"].rows[0]["Name"], "cudaMalloc")

    def test_profile_command_ignores_stale_report_on_failed_profile(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_profile_fail_nsys(tmp, name="fake-nsys-fail")

            prefix = tmp / "existing" / "sample"
            prefix.parent.mkdir(parents=True, exist_ok=True)
            stale_rep = prefix.with_suffix(".nsys-rep")
            stale_rep.write_text("stale report that must not be reused")

            artifacts = profile_command(
                command=["/bin/echo", "hello"],
                prefix=prefix,
                nsys_path=str(fake_nsys),
            )

            self.assertEqual(artifacts.exit_code, 1)
            self.assertFalse(stale_rep.exists())
            self.assertIn("ERROR: synthetic profile failure", artifacts.profile_stderr)
            for report in artifacts.reports.values():
                self.assertEqual(report.rows, [])
                self.assertIn("did not produce", report.skipped or "")

    def test_profile_command_propagates_stats_failure(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_stats_fail_nsys(tmp)

            artifacts = profile_command(
                command=["/bin/echo", "hello"],
                prefix=tmp / "sample",
                nsys_path=str(fake_nsys),
            )

            self.assertEqual(artifacts.exit_code, 0)
            self.assertEqual(artifacts.stats_exit_code, 9)
            self.assertEqual(overall_status(artifacts, []), "ERROR")
            self.assertIn("nsys stats failed", artifacts.reports["cuda_gpu_kern_sum"].skipped or "")

    def test_profile_command_reports_profile_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_sleepy_nsys(tmp, profile_sleep_s=0.2)

            with self.assertRaises(RuntimeError) as ctx:
                profile_command(
                    command=["/bin/echo", "hello"],
                    prefix=tmp / "sample",
                    nsys_path=str(fake_nsys),
                    timeout_s=0.01,
                )

            self.assertIn("timed out after", str(ctx.exception))
            self.assertIn("profile", str(ctx.exception))


class CliTests(unittest.TestCase):
    def _run_main(self, argv: list[str]) -> tuple[int, str]:
        stdout = StringIO()
        with redirect_stdout(stdout):
            exit_code = main(argv)
        return exit_code, stdout.getvalue()

    def test_default_prefix_path_tracks_markdown_output(self) -> None:
        out = Path("/tmp/reports/cuda.md")
        self.assertEqual(_default_prefix_path(out), Path("/tmp/reports/cuda"))

    def test_main_requires_command_separator(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            main(["--out", "/tmp/report.md"])
        self.assertIn("Usage: cuda-prof-report", str(ctx.exception))

    def test_main_rejects_latest_link_without_out(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            main(["--latest-link", "/tmp/latest.md", "--", "/bin/echo", "hello"])
        self.assertIn("--latest-link requires --out", str(ctx.exception))

    def test_main_returns_profile_exit_code_and_writes_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp, exit_code=7, emit_sqlite=True)

            out_path = tmp / "report.md"
            exit_code, stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--keep-sqlite",
                    "--prefix",
                    str(tmp / "sample"),
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            self.assertEqual(exit_code, 7)
            self.assertIn("[ERROR target_exit=7]", stdout)
            self.assertIn("next: Fix the target command or profiler failure first", stdout)
            self.assertIn(f"report: {tmp / 'sample.nsys-rep'}", stdout)
            self.assertIn(f"sqlite: {tmp / 'sample.sqlite'}", stdout)
            markdown = out_path.read_text()
            self.assertIn("Overall status: `ERROR`", markdown)
            self.assertIn("Exit code: `7`", markdown)
            self.assertIn("Stats exit code: `0`", markdown)
            self.assertIn("SQLite export:", markdown)

    def test_main_creates_output_parent_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "nested" / "reports" / "cuda.md"
            exit_code, _stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--prefix",
                    str(tmp / "sample"),
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertTrue(out_path.exists())
            self.assertIn("# CUDA Profile Report", out_path.read_text())

    def test_main_defaults_artifact_prefix_next_to_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "nested" / "reports" / "cuda.md"
            exit_code, _stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertTrue((tmp / "nested" / "reports" / "cuda.nsys-rep").exists())

    def test_main_updates_latest_links(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp, emit_sqlite=True)

            out_path = tmp / "reports" / "cuda.md"
            latest_link = tmp / "reports" / "latest.md"
            exit_code, stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--latest-link",
                    str(latest_link),
                    "--keep-sqlite",
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertTrue(latest_link.exists())
            self.assertEqual(latest_link.resolve(), out_path.resolve())
            self.assertEqual(
                latest_link.with_suffix(".nsys-rep").resolve(),
                (tmp / "reports" / "cuda.nsys-rep").resolve(),
            )
            self.assertEqual(
                latest_link.with_suffix(".sqlite").resolve(),
                (tmp / "reports" / "cuda.sqlite").resolve(),
            )
            self.assertIn(f"latest: {latest_link}", stdout)

    def test_main_removes_stale_latest_sqlite_link_when_sqlite_is_absent(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            latest_link = tmp / "reports" / "latest.md"

            fake_nsys_with_sqlite = _write_fake_nsys(tmp, emit_sqlite=True)
            first_out = tmp / "reports" / "first.md"
            first_exit, _first_stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys_with_sqlite),
                    "--out",
                    str(first_out),
                    "--latest-link",
                    str(latest_link),
                    "--keep-sqlite",
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            self.assertEqual(first_exit, 0)
            self.assertTrue(latest_link.with_suffix(".sqlite").exists())

            fake_nsys_without_sqlite = _write_fake_nsys(tmp, emit_sqlite=False)
            second_out = tmp / "reports" / "second.md"
            second_exit, _second_stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys_without_sqlite),
                    "--out",
                    str(second_out),
                    "--latest-link",
                    str(latest_link),
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            self.assertEqual(second_exit, 0)
            self.assertFalse(latest_link.with_suffix(".sqlite").exists())
            self.assertEqual(latest_link.resolve(), second_out.resolve())

    def test_main_removes_stale_latest_rep_link_when_profile_produces_no_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            latest_link = tmp / "reports" / "latest.md"

            fake_nsys_ok = _write_fake_nsys(tmp, emit_sqlite=True)
            first_out = tmp / "reports" / "first.md"
            with redirect_stdout(StringIO()):
                first_exit = main(
                    [
                        "--nsys",
                        str(fake_nsys_ok),
                        "--out",
                        str(first_out),
                        "--latest-link",
                        str(latest_link),
                        "--keep-sqlite",
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertEqual(first_exit, 0)
            self.assertTrue(latest_link.with_suffix(".nsys-rep").exists())

            fake_nsys_fail = _write_profile_fail_nsys(tmp, name="fake-nsys-fail-no-report")

            second_out = tmp / "reports" / "second.md"
            with redirect_stdout(StringIO()):
                second_exit = main(
                    [
                        "--nsys",
                        str(fake_nsys_fail),
                        "--out",
                        str(second_out),
                        "--latest-link",
                        str(latest_link),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertEqual(second_exit, 1)
            self.assertFalse(latest_link.with_suffix(".nsys-rep").exists())
            self.assertEqual(latest_link.resolve(), second_out.resolve())

    def test_main_updates_latest_links_with_relative_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)
            original_cwd = Path.cwd()
            os.chdir(tmp)
            try:
                stdout = StringIO()
                with redirect_stdout(stdout):
                    exit_code = main(
                        [
                            "--nsys",
                            str(fake_nsys),
                            "--out",
                            "reports/cuda.md",
                            "--latest-link",
                            "reports/latest.md",
                            "--",
                            "/bin/echo",
                            "hello",
                        ]
                    )
            finally:
                os.chdir(original_cwd)

            self.assertEqual(exit_code, 0)
            latest_link = tmp / "reports" / "latest.md"
            out_path = tmp / "reports" / "cuda.md"
            self.assertTrue(latest_link.exists())
            self.assertEqual(latest_link.resolve(), out_path.resolve())
            self.assertIn("latest: reports/latest.md", stdout.getvalue())

    def test_main_reports_latest_link_failures_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "reports" / "cuda.md"
            latest_link = tmp / "reports" / "latest.md"
            latest_link.mkdir(parents=True)

            with self.assertRaises(SystemExit) as ctx:
                main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--out",
                        str(out_path),
                        "--latest-link",
                        str(latest_link),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertIn("wrote report to", str(ctx.exception))
            self.assertIn("failed to update latest link", str(ctx.exception))
            self.assertTrue(out_path.exists())

    def test_main_rejects_non_positive_top(self) -> None:
        stderr = StringIO()
        with redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as ctx:
                main(["--top", "0", "--", "/bin/echo", "hello"])
        self.assertNotEqual(ctx.exception.code, 0)
        self.assertIn("value must be a positive integer", stderr.getvalue())

    def test_main_rejects_non_positive_timeout(self) -> None:
        stderr = StringIO()
        with redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as ctx:
                main(["--timeout", "0", "--", "/bin/echo", "hello"])
        self.assertNotEqual(ctx.exception.code, 0)
        self.assertIn("value must be a positive number", stderr.getvalue())

    def test_main_rejects_missing_explicit_nsys_path(self) -> None:
        with self.assertRaises(SystemExit) as ctx:
            main(["--nsys", "/definitely/missing/nsys", "--", "/bin/echo", "hello"])
        self.assertIn("nsys not found at", str(ctx.exception))

    def test_main_rejects_non_executable_explicit_nsys_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = tmp / "fake-nsys"
            fake_nsys.write_text("not executable")
            with self.assertRaises(SystemExit) as ctx:
                main(["--nsys", str(fake_nsys), "--", "/bin/echo", "hello"])
            self.assertIn("nsys is not executable", str(ctx.exception))

    def test_main_returns_policy_failure_exit_code(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "report.md"
            stdout = StringIO()
            with redirect_stdout(stdout):
                exit_code = main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--out",
                        str(out_path),
                        "--require-kernels",
                        "--max-api-time-pct",
                        "cudaMalloc=10",
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertEqual(exit_code, 2)
            self.assertIn("[FAIL require-kernels, max-api-time-pct:cudaMalloc]", stdout.getvalue())
            self.assertIn("require-kernels: No GPU kernels were captured.", stdout.getvalue())
            self.assertIn("max-api-time-pct:cudaMalloc: `cudaMalloc` used 90.0% CUDA API time", stdout.getvalue())
            self.assertIn("next: Reuse device buffers or add a persistent workspace", stdout.getvalue())
            markdown = out_path.read_text()
            self.assertIn("Overall status: `FAIL`", markdown)
            self.assertIn("## Policy Checks", markdown)
            self.assertIn("[FAIL] `require-kernels`", markdown)
            self.assertIn("[FAIL] `max-api-time-pct:cudaMalloc`", markdown)

    def test_main_reports_write_failures_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)
            out_path = tmp / "report-dir"
            out_path.mkdir()

            with self.assertRaises(SystemExit) as ctx:
                main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--out",
                        str(out_path),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertIn("failed to write report", str(ctx.exception))

    def test_main_reports_bad_cwd_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            with self.assertRaises(SystemExit) as ctx:
                main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--cwd",
                        str(tmp / "missing-cwd"),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertIn("failed to run", str(ctx.exception))

    def test_main_reports_ok_when_no_policies_are_provided(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "report.md"
            stdout = StringIO()
            with redirect_stdout(stdout):
                exit_code = main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--out",
                        str(out_path),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertEqual(exit_code, 0)
            self.assertIn("[OK]", stdout.getvalue())
            self.assertIn("next: Reuse device buffers or add a persistent workspace", stdout.getvalue())
            self.assertIn(f"report: {tmp / 'report.nsys-rep'}", stdout.getvalue())
            self.assertIn("Overall status: `OK`", out_path.read_text())

    def test_main_limits_rendered_sections_with_report_flag(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "report.md"
            exit_code, _stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--report",
                    "api",
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            markdown = out_path.read_text()
            self.assertEqual(exit_code, 0)
            self.assertIn("Report sections: `api`", markdown)
            self.assertIn("## CUDA API Hotspots", markdown)
            self.assertNotIn("## GPU Kernels", markdown)
            self.assertNotIn("## Device Transfers", markdown)
            self.assertNotIn("No GPU kernel activity was captured", markdown)
            self.assertNotIn("No GPU kernels were captured.", markdown)
            self.assertNotIn("No GPU kernels were captured.", _stdout)

    def test_main_resolves_relative_prefix_under_cwd(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            workdir = tmp / "workdir"
            workdir.mkdir()
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "report.md"
            stdout = StringIO()
            with redirect_stdout(stdout):
                exit_code = main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--cwd",
                        str(workdir),
                        "--prefix",
                        "nested/sample",
                        "--out",
                        str(out_path),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertEqual(exit_code, 0)
            self.assertTrue((workdir / "nested" / "sample.nsys-rep").exists())
            markdown = out_path.read_text()
            self.assertIn(f"Artifact prefix: `{workdir / 'nested' / 'sample'}`", markdown)

    def test_main_resolves_relative_out_and_latest_link_under_cwd(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            workdir = tmp / "workdir"
            workdir.mkdir()
            fake_nsys = _write_fake_nsys(tmp, emit_sqlite=True)

            stdout = StringIO()
            with redirect_stdout(stdout):
                exit_code = main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--cwd",
                        str(workdir),
                        "--out",
                        "reports/cuda.md",
                        "--latest-link",
                        "reports/latest.md",
                        "--keep-sqlite",
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            out_path = workdir / "reports" / "cuda.md"
            latest_link = workdir / "reports" / "latest.md"
            self.assertEqual(exit_code, 0)
            self.assertTrue(out_path.exists())
            self.assertEqual(latest_link.resolve(), out_path.resolve())
            self.assertEqual(
                latest_link.with_suffix(".nsys-rep").resolve(),
                (workdir / "reports" / "cuda.nsys-rep").resolve(),
            )
            self.assertEqual(
                latest_link.with_suffix(".sqlite").resolve(),
                (workdir / "reports" / "cuda.sqlite").resolve(),
            )
            self.assertIn(f"Wrote CUDA profile report to {out_path}", stdout.getvalue())
            self.assertIn(f"latest: {latest_link}", stdout.getvalue())

    def test_main_returns_stats_failure_exit_code(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_stats_fail_nsys(tmp)

            out_path = tmp / "report.md"
            stdout = StringIO()
            with redirect_stdout(stdout):
                exit_code = main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--out",
                        str(out_path),
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertEqual(exit_code, 9)
            self.assertIn("[ERROR stats_exit=9]", stdout.getvalue())
            markdown = out_path.read_text()
            self.assertIn("Overall status: `ERROR`", markdown)
            self.assertIn("Stats exit code: `9`", markdown)

    def test_main_reports_stats_timeout_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_sleepy_nsys(tmp, stats_sleep_s=0.2)

            with self.assertRaises(SystemExit) as ctx:
                main(
                    [
                        "--nsys",
                        str(fake_nsys),
                        "--out",
                        str(tmp / "report.md"),
                        "--stats-timeout",
                        "0.01",
                        "--",
                        "/bin/echo",
                        "hello",
                    ]
                )

            self.assertIn("timed out after", str(ctx.exception))
            self.assertIn("stats", str(ctx.exception))

    def test_main_auto_includes_api_section_for_api_policy(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_nsys = _write_fake_nsys(tmp)

            out_path = tmp / "report.md"
            exit_code, stdout = self._run_main(
                [
                    "--nsys",
                    str(fake_nsys),
                    "--out",
                    str(out_path),
                    "--report",
                    "kernels",
                    "--max-api-time-pct",
                    "cudaMalloc=10",
                    "--",
                    "/bin/echo",
                    "hello",
                ]
            )

            markdown = out_path.read_text()
            self.assertEqual(exit_code, 2)
            self.assertIn("Report sections: `kernels, api`", markdown)
            self.assertIn("## CUDA API Hotspots", markdown)
            self.assertIn("## GPU Kernels", markdown)
            self.assertNotIn("## Device Transfers", markdown)
            self.assertIn("[FAIL max-api-time-pct:cudaMalloc]", stdout)


if __name__ == "__main__":
    unittest.main()
