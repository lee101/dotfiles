import os, sys, glob, json, random, subprocess, concurrent.futures as cf, numpy as np, soundfile as sf, scipy.signal as ss, requests, torch
D = "/vfast/data/voice-enhance/space"; os.makedirs(D, exist_ok=True)
NK = os.environ["NETWRCK_KEY"]; SR = 48000
sents = [l.strip() for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "jargon.txt")) if l.strip()][:12] + ["The beige hue on the waters of the loch impressed all, including the French queen, before she heard that symphony again, just as young Arthur wanted."]
voices = [f"M{i}" for i in range(0, 11)] + [f"F{i}" for i in range(0, 11)]
def tts(a):
    v, i, t = a; f = f"{D}/{v}_{i:02d}.mp3"
    if not os.path.exists(f):
        for _ in range(3):
            r = requests.post("https://netwrck.com/api/v1/generate_speech", headers={"authorization": f"Bearer {NK}", "x-api-key": NK, "content-type": "application/json"}, json=dict(text=t, voice=v, speed=1, volume=1, language="en", steps=8, sample_rate=24000), timeout=120)
            if r.ok and len(r.content) > 2000: open(f, "wb").write(r.content); break
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", f, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
    return np.frombuffer(r.stdout, np.float32).copy()
with cf.ThreadPoolExecutor(6) as ex: res = list(ex.map(tts, [(v, i, t) for v in voices for i, t in enumerate(sents)]))
clips = {v: res[k * len(sents):(k + 1) * len(sents)] for k, v in enumerate(voices)}
EDGES = np.geomspace(100, 16000, 25)
def feats(x):
    f, t, S = ss.stft(x, SR, nperseg=2048, noverlap=1536); P = np.abs(S) ** 2
    e = 10 * np.log10(P.sum(0) + 1e-12); act = e > e.max() - 30
    band = np.array([10 * np.log10(P[(f >= EDGES[i]) & (f < EDGES[i + 1])][:, act].mean() + 1e-14) for i in range(24)])
    ref = band[(EDGES[:-1] > 300) & (EDGES[:-1] < 3000)].mean(); band = band - ref
    cen = (f[:, None] * P[:, act]).sum() / P[:, act].sum()
    n, h = 960, 480; fr = np.lib.stride_tricks.sliding_window_view(x, n)[::h]; en = 10 * np.log10((fr ** 2).mean(1) + 1e-12)
    st = np.convolve(en, np.ones(40) / 40, "valid") if len(en) > 40 else en
    ac = np.fft.irfft(np.abs(np.fft.rfft(fr[en > en.max() - 25] * np.hanning(n), 2 * n)) ** 2)[:, :n]; ac /= ac[:, :1] + 1e-12
    lo, hi = int(SR / 400), int(SR / 70); pk = ac[:, lo:hi].max(1); lag = ac[:, lo:hi].argmax(1) + lo; vo = pk > 0.5
    pitch = SR / lag[vo] if vo.any() else np.array([0.0])
    return dict(band=band, centroid=float(cen), crest=float(20 * np.log10(abs(x).max() / np.sqrt((x ** 2).mean() + 1e-12))), lra=float(np.percentile(st, 95) - np.percentile(st, 10)), pitch_med=float(np.median(pitch)), pitch_iqr=float(np.subtract(*np.percentile(pitch, [75, 25]))), hnr=float(np.median(pk[vo])) if vo.any() else 0.0)
from transformers import AutoFeatureExtractor, WavLMForXVector
fe = AutoFeatureExtractor.from_pretrained("microsoft/wavlm-base-plus-sv"); xv = WavLMForXVector.from_pretrained("microsoft/wavlm-base-plus-sv").cuda().eval()
def emb(x):
    x16 = ss.resample_poly(x, 1, 3).astype(np.float32)
    inp = fe(x16, sampling_rate=16000, return_tensors="pt", padding=True)
    with torch.no_grad(): e = xv(**{k: v.cuda() for k, v in inp.items()}).embeddings[0]
    return torch.nn.functional.normalize(e, dim=-1).cpu().numpy()
E_ = "/vfast/data/voice-enhance/eval/"
user_files = {n: sf.read(E_ + n + ".wav", dtype="float32")[0] for n in ["lee_new", "lee_beige", "lee_new_A", "lee_beige_A", "lee_new_v2", "lee_new_B", "mic1"]}
random.seed(0); pool = [sf.read(p, dtype="float32")[0] for p in sorted(glob.glob("/vfast/data/voice-enhance/user/*.wav"))]
user_segs = []
for k in range(40):
    x = random.choice(pool); s = random.randint(0, len(x) - SR * 10); user_segs.append(x[s:s + SR * 10])
out = {"tts": {}, "user": {}}
for v in voices: out["tts"][v] = [feats(x) for x in clips[v]]
for n, x in user_files.items(): out["user"][n] = feats(x)
out["user_pool"] = [feats(x) for x in user_segs]
embs = {v: np.stack([emb(x) for x in clips[v][:6]]) for v in voices}
uemb = {n: emb(x) for n, x in user_files.items()}
poolemb = np.stack([emb(x) for x in user_segs[:20]])
vc = {v: embs[v].mean(0) / np.linalg.norm(embs[v].mean(0)) for v in voices}
print("== distinct TTS voices (cosine between voice centroids >0.97 => alias)")
names = list(vc); M = np.stack([vc[v] for v in names]); C = M @ M.T
for i, a in enumerate(names):
    al = [names[j] for j in range(len(names)) if j != i and C[i, j] > 0.97]
    print(a, "within-voice sim", round(float((embs[a] @ vc[a]).mean()), 3), "aliases:", al)
print("== identity (cosine to user raw lee_new)")
pm = poolemb.mean(0); pm /= np.linalg.norm(pm)
for n, e in uemb.items(): print(f"{n:12s} vs lee_new {float(e @ uemb['lee_new']):.3f}  vs user-pool {float(e @ pm):.3f}  vs nearest TTS {max(float(e @ vc[v]) for v in voices):.3f} ({max(voices, key=lambda v: float(e @ vc[v]))})")
print("== feature stats (TTS voices mean +- std | user pool | lee_new | lee_new_A)")
def agg(L, k): a = np.array([d[k] for d in L]); return a.mean(), a.std()
allt = [d for v in voices for d in out["tts"][v]]
for k in ["centroid", "crest", "lra", "pitch_med", "pitch_iqr", "hnr"]:
    print(f"{k:10s} tts {agg(allt,k)[0]:8.2f}+-{agg(allt,k)[1]:6.2f} | pool {agg(out['user_pool'],k)[0]:8.2f}+-{agg(out['user_pool'],k)[1]:6.2f} | new {out['user']['lee_new'][k]:8.2f} | A {out['user']['lee_new_A'][k]:8.2f} | v2 {out['user']['lee_new_v2'][k]:8.2f}")
tb = np.mean([d["band"] for d in allt], 0); ub = np.mean([d["band"] for d in out["user_pool"]], 0)
m2 = np.mean([d["band"] for d in out["tts"]["M2"]], 0); ab = out["user"]["lee_new_A"]["band"]
cent = np.sqrt(EDGES[:-1] * EDGES[1:])
print("== band (Hz): tts-mean | tts-M2 | user-pool | lee_new_A | tone(tts-mean minus user-pool)")
for i in range(24): print(f"{cent[i]:7.0f} {tb[i]:6.1f} {m2[i]:6.1f} {ub[i]:6.1f} {ab[i]:6.1f} {tb[i]-ub[i]:6.1f}")
json.dump(dict(centers=cent.tolist(), tts_mean=tb.tolist(), tts_M2=m2.tolist(), user_pool=ub.tolist(), user_A=ab.tolist()), open(D + "/bands.json", "w"))
