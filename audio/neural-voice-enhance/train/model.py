import math, torch, torch.nn as nn, torch.nn.functional as F

TARGET_RMS_DB = -19.0


def mdct_basis(n):
    k = torch.arange(n).view(-1, 1).double()
    t = torch.arange(2 * n).view(1, -1).double()
    w = torch.sin(math.pi * (t + 0.5) / (2 * n))
    return (math.sqrt(2.0 / n) * w * torch.cos(math.pi / n * (t + 0.5 + n / 2) * (k + 0.5))).float()


class Enhancer(nn.Module):
    def __init__(self, n=96, hid=256, layers=2, env_frames=250):
        super().__init__()
        self.n, self.win = n, 2 * n
        self.enc = nn.Conv1d(1, n, 2 * n, n, bias=False)
        self.dec = nn.ConvTranspose1d(n, 1, 2 * n, n, bias=False)
        B = mdct_basis(n).unsqueeze(1)
        self.enc.weight.data.copy_(B)
        self.dec.weight.data.copy_(B)
        self.enc.weight.requires_grad_(False)
        self.dec.weight.requires_grad_(False)
        self.norm = nn.LayerNorm(n)
        self.inp = nn.Linear(n + 1, hid)
        self.gru = nn.GRU(hid, hid, layers, batch_first=True)
        self.mask = nn.Linear(hid, n)
        self.gain = nn.Linear(hid, 1)
        nn.init.zeros_(self.mask.weight); nn.init.zeros_(self.mask.bias)
        nn.init.zeros_(self.gain.weight); nn.init.zeros_(self.gain.bias)
        self.env_frames = env_frames
        self.floor = 0.0
        self.strength = 1.0
        self.aesthetic = 0.0
        self.register_buffer('tone', torch.zeros(n), persistent=False)

    def envelope(self, p):
        a = math.exp(-1.0 / self.env_frames)
        k = torch.tensor([(1 - a) * a ** j for j in range(self.env_frames)], device=p.device).flip(0).view(1, 1, -1)
        return F.conv1d(F.pad(p, (self.env_frames - 1, 0)), k)

    def forward(self, x):
        n = self.n
        L = x.shape[1]
        x = F.pad(x, (n, (-L) % n))
        p = F.avg_pool1d((x[:, n:] ** 2).unsqueeze(1), n, n)
        z = self.enc(x.unsqueeze(1))
        T = z.shape[-1]
        env = self.envelope(p[:, :, :T]).clamp_min(1e-9).sqrt()
        scale = 10 ** (TARGET_RMS_DB / 20) / env.clamp_min(10 ** (-75 / 20))
        zt = z.transpose(1, 2)
        sc = scale.transpose(1, 2)
        h = self.norm(torch.log10(zt.abs() * sc + 1e-4))
        lv = torch.log10(env.clamp_min(1e-6)).transpose(1, 2) / 3
        h = torch.relu(self.inp(torch.cat([h, lv], -1)))
        h, _ = self.gru(h)
        m = 2 * torch.sigmoid(self.mask(h))
        m = (1 + self.strength * (m - 1)).clamp_min(self.floor)
        g = torch.exp(self.gain(h).clamp(-3, 3))
        y = zt * m * 10 ** (self.aesthetic * self.tone / 20) * (g * sc) ** self.strength
        out = self.dec(y.transpose(1, 2)).squeeze(1)
        return out[:, n:n + L]
