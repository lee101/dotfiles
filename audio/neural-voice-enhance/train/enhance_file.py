import sys, torch, soundfile as sf
from model import Enhancer
x, sr = sf.read(sys.argv[1], dtype="float32"); assert sr == 48000
if x.ndim > 1: x = x.mean(1)
m = Enhancer(); m.load_state_dict(torch.load(sys.argv[3] if len(sys.argv) > 3 else "/vfast/data/voice-enhance/enh.pt", map_location="cpu")); m.eval()
with torch.no_grad(): y = m(torch.from_numpy(x)[None])[0].clamp(-1, 1).numpy()
sf.write(sys.argv[2], y, sr)
