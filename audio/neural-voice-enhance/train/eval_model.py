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
m = Enhancer().to(T.dev); m.load_state_dict(torch.load(sys.argv[1])); m.eval()
random.seed(7); torch.manual_seed(7)
tts, noise = T.load_tts(True), T.load_noise()
mix, cl = T.make_batch(tts, noise, 40)
with torch.no_grad(): y = m(mix)
a = [[], [], []]
for i in range(40):
    ref = tr(cl[i].cpu().numpy()); a[0].append(wer(ref, tr(mix[i].cpu().numpy()))); a[1].append(wer(ref, tr(y[i].clamp(-1, 1).cpu().numpy())))
print(f"synthetic held-out ({len(tts)} utts): WER vs clean-ASR  noisy {np.mean(a[0]):.3f}  enhanced {np.mean(a[1]):.3f}")
REF = "the beige hue on the waters of the loch impressed all including the french queen before she heard that symphony again just as young arthur wanted"
for p in sys.argv[2:]:
    x, sr = sf.read(p, dtype="float32"); x = x if x.ndim == 1 else x.mean(1)
    with torch.no_grad(): e = m(torch.from_numpy(x).to(T.dev)[None])[0].clamp(-1, 1).cpu().numpy()
    sf.write(p.replace(".wav", "_v2.wav"), e, sr)
    print(f"{p.split('/')[-1]:20s} raw {wer(REF, tr(x)):.2f}  enhanced {wer(REF, tr(e)):.2f} | {tr(e).strip()}")
