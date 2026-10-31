import sys, random, torch, numpy as np
import train as T
from model import Enhancer
from asrutil import tr, wer
m = Enhancer().to(T.dev); m.load_state_dict(torch.load(sys.argv[1])); m.eval()
random.seed(3); torch.manual_seed(3)
tts = T.load_tts(True)
for i in range(6):
    x = random.choice(tts); s = random.randint(0, max(0, len(x) - T.SEG)); seg = x[s:s + T.SEG].to(T.dev)
    seg = T.polish(seg[None]); seg = seg * 10 ** ((-19 - T.active_rms_db(seg)) / 20).unsqueeze(-1)
    for lvl in (-20, -45):
        inp = seg * 10 ** ((lvl + 19) / 20 * -1 * -1) if False else seg * 10 ** ((lvl - (-19)) / 20)
        with torch.no_grad(): y = m(inp)[0].clamp(-1, 1).cpu().numpy()
        ref = tr(seg[0].cpu().numpy())
        print(i, lvl, 'WER', round(wer(ref, tr(y)), 2), '|', ref[:60], '=>', tr(y)[:60])
