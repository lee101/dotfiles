import torch
from model import Enhancer
m = Enhancer()
x = torch.randn(1, 9600)
n = m.n
import torch.nn.functional as F
xp = F.pad(x, (n, (-9600) % n)); y = m.dec(m.enc(xp.unsqueeze(1)))[:, 0, n:n + 9600]
print("PR err", float((y - x)[:, 500:-500].abs().max()))
