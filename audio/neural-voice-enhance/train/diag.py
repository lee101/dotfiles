import torch, numpy as np, soundfile as sf, scipy.signal as ss
from model import Enhancer
import train as T
m=Enhancer().cuda(); m.load_state_dict(torch.load('/vfast/data/voice-enhance/enh.pt')); m.eval()
x,_=sf.read('/tmp/claude-1000/-home-lee-code-dotfiles/16e0e08e-8b22-4432-a134-e4aa0e029365/scratchpad/data/mic1.wav',dtype='float32'); x=torch.from_numpy(x).cuda()[None]
def r(y): return round(float(10*torch.log10((y**2).mean()+1e-12)),1)
with torch.no_grad():
    for g in [1,0.1,0.01]: print('gain',g,r(m(x*g)))
    for hp in [80,200,400]:
        b,a=ss.butter(4,hp,'high',fs=48000); xx=torch.from_numpy(ss.lfilter(b,a,x.cpu().numpy()).astype('float32')).cuda(); print('hp',hp,r(m(xx)))
    tts,noise=T.load_tts()[:40],T.load_noise()
    mix,cl=T.make_batch(tts,noise,8); y=m(mix); print('synth in',r(mix),'out',r(y),'tgt',r(cl))
    f,P=ss.welch(x.cpu().numpy()[0],48000,nperseg=2048); 
    f2,P2=ss.welch(mix.cpu().numpy()[0],48000,nperseg=2048)
    for a,b in [(0,100),(100,300),(300,1000),(1000,3000),(3000,8000),(8000,20000)]:
        s=lambda f,P:round(10*np.log10(P[(f>=a)&(f<b)].mean()+1e-15),1)
        print(a,b,'real',s(f,P),'synth',s(f2,P2))
