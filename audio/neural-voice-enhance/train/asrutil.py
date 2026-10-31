import sys, re, random, numpy as np, soundfile as sf, scipy.signal as ss, torch
import train as T
from model import Enhancer
from transformers import pipeline
asr = pipeline("automatic-speech-recognition", model="openai/whisper-small.en", device=0, torch_dtype=torch.float16)
def words(s): return re.sub(r"[^a-z ]", "", s.lower().replace("-", " ")).split()
def wer(ref, hyp):
    r, h = words(ref), words(hyp)
    if not r: return 0.0
    d = np.zeros((len(r) + 1, len(h) + 1), int); d[:, 0] = range(len(r) + 1); d[0] = range(len(h) + 1)
    for i in range(1, len(r) + 1):
        for j in range(1, len(h) + 1): d[i, j] = min(d[i-1, j] + 1, d[i, j-1] + 1, d[i-1, j-1] + (r[i-1] != h[j-1]))
    return d[-1, -1] / len(r)
def tr(x48):
    x = ss.resample_poly(x48, 1, 3).astype(np.float32)
    return asr({"raw": x, "sampling_rate": 16000})["text"]
