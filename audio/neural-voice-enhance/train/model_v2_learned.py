import torch, torch.nn as nn, torch.nn.functional as F

HOP = 64
TARGET_RMS_DB = -19.0


class Enhancer(nn.Module):
    def __init__(self, ch=192, hid=256, win=192, layers=2, env_frames=375):
        super().__init__()
        self.win, self.pre = win, win - HOP
        self.enc = nn.Conv1d(1, ch, win, HOP, bias=False)
        self.norm = nn.LayerNorm(ch)
        self.inp = nn.Linear(ch + 1, hid)
        self.gru = nn.GRU(hid, hid, layers, batch_first=True)
        self.mask = nn.Linear(hid, ch)
        self.gain = nn.Linear(hid, 1)
        self.dec = nn.ConvTranspose1d(ch, 1, win, HOP, bias=False)
        self.env_frames = env_frames

    def envelope(self, p):
        a = torch.exp(torch.tensor(-1.0 / self.env_frames))
        k = a ** torch.arange(self.env_frames, device=p.device)
        k = (k * (1 - a)).flip(0).view(1, 1, -1)
        return F.conv1d(F.pad(p, (self.env_frames - 1, 0)), k)

    def forward(self, x):
        L = x.shape[1]
        x = F.pad(x, (self.pre, (-L) % HOP))
        p = F.avg_pool1d((x[:, self.pre:] ** 2).unsqueeze(1), HOP, HOP)
        z = self.enc(x.unsqueeze(1))
        T = z.shape[-1]
        env = self.envelope(p[:, :, :T]).clamp_min(1e-9).sqrt()
        scale = 10 ** (TARGET_RMS_DB / 20) / env.clamp_min(10 ** (-75 / 20))
        h = self.norm(z.transpose(1, 2))
        lv = torch.log10(env.clamp_min(1e-6)).transpose(1, 2) / 3
        h = torch.relu(self.inp(torch.cat([h, lv], -1)))
        h, _ = self.gru(h)
        m = torch.sigmoid(self.mask(h))
        g = torch.exp(self.gain(h).clamp(-3, 3))
        y = z.transpose(1, 2) * m * g * scale.transpose(1, 2)
        out = self.dec(y.transpose(1, 2)).squeeze(1)
        return out[:, self.pre:self.pre + L]
