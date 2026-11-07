import sys, random, torch, numpy as np
import train as T
from model import Enhancer
m = Enhancer().to(T.dev); m.load_state_dict(torch.load(sys.argv[1])); m.eval()
random.seed(7); torch.manual_seed(7)
tts, noise = T.load_tts(True), T.load_noise()
mix, cl = T.make_batch(tts, noise, 12)
with torch.no_grad(): y = m(mix)
def sisdr(e, t):
    t = t - t.mean(); e = e - e.mean(); a = (e * t).sum() / (t * t).sum(); return 10 * torch.log10(((a * t) ** 2).sum() / ((e - a * t) ** 2).sum())
for i in range(12):
    print(i, 'in rms', round(float(T.rms_db(mix[i])), 1), 'tgt', round(float(T.rms_db(cl[i])), 1), 'out', round(float(T.rms_db(y[i])), 1), 'peak', round(float(y[i].abs().max()), 2), 'sisdr in', round(float(sisdr(mix[i], cl[i])), 1), 'out', round(float(sisdr(y[i], cl[i])), 1))
