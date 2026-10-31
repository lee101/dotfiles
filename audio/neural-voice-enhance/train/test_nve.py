import sys, ctypes as C, numpy as np, torch, soundfile as sf, os, time
from model import Enhancer
ck, wav = sys.argv[1], sys.argv[2]; WINLAG = 191
os.system(f"/vfast/data/voice-enhance/venv/bin/python export.py {ck} /tmp/nve_test.bin")
os.environ["NVE_WEIGHTS"] = "/tmp/nve_test.bin"
class D(C.Structure):
    _fields_ = [("id", C.c_ulong), ("label", C.c_char_p), ("props", C.c_int), ("name", C.c_char_p), ("maker", C.c_char_p), ("cr", C.c_char_p), ("n", C.c_ulong), ("pd", C.c_void_p), ("pn", C.c_void_p), ("ph", C.c_void_p), ("impl", C.c_void_p),
                ("inst", C.CFUNCTYPE(C.c_void_p, C.c_void_p, C.c_ulong)), ("conn", C.CFUNCTYPE(None, C.c_void_p, C.c_ulong, C.c_void_p)), ("act", C.c_void_p),
                ("run", C.CFUNCTYPE(None, C.c_void_p, C.c_ulong)), ("ra", C.c_void_p), ("sg", C.c_void_p), ("deact", C.c_void_p), ("clean", C.c_void_p)]
lib = C.CDLL("./nve.so"); lib.ladspa_descriptor.restype = C.POINTER(D)
d = lib.ladspa_descriptor(0).contents
h = d.inst(None, 48000)
x, _ = sf.read(wav, dtype="float32"); x = x if x.ndim == 1 else x.mean(1)
bs = int(sys.argv[3]) if len(sys.argv) > 3 else 64
N = len(x) // bs * bs; x = np.ascontiguousarray(x[:N]); y = np.zeros(N, np.float32); byp = np.zeros(1, np.float32)
gn = np.array([float(os.environ.get('NVE_GAIN', '0'))], np.float32)
d.conn(h, 0, x.ctypes.data); d.conn(h, 1, y.ctypes.data); d.conn(h, 2, byp.ctypes.data); d.conn(h, 3, gn.ctypes.data)
t = time.time()
for i in range(0, N, bs):
    d.conn(h, 0, x[i:].ctypes.data); d.conn(h, 1, y[i:].ctypes.data); d.run(h, bs)
dt = time.time() - t
m = Enhancer(); m.load_state_dict(torch.load(ck, map_location="cpu")); m.eval()
with torch.no_grad(): r = m(torch.from_numpy(x)[None])[0].numpy()
yy = y[64:]; rr = r[:len(yy)]
print("maxerr", float(np.abs(yy - rr).max()), "ref rms", float(np.sqrt((rr ** 2).mean())), "cpu realtime x", round(N / 48000 / dt, 1))
sf.write(sys.argv[4] if len(sys.argv) > 4 else "/tmp/nve_out.wav", y, 48000)
best = max(range(-200, 200), key=lambda l: np.dot(y[max(0, l):N + min(0, l)][:N-400], r[max(0, -l):][:N-400]))
print("best lag", best)
for l in (0, 64, best):
    a = y[l:l + 40000]; b = r[:40000]; print(l, "err", float(np.abs(a - b).mean()), "sig", float(np.abs(b).mean()))
a = y[WINLAG + 4000:N - 200]; b = r[4000:N - 200 - WINLAG]; print("aligned snr dB", 10 * np.log10((b ** 2).sum() / ((a - b) ** 2).sum()))
