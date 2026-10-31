import subprocess, sys, glob, numpy as np, soundfile as sf, os
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
SR = 48000; F = SR // 50
n = 0
for p in sorted(glob.glob("/home/lee/*.mp4"), key=os.path.getmtime)[-60:]:
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-map", "0:a:0", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
    x = np.frombuffer(r.stdout, np.float32)
    if len(x) < SR * 3: continue
    m = len(x) // F; e = 10 * np.log10((x[:m * F].reshape(m, F) ** 2).mean(1) + 1e-12)
    lo = np.percentile(e, 10); quiet = e < lo + 4
    i = 0
    while i < m:
        if not quiet[i]: i += 1; continue
        j = i
        while j < m and quiet[j]: j += 1
        if j - i >= 40 and lo > -75:
            sf.write(f"{OUT}/{n:04d}.wav", x[i * F:j * F], SR, subtype="FLOAT"); n += 1
        i = j
print(n, "noise clips")
