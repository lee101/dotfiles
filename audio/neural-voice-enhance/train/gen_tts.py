import os, re, sys, random, hashlib, concurrent.futures as cf, requests, glob
KEY = os.environ["NETWRCK_KEY"]
OUT = sys.argv[1]; N = int(sys.argv[2]); VOICES = sys.argv[3].split(","); OFF = int(sys.argv[4]) if len(sys.argv) > 4 else 0
URL = "https://netwrck.com/api/v1/generate_speech"
H = {"authorization": f"Bearer {KEY}", "x-api-key": KEY, "content-type": "application/json"}

def sentences():
    seen = set()
    for p in glob.glob("/home/lee/code/*/README*.md")[:3000] + glob.glob("/usr/share/doc/*/README*")[:500]:
        try: t = open(p, errors="ignore").read()
        except OSError: continue
        t = re.sub(r"```.*?```|`[^`]*`|\[([^\]]*)\]\([^)]*\)", r"\1", t, flags=re.S)
        for s in re.split(r"(?<=[.!?])\s+", re.sub(r"\s+", " ", t)):
            s = s.strip()
            if re.fullmatch(r"[A-Za-z][A-Za-z ,'\-]{40,160}[.!?]", s) and s not in seen:
                seen.add(s); yield s

def job(a):
    i, text, v = a
    f = f"{OUT}/{v}_{i:05d}.mp3"
    if os.path.exists(f): return 1
    for _ in range(3):
        try:
            r = requests.post(URL, headers=H, timeout=120, json=dict(text=text, voice=v, speed=random.choice([0.9, 1, 1.1]), volume=1, language="en", steps=8, sample_rate=24000))
            if r.ok and len(r.content) > 2000:
                open(f, "wb").write(r.content); open(f[:-4] + ".txt", "w").write(text); return 1
        except requests.RequestException: pass
    return 0

random.seed(0)
S = list(sentences()); random.shuffle(S); S = S[OFF:OFF + N]
fixed = "The beige hue on the waters of the loch impressed all, including the French queen, before she heard that symphony again, just as young Arthur wanted"
jobs = [(OFF + i + 1, s, VOICES[i % len(VOICES)]) for i, s in enumerate(S)]
with cf.ThreadPoolExecutor(6) as ex: ok = sum(ex.map(job, jobs))
print(ok, "/", len(jobs))
