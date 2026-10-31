import io, time, json, statistics, glob, subprocess, concurrent.futures as cf, numpy as np, soundfile as sf, requests
from stt_tune import KEY, to16, wer, muse
x, _ = sf.read("/vfast/data/voice-enhance/eval/lee_beige.wav", dtype="float32"); x16 = to16(x)
def call(a):
    buf = io.BytesIO(); sf.write(buf, a, 16000, format="WAV", subtype="PCM_16"); t = time.time()
    r = requests.post("https://api.meta.ai/v1/asr/transcribe", headers={"Authorization": f"Bearer {KEY}"}, files={"request": (None, json.dumps({"model": "muse-voice-transcribe-1.0", "audioEncoding": "WAV", "language": "en"}), "application/json"), "audio": ("a.wav", buf.getvalue(), "audio/wav")}, timeout=60)
    return time.time() - t
def tempo(a, f):
    sf.write("/tmp/t_in.wav", a, 16000)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", "/tmp/t_in.wav", "-filter:a", f"atempo={f}", "-ar", "16000", "/tmp/t_out.wav"], check=True)
    return sf.read("/tmp/t_out.wav", dtype="float32")[0]
sents = [l.strip() for l in open("jargon.txt") if l.strip()]
import glob
files = sorted(glob.glob("/vfast/data/voice-enhance/stt/jar_0[0-9][0-9].mp3"))[:40]
clips = []
for f in files:
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", f, "-ac", "1", "-ar", "16000", "-f", "f32le", "-"], capture_output=True); clips.append(np.frombuffer(r.stdout, np.float32).copy())
print("tempo -> WER on clean jargon TTS")
for f in (1.0, 1.25, 1.5, 1.75):
    with cf.ThreadPoolExecutor(6) as ex: outs = list(ex.map(lambda c: muse(tempo(c, f) if f != 1.0 else c, ""), clips))
    print(f, round(np.mean([wer(s, t) for s, t in zip(sents, outs)]), 3))
