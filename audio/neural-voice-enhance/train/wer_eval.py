import sys, re, numpy as np, soundfile as sf, scipy.signal as ss, torch
from transformers import pipeline
REF = "the beige hue on the waters of the loch impressed all including the french queen before she heard that symphony again just as young arthur wanted"
def norm(s): return re.sub(r"[^a-z ]", "", s.lower().replace("-", " ")).split()
def wer(h):
    r, h = REF.split(), norm(h); d = np.zeros((len(r) + 1, len(h) + 1), int); d[:, 0] = range(len(r) + 1); d[0] = range(len(h) + 1)
    for i in range(1, len(r) + 1):
        for j in range(1, len(h) + 1): d[i, j] = min(d[i-1, j] + 1, d[i, j-1] + 1, d[i-1, j-1] + (r[i-1] != h[j-1]))
    return d[-1, -1] / len(r)
asr = pipeline("automatic-speech-recognition", model="openai/whisper-small.en", device=0, torch_dtype=torch.float16)
for p in sys.argv[1:]:
    x, sr = sf.read(p, dtype="float32"); x = x if x.ndim == 1 else x.mean(1)
    x = ss.resample_poly(x, 16000, sr).astype(np.float32)
    t = asr({"raw": x, "sampling_rate": 16000})["text"]
    print(f"{p.split('/')[-1]:28s} WER {wer(t):.2f} | {t.strip()}")
