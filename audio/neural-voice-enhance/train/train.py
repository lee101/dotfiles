import os, sys, glob, math, random, subprocess, time, numpy as np, soundfile as sf, torch, torch.nn.functional as F
from model import Enhancer, TARGET_RMS_DB
DATA = "/vfast/data/voice-enhance"; SR = 48000; SEG = SR * 3
dev = "cuda"
torch.backends.cuda.matmul.allow_tf32 = True

def held(p):
    return int(p.rsplit("_", 1)[1][:-4]) % 10 == 0

def load_tts(heldout=False):
    out = []
    for p in sorted(glob.glob(f"{DATA}/tts/*.mp3")):
        if held(p) != heldout: continue
        r = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
        x = np.frombuffer(r.stdout, np.float32)
        if len(x) > SR: out.append(torch.from_numpy(x.copy()))
    return out

def load_user():
    return [torch.from_numpy(sf.read(p, dtype="float32")[0]) for p in sorted(glob.glob(f"{DATA}/user/*.wav"))]

def crop_user(pool):
    for _ in range(8):
        x = random.choice(pool)
        s = random.randint(0, len(x) - SEG)
        seg = x[s:s + SEG]
        e = (seg.unfold(0, 960, 960) ** 2).mean(-1)
        if (e > e.max() * 1e-3).float().mean() > 0.6: break
    return seg

def load_noise():
    return [torch.from_numpy(sf.read(p, dtype="float32")[0]) for p in sorted(glob.glob(f"{DATA}/noise/*.wav"))]

def rms_db(x, dim=-1):
    return 10 * torch.log10((x ** 2).mean(dim) + 1e-12)

def active_rms_db(x):
    f = x.unfold(-1, 960, 960); e = (f ** 2).mean(-1)
    thr = e.max(-1, keepdim=True).values * 1e-3
    return 10 * torch.log10((e * (e > thr)).sum(-1) / (e > thr).sum(-1).clamp_min(1) + 1e-12)

def band_noise(n, f1, f2, tilt=0.0):
    X = torch.fft.rfft(torch.randn(n, device=dev))
    f = torch.fft.rfftfreq(n, 1 / SR).to(dev)
    X = X * ((f >= f1) & (f <= f2)).float() * (f.clamp_min(100) / 1000) ** (tilt / 6.0206)
    x = torch.fft.irfft(X, n)
    return x / (x.pow(2).mean().sqrt() + 1e-9)

def q(sec):
    return max(1, int(sec * SR) // 960) * 960

def gen_event():
    k = random.choice(["breath", "breath", "screech", "hiss", "pop"])
    if k == "breath":
        n = q(random.uniform(0.25, 0.8)); x = band_noise(n, random.uniform(300, 900), random.uniform(4000, 8000), -6); lvl = random.uniform(-28, -8)
        e = torch.hann_window(n, device=dev) ** random.uniform(0.7, 2)
    elif k == "screech":
        n = q(random.uniform(0.05, 0.4)); f0 = random.uniform(1500, 5500); f = torch.linspace(f0, f0 * random.uniform(0.75, 1.3), n, device=dev)
        ph = 2 * math.pi * torch.cumsum(f, 0) / SR; x = torch.sin(ph) + 0.4 * torch.sin(2 * ph)
        x = x * (1 + 0.3 * torch.sin(2 * math.pi * random.uniform(15, 80) * torch.arange(n, device=dev) / SR)); x = x / (x.pow(2).mean().sqrt() + 1e-9)
        lvl = random.uniform(-26, -4); e = torch.hann_window(n, device=dev) ** 0.5
    elif k == "hiss":
        n = q(random.uniform(0.08, 0.35)); x = band_noise(n, random.uniform(3500, 6000), random.uniform(9000, 16000)); lvl = random.uniform(-28, -6)
        e = torch.hann_window(n, device=dev) ** random.uniform(0.5, 1.5)
    else:
        n = q(random.uniform(0.02, 0.07)); x = band_noise(n, 20, random.uniform(80, 160)); lvl = random.uniform(-14, 2)
        e = torch.hann_window(n, device=dev) ** 0.5
    return x * e, lvl

EVBANK = []

def make_event():
    if not EVBANK:
        EVBANK.extend(gen_event() for _ in range(1500))
    x, lvl = random.choice(EVBANK)
    return (x if random.random() < 0.5 else x.flip(0)) * random.choice([-1.0, 1.0]), lvl

def events(sig, B, L):
    out = torch.zeros(B, L, device=dev)
    ref = 10 ** (active_rms_db(sig) / 20)
    for b in range(B):
        if random.random() < 0.8:
            for _ in range(random.randint(1, 7)):
                x, lvl = make_event()
                if len(x) >= L: continue
                s0 = random.randint(0, L - len(x))
                out[b, s0:s0 + len(x)] += x * ref[b] * 10 ** (lvl / 20)
    return out

def expand_target(x):
    ms = F.avg_pool1d((x ** 2).unsqueeze(1), 960, 480, padding=240).squeeze(1)
    db = 10 * torch.log10(ms + 1e-12)
    thr = (active_rms_db(x) - 30).unsqueeze(-1)
    g = (db - thr).clamp(max=0).clamp(min=-25)
    g = F.avg_pool1d(g.unsqueeze(1), 5, 1, padding=2).squeeze(1)
    gs = F.interpolate(g.unsqueeze(1), size=x.shape[-1], mode="linear", align_corners=False).squeeze(1)
    return x * 10 ** (gs / 20)

def polish(x):
    n = x.shape[-1]
    f = torch.fft.rfftfreq(n, 1 / SR).to(dev)
    g = 2.0 * torch.sigmoid((200 - f) / 60) + 1.5 * torch.exp(-0.5 * (torch.log2((f + 1) / 4000) / 0.7) ** 2) + 2.0 * torch.sigmoid((f - 7000) / 1500)
    return torch.fft.irfft(torch.fft.rfft(x) * 10 ** (g / 20), n)

def rand_fir(B, n=2048):
    f = torch.fft.rfftfreq(n, 1 / SR).to(dev)
    lo = torch.rand(B, 1, device=dev) * 18
    lof = 150 + torch.rand(B, 1, device=dev) * 350
    tilt = (torch.rand(B, 1, device=dev) - 0.6) * 14
    hic = 3000 + torch.rand(B, 1, device=dev) * 15000
    hislope = torch.rand(B, 1, device=dev) * 24
    g = lo * torch.sigmoid((lof - f) / 60) + tilt * torch.log2((f + 100) / 1000) / 3
    g = g - hislope * torch.relu(torch.log2((f + 1) / hic)).clamp(max=3)
    g = g + torch.randn(B, 1, 16, device=dev).repeat_interleave(f.numel() // 16 + 1, -1)[:, 0, :f.numel()] * 1.5
    mag = 10 ** (g / 20)
    h = torch.fft.irfft(mag, n=n)
    h = torch.roll(h, 64, -1)[:, :n] * torch.hann_window(n, device=dev).roll(0) ** 0.0
    return h

def fftconv(x, h):
    n = x.shape[-1] + h.shape[-1]
    return torch.fft.irfft(torch.fft.rfft(x, n) * torch.fft.rfft(h, n), n)[..., :x.shape[-1]]

def rand_rir(B, n=SR // 2):
    t = torch.arange(n, device=dev) / SR
    rt = 0.05 + torch.rand(B, 1, device=dev) ** 2 * 0.5
    h = torch.randn(B, n, device=dev) * torch.exp(-6.9 * t / rt)
    h[:, 0] = 1.0
    wet = torch.rand(B, 1, device=dev) * 0.35
    h[:, 1:] *= wet * 0.1
    dry = torch.rand(B, 1, device=dev) < 0.4
    h = torch.where(dry, F.pad(torch.ones(B, 1, device=dev), (0, n - 1)), h)
    return h

def colored_noise(B, L):
    X = torch.fft.rfft(torch.randn(B, L, device=dev))
    f = torch.fft.rfftfreq(L, 1 / SR).to(dev).clamp_min(20)
    a = torch.rand(B, 1, device=dev) * 2.0
    X = X / f ** (a / 2)
    low = torch.rand(B, 1, device=dev) * 12
    X = X * (1 + 10 ** (low / 20) * torch.sigmoid((300 - f) / 80))
    x = torch.fft.irfft(X, L)
    return x / x.std(-1, keepdim=True)

def clicks(B, L):
    x = torch.zeros(B, L, device=dev)
    for b in range(B):
        if random.random() < 0.4:
            for _ in range(random.randint(1, 8)):
                n = random.randint(100, 2400); s = random.randint(0, L - n)
                x[b, s:s + n] = torch.randn(n, device=dev) * torch.exp(-torch.arange(n, device=dev) / random.uniform(30, 500)) * random.uniform(0.3, 3)
    return x

def make_batch(tts, noise, B, user=None):
    cl = torch.empty(B, SEG)
    for b in range(B):
        if user and random.random() < 0.4:
            seg = crop_user(user)
        else:
            x = random.choice(tts)
            s = random.randint(0, max(0, len(x) - SEG)); seg = x[s:s + SEG]
        cl[b] = 0
        cl[b, :len(seg)] = seg
    cl = polish(expand_target(cl.to(dev)))
    cl = cl * (10 ** ((TARGET_RMS_DB - active_rms_db(cl)) / 20)).unsqueeze(-1)
    return degrade(cl, tts, noise, B), cl

def degrade(cl, tts, noise, B):
    sig = fftconv(cl, rand_rir(B))
    sig = fftconv(sig, rand_fir(B))
    lvl = -62 + torch.rand(B, 1, device=dev) * 52
    sig = sig * 10 ** ((lvl - active_rms_db(sig).unsqueeze(-1)) / 20)
    nz = torch.zeros(B, SEG, device=dev)
    for b in range(B):
        r = random.random()
        if r < 0.55 and noise:
            c = random.choice(noise)
            c = c.repeat(math.ceil(SEG / len(c)) + 1)[random.randint(0, len(c)):][:SEG] if len(c) < SEG else c[random.randint(0, len(c) - SEG):][:SEG]
            nz[b] = c.to(dev) / (c.std() + 1e-9)
        else:
            nz[b] = colored_noise(1, SEG)[0]
    nz = nz + clicks(B, SEG) * 0.5 * (torch.rand(B, 1, device=dev) < 0.5)
    snr = -2 + torch.rand(B, 1, device=dev) * 37
    snr = torch.where(torch.rand(B, 1, device=dev) < 0.08, torch.full_like(snr, 80.0), snr)
    nz = nz * 10 ** ((active_rms_db(sig).unsqueeze(-1) - snr) / 20) * (1 + 0 * nz)
    bab = torch.zeros_like(nz)
    for b in range(B):
        if random.random() < 0.15:
            x = random.choice(tts); s = random.randint(0, max(0, len(x) - SEG)); y = x[s:s + SEG].to(dev)
            bab[b, :len(y)] = y / (y.std() + 1e-9)
    bab = bab * 10 ** ((active_rms_db(sig).unsqueeze(-1) - (8 + torch.rand(B, 1, device=dev) * 15)) / 20)
    mix = sig + nz + bab + events(sig, B, SEG)
    hot = torch.rand(B, 1, device=dev) < 0.2
    mix = torch.where(hot, mix * 10 ** (torch.rand(B, 1, device=dev) * 14 / 20 + 0.3), mix)
    return mix.clamp(-1, 1)

class W2V:
    def __init__(self):
        from transformers import Wav2Vec2ForCTC
        self.m = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-base-960h").to(dev).eval().half()
        for p in self.m.parameters(): p.requires_grad_(False)
        k = torch.sinc(torch.arange(-31, 32, device=dev) / 3.0) * torch.hamming_window(63, periodic=False, device=dev)
        self.k = (k / k.sum()).view(1, 1, -1)
    def feats(self, x):
        x = F.conv1d(x.unsqueeze(1), self.k, stride=3, padding=31).squeeze(1)
        x = (x - x.mean(-1, keepdim=True)) / (x.std(-1, keepdim=True) + 1e-5)
        o = self.m(x.half(), output_hidden_states=True)
        return [o.hidden_states[i].float() for i in (4, 8, 12)], o.logits.float()
    def loss(self, y, t):
        with torch.no_grad(): ft, lt = self.feats(t)
        fy, ly = self.feats(y)
        kl = F.kl_div(F.log_softmax(ly, -1), F.softmax(lt, -1), reduction="none").sum(-1).mean()
        return sum((a - b).abs().mean() for a, b in zip(fy, ft)) / 3, kl

WINS = [(256, 64), (512, 128), (1024, 256), (2048, 512)]
def stft_loss(y, t):
    l = 0
    for n, h in WINS:
        w = torch.hann_window(n, device=dev)
        Y = torch.stft(y, n, h, window=w, return_complex=True).abs(); T = torch.stft(t, n, h, window=w, return_complex=True).abs()
        l = l + 4 * ((Y + 1e-4) ** 0.3 - (T + 1e-4) ** 0.3).abs().mean() + (Y - T).norm() / (T.norm() + 1e-6) + 0.2 * (torch.log(Y + 0.02) - torch.log(T + 0.02)).abs().mean()
    return l / len(WINS)

if __name__ == "__main__":
    steps = int(sys.argv[1]); B = 24; resume = sys.argv[2] if len(sys.argv) > 2 else None
    tts, noise, user = load_tts(), load_noise(), load_user()
    print(len(user), "user", len(tts), "tts", len(noise), "noise", sum(len(x) for x in tts) / SR / 60, "min", flush=True)
    m = Enhancer().to(dev)
    if resume: m.load_state_dict(torch.load(resume))
    w2v = W2V()
    print(sum(p.numel() for p in m.parameters()) / 1e3, "k params", flush=True)
    opt = torch.optim.AdamW(m.parameters(), 1e-3, weight_decay=1e-2)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, 1e-3, total_steps=steps, pct_start=0.05)
    t0 = time.time()
    for it in range(steps):
        x, t = make_batch(tts, noise, B, user)
        y = m(x)
        lw, kl = w2v.loss(y, t)
        loss = stft_loss(y, t) + 20 * (y - t).abs().mean() + 5 * lw + float(os.environ.get('KLW', '0.5')) * kl
        opt.zero_grad(); loss.backward(); torch.nn.utils.clip_grad_norm_(m.parameters(), 1.0); opt.step(); sched.step()
        if it % 100 == 0: print(it, round(loss.item(), 4), round(lw.item(), 3), round(kl.item(), 3), round(rms_db(y.detach()).mean().item(), 1), round(rms_db(t).mean().item(), 1), round(time.time() - t0), flush=True)
        if it % 2000 == 1999: torch.save(m.state_dict(), os.environ.get("OUT", f"{DATA}/enh.pt"))
    torch.save(m.state_dict(), os.environ.get("OUT", f"{DATA}/enh.pt"))
