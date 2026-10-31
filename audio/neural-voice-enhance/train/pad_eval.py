import glob
from stt_tune import *
C = os.path.expanduser("~/.local/share/voicetype/calibration")
ids = sorted(os.path.basename(p)[:3] for p in glob.glob(C + "/*.wav"))
refs = {i: open(f"{C}/{i}.txt").read().strip() for i in ids}
x16 = {i: sf.read(f"{C}/{i}.wav", dtype="float32")[0] for i in ids}
rng = np.random.default_rng(0)
def pad(x, s, noise):
    n = int(16000 * s); t = rng.standard_normal(n).astype(np.float32) * noise
    return np.concatenate([x, t])
conds = {"raw": lambda x: x, "pad0.5": lambda x: pad(x, .5, 0), "pad1.0": lambda x: pad(x, 1.0, 0), "pad1.0n": lambda x: pad(x, 1.0, 0.002), "lead+pad": lambda x: np.concatenate([np.zeros(8000, np.float32), pad(x, 1.0, 0)])}
jobs = [(i, c) for i in ids for c in conds]
with cf.ThreadPoolExecutor(6) as ex: outs = list(ex.map(lambda j: muse(conds[j[1]](x16[j[0]]), PROMPTS["ctx"]), jobs))
import collections
agg = collections.defaultdict(list)
for (i, c), t in zip(jobs, outs): agg[c].append(wer(refs[i], t))
for k in agg: print(k, f"{np.mean(agg[k]):.3f}")
