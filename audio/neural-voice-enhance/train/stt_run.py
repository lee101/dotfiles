import sys, glob
from stt_tune import *
import train as T
from model import Enhancer
SEED = int(os.environ.get('SEED', '0')); random.seed(11 + SEED); torch.manual_seed(11 + SEED)
FLOORS = [float(v) for v in os.environ.get('FLOORS', '0').split(',')]
PK = os.environ.get('PK', 'none,spell,ctx').split(','); CONDS = os.environ.get('CONDS', 'clean,aug,enh0.0').split(',')
sents = [l.strip() for l in open(os.path.join(HERE, "jargon.txt")) if l.strip()]
voices = "M1 M2 M3 M4 M5 F1 F2 F3 F4 F5".split()
def tts(i, text, v):
    f = f"{D}/jar_{SEED}_{i:03d}.mp3"
    if not os.path.exists(f):
        for _ in range(3):
            r = requests.post("https://netwrck.com/api/v1/generate_speech", headers={"authorization": f"Bearer {NK}", "x-api-key": NK, "content-type": "application/json"}, json=dict(text=text, voice=v, speed=1, volume=1, language="en", steps=8, sample_rate=24000), timeout=120)
            if r.ok and len(r.content) > 2000: open(f, "wb").write(r.content); break
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", f, "-ac", "1", "-ar", "48000", "-f", "f32le", "-"], capture_output=True)
    return torch.from_numpy(np.frombuffer(r.stdout, np.float32).copy())
with cf.ThreadPoolExecutor(6) as ex: clips = list(ex.map(lambda a: tts(*a), [(i, s, voices[(i + 3 * SEED) % 10]) for i, s in enumerate(sents)]))
T.SEG = 48000 * 10
m = Enhancer().to(T.dev); m.load_state_dict(torch.load(sys.argv[1])); m.eval()
noise = T.load_noise(); items = []
for i, (s, c) in enumerate(zip(sents, clips)):
    mix, cl = T.make_batch([c], noise, 1)
    n = len(c)
    d = {"clean": c.numpy(), "aug": mix[0, :n].cpu().numpy()}
    for fl in FLOORS:
        m.floor = fl
        with torch.no_grad(): d[f"enh{fl}"] = m(mix)[0, :n].clamp(-1, 1).cpu().numpy()
    items.append((s, d))
real = []
for name, p in [("beige", "/vfast/data/voice-enhance/eval/lee_beige.wav"), ("lee_new", "/vfast/data/voice-enhance/eval/lee_new.wav")]:
    x, _ = sf.read(p, dtype="float32")
    m.floor = 0.0
    with torch.no_grad(): e = m(torch.from_numpy(x).to(T.dev)[None])[0].clamp(-1, 1).cpu().numpy()
    real.append((name, {"raw": x, "enh": e}))
REF = "The beige hue on the waters of the loch impressed all, including the French queen, before she heard that symphony again, just as young Arthur wanted."
jobs = [(("jar", i, cond, pk), to16(x)) for i, (s, d) in enumerate(items) for cond, x in d.items() if cond in CONDS for pk in PK] + [(("real", name, cond, pk), to16(x)) for name, d in real for cond, x in d.items() for pk in PK]
with cf.ThreadPoolExecutor(6) as ex: outs = list(ex.map(lambda j: muse(j[1], PROMPTS[j[0][3]]), jobs))
res = {}
for (k, _), t in zip(jobs, outs): res[json.dumps(k)] = t
json.dump(res, open(f"{D}/results_{os.path.basename(sys.argv[1])}_s{SEED}.json", "w"), indent=1)
import collections
agg = collections.defaultdict(lambda: [[], [], []])
for (k, _), t in zip(jobs, outs):
    if k[0] != "jar": continue
    s = items[k[1]][0]; need = [x for x in TERMS if present(x, s)]
    a = agg[(k[2], k[3])]; a[0].append(wer(s, t)); a[1].append(sum(present(x, t) for x in need)); a[2].append(len(need))
print("cond prompt  WER  term-recall")
for key in sorted(agg): a = agg[key]; print(f"{key[0]:6s} {key[1]:6s} {np.mean(a[0]):.3f}  {sum(a[1])}/{sum(a[2])}")
for (k, _), t in zip(jobs, outs):
    if k[0] == "real": print(k[1:], f"WER {wer(REF, t):.2f}", t[:120])
