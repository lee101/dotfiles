import os, sys, json, random, subprocess, time, numpy as np, soundfile as sf, scipy.signal as ss, torch, torch.nn.functional as F
import train as T
from model import Enhancer, TARGET_RMS_DB
dev, SR = T.dev, T.SR
CR = "/vfast/data/voice-enhance/crisp"

def load_pairs():
    pairs = []
    for i in range(6):
        p = f"{CR}/out_long/long{i}.wav"
        if not os.path.exists(p): continue
        xin = sf.read(f"{CR}/in/long{i}.wav", dtype="float32")[0]
        r = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
        tout = np.frombuffer(r.stdout, np.float32).copy()
        for m in json.load(open(f"{CR}/in/long{i}.json")):
            o, L = m["out_off"], m["len"]
            x = xin[o:o + L]; pad = 4800
            t = tout[max(0, o - pad):o + L + pad]
            ex = ss.fftconvolve(abs(x), np.ones(48) / 48, "same")[::48]; et = ss.fftconvolve(abs(t), np.ones(48) / 48, "same")[::48]
            cc = ss.correlate(et - et.mean(), ex - ex.mean(), mode="full", method="fft")
            lag = (cc.argmax() - (len(ex) - 1)) * 48
            st = (o - max(0, o - pad)) + lag
            tt = tout[max(0, o - pad) + (st - (o - max(0, o - pad))):][:0]
            start = max(0, o + lag)
            tt = tout[start:start + L]
            if len(tt) < L: tt = np.pad(tt, (0, L - len(tt)))
            pairs.append((torch.from_numpy(x.copy()), torch.from_numpy(tt.copy())))
    return pairs

def crop_pair(pairs):
    for _ in range(8):
        x, t = random.choice(pairs)
        s = random.randint(0, len(x) - T.SEG)
        xs, ts = x[s:s + T.SEG], t[s:s + T.SEG]
        e = (xs.unfold(0, 960, 960) ** 2).mean(-1)
        if (e > e.max() * 1e-3).float().mean() > 0.6: break
    return xs, ts

def make_batch2(tts, noise, B, user, pairs, p_pair):
    cl = torch.zeros(B, T.SEG); tg = torch.zeros(B, T.SEG); is_pair = torch.zeros(B, dtype=torch.bool)
    for b in range(B):
        if random.random() < p_pair:
            xs, ts = crop_pair(pairs); cl[b] = xs; tg[b] = ts; is_pair[b] = True
        elif user and random.random() < 0.4:
            seg = T.crop_user(user); cl[b, :len(seg)] = seg
        else:
            x = random.choice(tts); s = random.randint(0, max(0, len(x) - T.SEG)); seg = x[s:s + T.SEG]; cl[b, :len(seg)] = seg
    cl, tg, is_pair = cl.to(dev), tg.to(dev), is_pair.to(dev)
    clp = T.polish(T.expand_target(cl))
    cl = torch.where(is_pair.unsqueeze(-1), cl, clp)
    cl = cl * (10 ** ((TARGET_RMS_DB - T.active_rms_db(cl)) / 20)).unsqueeze(-1)
    tg = tg * (10 ** ((TARGET_RMS_DB - T.active_rms_db(tg)) / 20)).unsqueeze(-1)
    tgt = torch.where(is_pair.unsqueeze(-1), tg, cl)
    return T.degrade(cl, tts, noise, B), cl, tgt, is_pair

_mel = {}
def mel_log(x):
    if "fb" not in _mel:
        n = 1024; f = np.fft.rfftfreq(n, 1 / SR); edges = np.geomspace(60, 16000, 65); fb = np.zeros((64, len(f)), np.float32)
        for i in range(64):
            lo, c, hi = edges[i], edges[i + 1] if i + 1 < 65 else edges[-1], edges[min(i + 2, 64)]
            fb[i] = np.clip(np.minimum((f - lo) / (c - lo + 1e-9), (hi - f) / (hi - c + 1e-9)), 0, None)
        _mel["fb"] = torch.from_numpy(fb).to(dev); _mel["w"] = torch.hann_window(n, device=dev)
    S = torch.stft(x, 1024, 256, window=_mel["w"], return_complex=True).abs() ** 2
    M = torch.einsum("mf,bft->bmt", _mel["fb"], S)
    return torch.log(F.avg_pool1d(M, 3, 1, padding=1) + 1e-6)

if __name__ == "__main__":
    steps = int(sys.argv[1]); B = 24; resume = sys.argv[2]; p_pair = float(os.environ.get("PPAIR", "0.5"))
    tts, noise, user = T.load_tts(), T.load_noise(), T.load_user(); pairs = load_pairs()
    print(len(pairs), "teacher pairs", sum(len(p[0]) for p in pairs) / SR / 60, "min", flush=True)
    m = Enhancer().to(dev); m.load_state_dict(torch.load(resume)); w2v = T.W2V()
    opt = torch.optim.AdamW(m.parameters(), 5e-4, weight_decay=1e-2)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, 5e-4, total_steps=steps, pct_start=0.05)
    t0 = time.time()
    for it in range(steps):
        x, cl, tg, ip = make_batch2(tts, noise, B, user, pairs, p_pair)
        y = m(x); loss = 0; lm = torch.zeros(()); ls = torch.zeros(())
        if ip.any():
            lm = (mel_log(y[ip]) - mel_log(tg[ip])).abs().mean(); lcp, _ = w2v.loss(y[ip], cl[ip])
            loss = loss + float(os.environ.get("MELW", "3")) * lm + 5 * lcp
        if (~ip).any():
            lw, _ = w2v.loss(y[~ip], tg[~ip]); ls = T.stft_loss(y[~ip], tg[~ip]) + 20 * (y[~ip] - tg[~ip]).abs().mean() + 5 * lw
            loss = loss + ls
        opt.zero_grad(); loss.backward(); torch.nn.utils.clip_grad_norm_(m.parameters(), 1.0); opt.step(); sched.step()
        if it % 100 == 0: print(it, round(float(loss), 3), "mel", round(float(lm), 3), "syn", round(float(ls), 3), round(time.time() - t0), flush=True)
        if it % 2000 == 1999: torch.save(m.state_dict(), os.environ.get("OUT", f"{T.DATA}/enh_D.pt"))
    torch.save(m.state_dict(), os.environ.get("OUT", f"{T.DATA}/enh_D.pt"))
