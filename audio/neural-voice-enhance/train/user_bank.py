import subprocess, glob, os, sys, numpy as np, soundfile as sf
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
SR = 48000; F = SR // 50; n = 0; kept = []
files = sorted(glob.glob("/home/lee/*.mp4"), key=os.path.getmtime)[-80:] + ["/vfast/data/code/videos/latest-lee-talking.mp3"]
for p in files:
    for t in range(4):
        r = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-map", f"0:a:{t}", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
        x = np.frombuffer(r.stdout, np.float32)
        if len(x) < SR * 4: continue
        m = len(x) // F; e = 10 * np.log10((x[:m * F].reshape(m, F) ** 2).mean(1) + 1e-12)
        s = np.sort(e); fl = s[:max(1, m // 10)].mean(); top = s[-m // 5:].mean()
        act = (e > fl + 20).mean()
        if top - fl >= 38 and act > 0.25 and top > -45:
            sf.write(f"{OUT}/{n:04d}.wav", x, SR, subtype="FLOAT"); kept.append((os.path.basename(p), t, round(len(x) / SR, 1), round(top - fl), round(act, 2))); n += 1
for k in kept: print(k)
print(n, "user clips", sum(k[2] for k in kept), "s")
