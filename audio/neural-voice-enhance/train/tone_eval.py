import json, glob, sys, numpy as np, soundfile as sf, scipy.signal as ss, torch, subprocess
from scipy.ndimage import gaussian_filter1d
from model import Enhancer
import breath_metric as bm
b = json.load(open("/vfast/data/voice-enhance/space/bands.json")); c = np.array(b["centers"]); tts = np.array(b["tts_mean"]); m2 = np.array(b["tts_M2"]); usr = np.array(b["user_pool"])
target = 0.5 * tts + 0.5 * m2
d = target - usr; d[c < 180] = 0; d[c > 7000] = 0
d = gaussian_filter1d(d, 1.0); d = np.clip(d, -6, 5) * 0.8
n = 96; bins = (np.arange(n) + 0.5) * 24000 / n
tone = np.interp(np.log(bins), np.log(c), d, left=0, right=0); tone[bins > 7000] = 0
json.dump({"tone_db": tone.round(2).tolist()}, open("/vfast/data/voice-enhance/space/tone.json", "w"))
print("tone dB at Hz:", {int(f): round(float(t), 1) for f, t in zip(bins[::6], tone[::6])})
dev = "cuda"; m = Enhancer().to(dev); m.load_state_dict(torch.load("/vfast/data/voice-enhance/enh_A.pt")); m.eval(); m.tone.copy_(torch.tensor(tone, dtype=torch.float32))
from transformers import AutoFeatureExtractor, WavLMForXVector
fe = AutoFeatureExtractor.from_pretrained("microsoft/wavlm-base-plus-sv"); xv = WavLMForXVector.from_pretrained("microsoft/wavlm-base-plus-sv").cuda().eval()
def emb(x):
    inp = fe(ss.resample_poly(x, 1, 3).astype(np.float32), sampling_rate=16000, return_tensors="pt")
    with torch.no_grad(): return torch.nn.functional.normalize(xv(**{k: v.cuda() for k, v in inp.items()}).embeddings[0], dim=-1).cpu().numpy()
E = "/vfast/data/voice-enhance/eval/"
for name in ["lee_new", "lee_beige"]:
    x, _ = sf.read(E + name + ".wav", dtype="float32"); raw = emb(x)
    print(f"-- {name}: strength aesthetic | identity-cos centroid(Hz) 2.6-3.3k-vs-mid(dB) 400-1k-vs-mid(dB) noisy_frac")
    for s in (0.5, 1.0):
        for a in (0.0, 0.5, 1.0):
            m.strength, m.aesthetic = s, a
            with torch.no_grad(): y = m(torch.from_numpy(x).to(dev)[None])[0].clamp(-1, 1).cpu().numpy()
            f, t, S = ss.stft(y, 48000, nperseg=2048); P = np.abs(S) ** 2; act = 10 * np.log10(P.sum(0) + 1e-12) > 10 * np.log10(P.sum(0) + 1e-12).max() - 30
            bd = lambda lo, hi: 10 * np.log10(P[(f >= lo) & (f < hi)][:, act].mean())
            mid = bd(300, 3000)
            sf.write(E + f"{name}_s{s}_a{a}.wav", y, 48000)
            r = bm.analyze(E + f"{name}_s{s}_a{a}.wav")
            print(f"   s={s} a={a} | id {float(emb(y) @ raw):.3f} cent {float((f[:, None] * P[:, act]).sum() / P[:, act].sum()):.0f} hi {bd(2600, 3400) - mid:+.1f} body {bd(400, 1000) - mid:+.1f} noisy {float(r['noisy_frac']):.3f}")
