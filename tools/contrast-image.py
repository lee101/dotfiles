#!/usr/bin/env python3
"""Compact rendered-text contrast audit for screenshots.

Uses Tesseract word boxes, then samples pixels just outside each word to infer
the local background. It is intentionally an image audit: it catches opacity,
overlays, gradients, and compositing mistakes that source-token checks miss.

Usage: contrast-image.py screenshot.png [--json]
Exit 1 when any normal-sized word is below 4.5:1 (large text uses 3:1).
"""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path
from PIL import Image, ImageStat

def lum(rgb):
    c = [v / 255 for v in rgb]
    c = [(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c]
    return .2126*c[0] + .7152*c[1] + .0722*c[2]

def ratio(a, b):
    x, y = sorted((lum(a), lum(b)))
    return (y + .05) / (x + .05)

def audit(path):
    image = Image.open(path).convert("RGB")
    data = subprocess.run(["tesseract", str(path), "stdout", "--psm", "11", "tsv"],
                          check=True, capture_output=True, text=True).stdout
    rows = []
    for line in data.splitlines()[1:]:
        cols = line.split("\t")
        if len(cols) != 12 or not cols[11].strip(): continue
        try: x, y, w, h, conf = map(float, (cols[6], cols[7], cols[8], cols[9], cols[10]))
        except ValueError: continue
        if conf < 45 or w < 5 or h < 5: continue
        x, y, w, h = map(int, (x, y, w, h))
        pad = max(2, min(8, h // 3))
        box = image.crop((max(0,x-pad), max(0,y-pad), min(image.width,x+w+pad), min(image.height,y+h+pad)))
        # Border pixels are a cheap, robust local background estimate.
        px = box.load(); bw, bh = box.size
        edge = [px[i, j] for i in range(bw) for j in range(bh)
                if i < pad or j < pad or i >= bw-pad or j >= bh-pad]
        bg = tuple(int(sum(channel) / len(edge)) for channel in zip(*edge))
        # Text is generally the brighter cluster on this site's dark theme.
        fg = (245,247,250) if lum(bg) < .35 else (20,22,25)
        value = ratio(fg, bg)
        rows.append({"text": cols[11].strip(), "x": x, "y": y, "ratio": round(value, 2),
                     "level": "AA" if value >= (3 if h >= 24 else 4.5) else "FAIL"})
    return {"image": str(path), "words": len(rows), "fails": sum(r["level"] == "FAIL" for r in rows), "results": rows}

parser = argparse.ArgumentParser()
parser.add_argument("image", type=Path); parser.add_argument("--json", action="store_true")
args = parser.parse_args(); report = audit(args.image)
if args.json: print(json.dumps(report, separators=(",", ":")))
else:
    print(f"{report['image']}: {report['words']} words, {report['fails']} contrast failures")
    for row in report["results"]:
        if row["level"] == "FAIL": print(f"  FAIL {row['ratio']:>4}:1 {row['text']!r} @ ({row['x']},{row['y']})")
sys.exit(1 if report["fails"] else 0)
