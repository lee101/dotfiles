import torch
from model import Enhancer
import train as T
m=Enhancer().cuda(); m.load_state_dict(torch.load('/vfast/data/voice-enhance/enh.pt')); m.eval()
tts,noise=T.load_tts()[:60],T.load_noise()
mix,cl=T.make_batch(tts,noise,8)
with torch.no_grad():
    y=m(mix)
    f=lambda a:[round(float(10*torch.log10((a[i]**2).mean()+1e-12)),1) for i in range(8)]
    print('mix',f(mix)); print('tgt',f(cl)); print('out',f(y))
    L=lambda a:round(float(T.stft_loss(a,cl)+50*(a-cl).abs().mean()),3)
    print('loss model',L(y),'zero',L(torch.zeros_like(cl)),'mix',L(mix))
    print('lr state', [p.abs().mean().item() for p in list(m.parameters())[:2]])
