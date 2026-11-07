import sys, numpy as np, soundfile as sf
def analyze(p):
    x, sr = sf.read(p, dtype="float32"); x = x if x.ndim == 1 else x.mean(1)
    n, h = int(.02 * sr), int(.01 * sr); m = (len(x) - n) // h
    fr = np.stack([x[i * h:i * h + n] for i in range(m)]) * np.hanning(n)
    e = 10 * np.log10((fr ** 2).mean(1) + 1e-12); e -= e.max()
    S = np.abs(np.fft.rfft(fr, 2 * n)) ** 2
    ac = np.fft.irfft(S)[:, :n]; ac = ac / (ac[:, :1] + 1e-12)
    lo, hi = int(sr / 400), int(sr / 70)
    voiced = ac[:, lo:hi].max(1) > 0.45
    f = np.fft.rfftfreq(2 * n, 1 / sr); band = (f > 1500) & (f < 9000)
    flat = np.exp(np.log(S[:, band] + 1e-14).mean(1)) / (S[:, band].mean(1) + 1e-14)
    noisy = (~voiced) & (e > -48) & (e < -14) & (flat > 0.25)
    runs = []; c = 0
    for v in noisy:
        if v: c += 1
        else:
            if c: runs.append(c)
            c = 0
    if c: runs.append(c)
    long = sum(r for r in runs if r >= 20) * 0.01
    gap = (~voiced) & (e < -14)
    return dict(dur=round(len(x) / sr, 1), voiced=round(voiced.mean(), 2), breath_s=round(long, 2), noisy_frac=round(noisy.mean(), 3), gap_floor_db=round(float(np.median(e[gap & (e < -30)])) if (gap & (e < -30)).any() else 0, 1), peak_to_rms_db=round(20 * np.log10(abs(x).max() / (np.sqrt((x ** 2).mean()) + 1e-9)), 1))
if __name__ == "__main__":
    for p in sys.argv[1:]: print(f"{p.split('/')[-1]:30s}", analyze(p))
