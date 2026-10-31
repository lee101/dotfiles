import sys, time, numpy as np, soundfile as sf, concurrent.futures as cf
from stt_tune import to16, muse, wer
REF1 = "The beige hue on the waters of the loch impressed all, including the French queen, before she heard that symphony again, just as young Arthur wanted."
a = to16(sf.read('/vfast/data/voice-enhance/eval/lee_beige.wav', dtype='float32')[0]); b = to16(sf.read('/vfast/data/voice-enhance/eval/lee_new.wav', dtype='float32')[0])
x = np.concatenate([a, np.zeros(8000, np.float32), b, np.zeros(8000, np.float32), a]); ref = " ".join([REF1]*3)
sr=16000; fl=320
def split(x, thr, pf, mn, mx, nosplit):
    r = np.sqrt((x[:len(x)//fl*fl].reshape(-1, fl)**2).mean(1)); sp = r[r>r.max()*0.1].mean()
    pts=[]; pos=0
    while len(x)-pos > nosplit*sr:
        lo=int((pos+mn*sr)/fl); hi=min(int((pos+mx*sr)/fl), len(r)-pf)
        m,f=min((r[f:f+pf].mean(), f) for f in range(lo, hi))
        if m>sp*thr: break
        pts.append((f+pf//2)*fl); pos=pts[-1]
    return pts
for name,(thr,pf,mn,mx,ns) in {"cur":(0.25,8,2.5,6.5,7.5),"strict":(0.10,10,4,9,10),"stricter":(0.06,12,4,10,10)}.items():
    pts=split(x,thr,pf,mn,mx,ns); chunks=np.split(x,pts); res=[]
    for k in range(2):
        t=time.time()
        with cf.ThreadPoolExecutor(8) as ex: outs=list(ex.map(lambda c: muse(c,""),chunks))
        res.append((time.time()-t, wer(ref," ".join(outs))))
    print(name, [round(p/sr,1) for p in pts], [f"{t*1000:.0f}ms WER {w:.2f}" for t,w in res])
    if name=="cur": print(" | ".join(outs))
