#!/usr/bin/env python3
"""Summarize a Chrome DevTools performance trace. Token-efficient output.
Usage: trace_summary.py trace.json [--net N] [--tasks N] [--domain substr]"""
import json, sys, collections, argparse

p = argparse.ArgumentParser()
p.add_argument("trace")
p.add_argument("--net", type=int, default=25)
p.add_argument("--tasks", type=int, default=15)
p.add_argument("--domain", default=None)
a = p.parse_args()

raw = json.load(open(a.trace))
evs = raw["traceEvents"] if isinstance(raw, dict) else raw

nav_ts = None
markers = {}
for e in evs:
    n = e.get("name")
    if n == "navigationStart" and nav_ts is None:
        nav_ts = e["ts"]
    elif n in ("firstContentfulPaint", "largestContentfulPaint::Candidate",
               "MarkDOMContent", "MarkLoad", "firstPaint"):
        markers[n] = e["ts"]
if nav_ts is None:
    nav_ts = min(e["ts"] for e in evs if e.get("ts"))

def rel(ts): return (ts - nav_ts) / 1000.0

print("== markers (ms from nav) ==")
for k, v in sorted(markers.items(), key=lambda x: x[1]):
    print(f"{rel(v):9.0f}  {k}")

# network: pair send/receive/finish by requestId
reqs = {}
for e in evs:
    d = e.get("args", {}).get("data", {})
    rid = d.get("requestId")
    if not rid: continue
    n = e["name"]
    r = reqs.setdefault(rid, {})
    if n == "ResourceSendRequest":
        r.update(url=d.get("url", ""), prio=d.get("priority", ""), start=e["ts"],
                 rtype=d.get("resourceType", ""))
    elif n == "ResourceReceiveResponse":
        r.update(ttfb=e["ts"], mime=d.get("mimeType", ""), status=d.get("statusCode"),
                 cached=d.get("fromCache", False))
    elif n == "ResourceFinish":
        r.update(end=e["ts"], enc=d.get("encodedDataLength", 0))

rows = []
tot_bytes = 0
by_host = collections.Counter()
by_host_b = collections.Counter()
for r in reqs.values():
    if "url" not in r or "end" not in r or "start" not in r: continue
    if a.domain and a.domain not in r["url"]: continue
    dur = (r["end"] - r["start"]) / 1000.0
    ttfb = (r.get("ttfb", r["end"]) - r["start"]) / 1000.0
    host = r["url"].split("/")[2] if "://" in r["url"] else "?"
    by_host[host] += 1
    by_host_b[host] += r.get("enc", 0)
    tot_bytes += r.get("enc", 0)
    rows.append((dur, ttfb, r))

print(f"\n== network: {len(rows)} reqs, {tot_bytes/1024:.0f}KB encoded ==")
print("by host: " + ", ".join(f"{h}:{c}/{by_host_b[h]/1024:.0f}KB" for h, c in by_host.most_common(8)))
print(f"\ntop {a.net} by duration (start->end ms | ttfb | KB | url)")
for dur, ttfb, r in sorted(rows, reverse=True, key=lambda x: x[0])[:a.net]:
    u = r["url"]
    u = u if len(u) <= 110 else u[:70] + "..." + u[-37:]
    c = " CACHED" if r.get("cached") else ""
    print(f"{rel(r['start']):7.0f}->{rel(r['end']):7.0f} {dur:7.0f} {ttfb:6.0f} {r.get('enc',0)/1024:8.1f} {r.get('rtype','')[:6]:6}{c} {u}")

# main-thread long tasks
tasks = []
cat_self = collections.Counter()
for e in evs:
    if e.get("name") == "RunTask" and e.get("dur", 0) > 50000:
        tasks.append(e)
    n = e.get("name")
    if e.get("ph") == "X" and n in ("EvaluateScript", "FunctionCall", "v8.compile",
                                    "Layout", "UpdateLayoutTree", "Paint", "ParseHTML",
                                    "MinorGC", "MajorGC", "TimerFire", "EventDispatch",
                                    "XHRReadyStateChange", "ImageDecodeTask"):
        cat_self[n] += e.get("dur", 0)

print(f"\n== main thread activity totals (ms) ==")
for k, v in cat_self.most_common():
    print(f"{v/1000:9.0f}  {k}")

print(f"\n== long tasks >50ms: {len(tasks)} (top {a.tasks}) ==")
def task_attrib(t):
    t0, t1 = t["ts"], t["ts"] + t["dur"]
    best, name = 0, ""
    for e in evs:
        if e.get("ph") != "X" or not e.get("dur"): continue
        if e["ts"] >= t0 and e["ts"] < t1 and e.get("name") in ("EvaluateScript", "FunctionCall", "Layout", "ParseHTML", "v8.compile", "TimerFire", "EventDispatch"):
            if e["dur"] > best:
                best = e["dur"]
                d = e.get("args", {}).get("data", {})
                src = d.get("url") or d.get("functionName") or ""
                name = f"{e['name']} {src}"
    return name[:120]

for t in sorted(tasks, key=lambda x: -x["dur"])[:a.tasks]:
    print(f"{rel(t['ts']):8.0f}  {t['dur']/1000:6.0f}ms  {task_attrib(t)}")
