import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("bunny_report", Path(__file__).with_name("bunny-report.py"))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ReportTests(unittest.TestCase):
    def extract(self, records):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "output.jsonl"
            path.write_text("\n".join(json.dumps(record) for record in records))
            return report.summarize(path)

    def test_di_usage_and_unverified_claim(self):
        result = self.extract([{"final_output": "tests pass", "exit_code": 0,
                                "usage": {"input_tokens": 10193, "output_tokens": 9}}])
        self.assertEqual(result["reported_usage"]["input_tokens"], 10193)
        self.assertFalse(result["agent_claims_verified"])

    def test_op_counts_only_message_end_not_duplicate_event_snapshots(self):
        message = {"role": "assistant", "content": [{"type": "text", "text": "summary"}],
                   "usage": {"input": 10, "output": 2, "cacheRead": 7, "cacheWrite": 1}}
        result = self.extract([{"type": "message_start", "message": message},
                               {"type": "message_end", "message": message},
                               {"type": "turn_end", "message": message},
                               {"type": "agent_end", "messages": [message]}])
        self.assertEqual(result["reported_usage"]["input_tokens"], 10)
        self.assertEqual(result["reported_usage"]["cache_read_tokens"], 7)
        self.assertEqual(result["usage_records"], 1)

    def test_missing_invalid_usage_is_unknown(self):
        result = self.extract([{"final_output": "", "exit_code": 1,
                                "usage": {"input_tokens": None, "output_tokens": True}}])
        self.assertIsNone(result["reported_usage"]["input_tokens"])
        self.assertIsNone(result["reported_usage"]["output_tokens"])

    def test_non_object_records_and_non_text_content(self):
        result = self.extract([[], {"type": "message_end", "message": []},
                               {"type": "message_end", "message": {"role": "assistant", "content": [None]}}])
        self.assertEqual(result["invalid_records"], 1)

    def test_oversized_and_truncated_records_do_not_hide_later_usage(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "output.jsonl"
            path.write_bytes(b"x" * (report.MAX_RECORD_BYTES + 1) + b"\n{bad\n" +
                             b'{"final_output":"ok","exit_code":0,"usage":{"output_tokens":3}}\n')
            result = report.summarize(path)
            self.assertEqual(result["oversized_records"], 1)
            self.assertEqual(result["invalid_records"], 1)
            self.assertEqual(result["reported_usage"]["output_tokens"], 3)

    def test_preview_is_bounded_and_terminal_safe(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "log"
            path.write_text("ignore\n" * 10000 + "\x1b[31mhello\x1b[0m\x00\n")
            result = report.preview(path)
            self.assertLessEqual(len(result.splitlines()), 100)
            self.assertLessEqual(len(result.encode()), report.MAX_PREVIEW_BYTES)
            self.assertTrue(result.endswith("hello"))
            self.assertNotIn("\x1b", result)

    def test_preview_invalid_utf8_stays_byte_bounded(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "log"
            path.write_bytes(b"\xff" * report.MAX_PREVIEW_BYTES)
            self.assertLessEqual(len(report.preview(path).encode()), report.MAX_PREVIEW_BYTES)


if __name__ == "__main__":
    unittest.main()
