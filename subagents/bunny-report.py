#!/usr/bin/env python3
"""Preview saved agent output or extract reported usage without trusting claims."""

import argparse
import json
import os
from pathlib import Path
import re
from typing import Any


MAX_RECORD_BYTES = 16 * 1024 * 1024
MAX_PREVIEW_BYTES = 24 * 1024


def clean_text(value: str) -> str:
    value = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", value)
    return "".join(char for char in value if char in "\n\t" or char.isprintable())


def preview(path: Path) -> str:
    with path.open("rb") as handle:
        handle.seek(max(0, path.stat().st_size - MAX_PREVIEW_BYTES))
        content = handle.read(MAX_PREVIEW_BYTES)
    text = clean_text("\n".join(content.decode("utf-8", errors="replace").splitlines()[-100:]))
    return text.encode("utf-8")[-MAX_PREVIEW_BYTES:].decode("utf-8", errors="ignore")


def token_count(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else None


def summarize(path: Path) -> dict[str, Any]:
    totals = {"input_tokens": 0, "output_tokens": 0, "cache_read_tokens": 0, "cache_write_tokens": 0}
    known = {key: False for key in totals}
    counts = {"usage_records": 0, "invalid_records": 0, "oversized_records": 0}
    summary = ""
    exit_code = None
    model = None
    fx_report = False
    with path.open("rb") as handle:
        while True:
            line = handle.readline(MAX_RECORD_BYTES + 1)
            if not line:
                break
            if len(line) > MAX_RECORD_BYTES:
                counts["oversized_records"] += 1
                while not line.endswith(b"\n"):
                    line = handle.readline(MAX_RECORD_BYTES + 1)
                    if not line:
                        break
                continue
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except (ValueError, UnicodeDecodeError):
                counts["invalid_records"] += 1
                continue
            if not isinstance(record, dict):
                counts["invalid_records"] += 1
                continue
            if "final_output" in record and "exit_code" in record:
                fx_report = True
                exit_code = record.get("exit_code")
                model = record.get("model")
                summary = record.get("final_output", "")
                usage = record.get("usage")
                fields = {key: key for key in totals}
            elif record.get("type") == "message_end":
                message = record.get("message")
                if not isinstance(message, dict) or message.get("role") != "assistant":
                    continue
                usage = message.get("usage")
                model = message.get("model", model)
                content = message.get("content")
                if isinstance(content, list):
                    texts = [item["text"] for item in content if isinstance(item, dict)
                             and item.get("type") == "text" and isinstance(item.get("text"), str)]
                    if texts:
                        summary = "\n".join(texts)
                fields = {"input_tokens": "input", "output_tokens": "output",
                          "cache_read_tokens": "cacheRead", "cache_write_tokens": "cacheWrite"}
            else:
                continue
            if not isinstance(usage, dict):
                continue
            counts["usage_records"] += 1
            for name, field in fields.items():
                amount = token_count(usage.get(field))
                if amount is not None:
                    known[name] = True
                    totals[name] += amount
    return {"log": str(path), "format": "di" if fx_report else "op-or-unknown",
            "model": model, "agent_exit_code": exit_code,
            "reported_usage": {key: value if known[key] else None for key, value in totals.items()},
            **counts, "agent_claims_verified": False,
            "agent_summary": clean_text(summary)[-6000:] if isinstance(summary, str) else ""}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--preview-only", action="store_true", help="Show only the bounded last 100 lines first")
    mode.add_argument("--summary-only", action="store_true", help="Show only the unverified final summary and usage")
    parser.add_argument("--output", type=Path, help="Write a private JSON usage report after preview and review")
    args = parser.parse_args()
    if args.preview_only:
        print(preview(args.log))
        return
    report = summarize(args.log)
    if args.summary_only:
        print("Unverified agent summary:")
        print(report["agent_summary"][-4000:] or "No final summary found.")
        print(json.dumps({"usage": report["reported_usage"],
                          "invalid_records": report["invalid_records"],
                          "oversized_records": report["oversized_records"]}))
        return
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output:
        descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as handle:
            handle.write(encoded)
        print(json.dumps({"report": str(args.output), "usage": report["reported_usage"],
                          "invalid_records": report["invalid_records"],
                          "oversized_records": report["oversized_records"]}))
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
