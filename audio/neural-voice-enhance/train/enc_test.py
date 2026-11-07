import io, time, json, subprocess, statistics, sys, numpy as np, soundfile as sf, requests, os
from stt_tune import KEY, to16, norm, wer
REF = "The beige hue on the waters of the loch impressed all, including the French queen, before she heard that symphony again, just as young Arthur wanted."
x, _ = sf.read("/vfast/data/voice-enhance/eval/lee_beige.wav", dtype="float32"); x16 = to16(x)
wav = io.BytesIO(); sf.write(wav, x16, 16000, format="WAV", subtype="PCM_16"); open("/tmp/enc.wav", "wb").write(wav.getvalue())
def ff(args, out): subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", "/tmp/enc.wav"] + args + [out], check=True); return open(out, "rb").read()
variants = {
 "WAV16k": ("WAV", "audio.wav", "audio/wav", open("/tmp/enc.wav", "rb").read()),
 "WAV8k": ("WAV", "audio.wav", "audio/wav", ff(["-ar", "8000"], "/tmp/e8.wav")),
 "FLAC": ("FLAC", "audio.flac", "audio/flac", ff(["-c:a", "flac"], "/tmp/e.flac")),
 "OGG_OPUS24": ("OGG_OPUS", "audio.ogg", "audio/ogg", ff(["-c:a", "libopus", "-b:a", "24k", "-application", "voip"], "/tmp/e.ogg")),
}
for name, (enc, fn, mime, data) in variants.items():
    ts = []; txt = ""
    for k in range(4):
        t = time.time()
        try:
            r = requests.post("https://api.meta.ai/v1/asr/transcribe", headers={"Authorization": f"Bearer {KEY}"}, files={"request": (None, json.dumps({"model": "muse-voice-transcribe-1.0", "audioEncoding": enc, "language": "en"}), "application/json"), "audio": (fn, data, mime)}, timeout=60)
            ts.append(time.time() - t)
            txt = r.json().get("text", r.text[:80]) if r.ok else f"HTTP {r.status_code} {r.text[:90]}"
        except Exception as e: txt = str(e)[:80]
    print(f"{name:11s} {len(data)/1024:6.0f} KB  median {statistics.median(ts)*1000 if ts else -1:6.0f} ms | WER {wer(REF, txt):.2f} | {txt[:70]}")
