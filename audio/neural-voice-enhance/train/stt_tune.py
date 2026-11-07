import os, sys, io, re, json, random, subprocess, concurrent.futures as cf, numpy as np, soundfile as sf, scipy.signal as ss, requests, torch
HERE = os.path.dirname(os.path.abspath(__file__))
D = "/vfast/data/voice-enhance/stt"; os.makedirs(D, exist_ok=True)
KEY = os.environ["META_API_KEY"].strip()
NK = os.environ.get("NETWRCK_KEY", "")
TERMS = ["Netwrck", "CuteDSL", "ManifoldGen", "OpenPaths", "OmniServe", "DictatorFlow", "Muse", "Appnz", "BinanceGo", "Mojo", "Zig", "Hermes", "CosyVoice", "Supertonic", "ComfyUI", "llama.cpp", "Parakeet", "DeepFilterNet", "PipeWire", "Claude Code", "vLLM", "SGLang", "RunPod", "ONNX", "Triton", "wav2vec", "Bitbank", "OpenRouter", "Gemma", "Qwen", "pgx", "uv", "bun"]
PROMPTS = {
    "none": "",
    "spell": "Preferred spellings: " + ", ".join(TERMS),
    "ctx": "The speaker is a software engineer who dictates code, commands and project notes. Names and terms they use: " + ", ".join(TERMS) + ".",
}
def norm(s): return re.sub(r"[^a-z0-9 ]", "", s.lower().replace("-", " ").replace(".", " ")).split()
def squash(s): return re.sub(r"[^a-z0-9]", "", s.lower())
def wer(ref, hyp):
    r, h = norm(ref), norm(hyp); d = np.zeros((len(r) + 1, len(h) + 1), int); d[:, 0] = range(len(r) + 1); d[0] = range(len(h) + 1)
    for i in range(1, len(r) + 1):
        for j in range(1, len(h) + 1): d[i, j] = min(d[i-1, j] + 1, d[i, j-1] + 1, d[i-1, j-1] + (r[i-1] != h[j-1]))
    return d[-1, -1] / max(1, len(r))
def terms_in(text): return [t for t in TERMS if squash(t) in squash(text) and re.search(r"\b" + re.escape(t.lower().split()[0]), text.lower()) is not None or squash(t) in squash(text)]
def present(t, text): return squash(t) in squash(text)
def muse(x16, prompt, tries=4):
    buf = io.BytesIO(); sf.write(buf, x16, 16000, format="WAV", subtype="PCM_16")
    req = {"model": "muse-voice-transcribe-1.0", "audioEncoding": "WAV", "language": "en"}
    if prompt: req["prompt"] = prompt
    for k in range(tries):
        try:
            r = requests.post("https://api.meta.ai/v1/asr/transcribe", headers={"Authorization": f"Bearer {KEY}"}, files={"request": (None, json.dumps(req), "application/json"), "audio": ("audio.wav", buf.getvalue(), "audio/wav")}, timeout=90)
            if r.ok:
                j = r.json(); return j.get("text") or j.get("transcript") or json.dumps(j)
            if r.status_code == 429: import time; time.sleep(2 + 3 * k)
        except requests.RequestException: pass
    return ""
def to16(x48): return ss.resample_poly(x48, 1, 3).astype(np.float32)
