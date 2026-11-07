import sys, glob, json
from stt_tune import *
import train as T
from model import Enhancer
import scipy.signal as ss
C = os.path.expanduser("~/.local/share/voicetype/calibration")
m = Enhancer().to(T.dev); m.load_state_dict(torch.load(sys.argv[1])); m.eval()
ids = sorted(os.path.basename(p)[:3] for p in glob.glob(C + "/*.wav"))
refs = {i: open(f"{C}/{i}.txt").read().strip() for i in ids}
x16 = {i: sf.read(f"{C}/{i}.wav", dtype="float32")[0] for i in ids}
def enh(x, fl):
    y = ss.resample_poly(x, 3, 1).astype(np.float32); m.floor = fl
    with torch.no_grad(): e = m(torch.from_numpy(y).to(T.dev)[None])[0].clamp(-1, 1).cpu().numpy()
    return to16(e)
conds = {"raw": lambda x: x, "enh0.6": lambda x: enh(x, 0.6), "enh0": lambda x: enh(x, 0.0)}
jobs = [(i, c, pk) for i in ids for c in conds for pk in ["none", "ctx"]]
def run(j):
    i, c, pk = j; return muse(conds[c](x16[i]), PROMPTS[pk])
with cf.ThreadPoolExecutor(6) as ex: outs = list(ex.map(run, jobs))
res = {json.dumps(j): t for j, t in zip(jobs, outs)}
json.dump(res, open("/vfast/data/voice-enhance/stt/calib_results.json", "w"), indent=1)
import collections
agg = collections.defaultdict(list)
for (i, c, pk), t in zip(jobs, outs): agg[(c, pk)].append(wer(refs[i], t))
for k in sorted(agg): print(k, f"{np.mean(agg[k]):.3f}")
for (i, c, pk), t in zip(jobs, outs):
    if c == "raw" and pk == "ctx" and wer(refs[i], t) > 0.1: print(i, "REF", refs[i], "\n   HYP", t)
