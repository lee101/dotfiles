# Neural voice enhancement for OBS

This setup replaces OBS's RNNoise stage with DeepFilterNet3, exposes the result
as a normal 48 kHz microphone, and starts it automatically at login and before
OBS. Everything is installed in the current user's home directory.

## Install

From the dotfiles repository:

```bash
./audio/neural-voice-enhance/install.sh
```

The installer auto-detects the current physical microphone, downloads the
pinned DeepFilterNet Plus v1.0.2 LADSPA build, verifies its SHA-256 checksum,
and installs:

- `~/.ladspa/libdeep_filter_ladspa.so`
- `~/.local/bin/neural-voice-enhance`
- `~/.local/bin/obs` and `obs-neural`
- `~/.config/systemd/user/neural-voice-enhance.service`
- an `OBS Studio (Neural Voice)` application launcher

For a specific microphone or stronger filtering:

```bash
pactl list short sources
./audio/neural-voice-enhance/install.sh \
  --source alsa_input.example_device \
  --attenuation 35
```

The normal 24 dB preset is the recommended starting point. More suppression can
sound cleaner in steady noise but may make speech less natural.

## Use

The service makes `enhanced_voice`, shown as
`Enhanced_Voice_DeepFilterNet`, the default microphone. OBS profiles using
`Mic/Aux = Default` therefore pick it up automatically.

```bash
neural-voice-enhance status
neural-voice-enhance restart
neural-voice-enhance stop
obs
```

If OBS has an RNNoise filter from an older setup, disable it to avoid applying
two neural suppressors in series. The repository's `CleanAudio` profile ships
with that legacy filter disabled.

To bypass the wrapper, launch `/usr/bin/obs`. To use an OBS binary in another
location, set `VOICE_ENHANCE_OBS_BINARY`.

## Uninstall

```bash
./audio/neural-voice-enhance/install.sh --uninstall
```

Uninstalling stops and disables the service, restores the physical microphone,
removes only managed files, and restores a pre-existing `~/.local/bin/obs`
wrapper and desktop entry when they were backed up during installation.

## Compatibility

The current release supports x86-64 Linux with a running PulseAudio-compatible
server whose `pactl load-module` implementation provides `module-null-sink`,
`module-ladspa-sink`, `module-loopback`, and `module-remap-source`. Native
PulseAudio on Ubuntu 22.04 is tested. NVIDIA Broadcast's supported desktop
integration remains a Windows path; this Linux setup is CPU-optimized.

## NVE (own model, ~2.7 ms)

Frozen MDCT filterbank (perfect reconstruction, 4 ms) with a GRU-predicted per-bin gain mask in [0,2] plus automatic gain, so the output is the input signal re-weighted (no resynthesis, voice identity kept). Trained on TTS + your own recordings degraded with real room noise, mic EQ, reverb, soft levels. Plugin adds makeup gain, compressor, soft limiter.

- `train/gen_tts.py`, `train/noise_bank.py`: data; `train/train.py N`: train; `train/nve.c`: LADSPA engine (matches PyTorch to 70 dB)
- `./nve install [ckpt]`, `./nve start`, `./nve stop`: source `enhanced_voice_nve`, runs beside the DeepFilterNet source

Eval (`train/eval_model.py ckpt files...`, whisper-small.en): measured WER of enhanced vs raw is currently not better than raw on clean-ish input (user clip raw 0.04, enhanced 0.12), so dictator's stage is opt-in (`VOICETYPE_NVE=1`, weights at `~/.local/share/neural-voice-enhance/enh.bin`).
Zig engine: `voicetypezig/src/nve.zig` (`zig test src/nve.zig` with `NVE_TEST_*`), matches PyTorch to ~100 dB.

## STT tuning (dictator)

Measured with Muse (`train/stt_run.py`, 40 jargon sentences x voices x degraded mic, 3-5 seeds):
- Muse is robust to noise; enhancement does not help it. NVE with `VOICETYPE_NVE=1` uses mask floor 0.6 (`VOICETYPE_NVE_FLOOR`), which is neutral for Muse WER (0.271 vs 0.268). Calls use Floor 0 in `nve-voice.conf`.
- Vocabulary prompt (`VOICETYPE_STT_PROMPT`, default built from `voicetypezig/src/vocab.zig` terms): neutral on clean audio, +3 of 150 terms on degraded audio. Not a real gain.
- `vocab.zig` post-correction (phonetic aliases, joined words, fuzzy match, user file `~/.config/voicetype/vocabulary.txt` with `alias=>Canonical` lines) lifts term recall 333/450 to 354/450 in-sample (aliases were derived from these transcripts, so expect less on new speech). "network" for Netwrck is not corrected by default (real word); add `network=>Netwrck` if wanted.

## Latency and breath/screech (latest)

- Muse accepts only mono s16le WAV at 16/24 kHz (OGG/FLAC/8k rejected). Latency ~1.2-1.5 s up to 4 s of audio, then ~0.2 s per extra second. Speeding audio up (1.25x) doubles WER, so it is not used. `voicetypezig/src/chunked.zig` splits dictations over 10 s at clear pauses (>=240 ms) and transcribes the pieces in parallel (42 s clip: ~7.5 s -> ~2.6 s, WER 0.06 vs 0.03-0.06).
- Training now adds breath, screech, hiss and pop events to the input only, and gates sub-threshold noise in the targets. Model `enh_A.pt` (live): voicing preserved, whisper WER on the beige clip equals raw. The ASR-consistency (KL) variant destroys speech and is rejected.
- `train/breath_metric.py` gives a rough noisy-gap measure; `train/stt_run.py`, `eval_model.py`, `chunk_sim.py` are the evaluation harnesses.

## CrispVoice teacher and distillation

- `Francium-Tech/CrispVoice` is offline (ClearerVoice MossFormer2 + Resemble Enhance + DeepFilterNet blend + mastering). Installed in `/vfast/data/voice-enhance/crisp/repo` with a CUDA torch and a `--device cuda` patch (about 2x realtime on the 3090 Ti).
- As an output it hurts intelligibility (Whisper WER 0.38-0.46 vs 0.04 raw) and drifts identity (WavLM-sv cosine 0.97), but it makes much cleaner gaps and richer harmonics, so it is used only as a phase-free teacher: `train/train_distill.py` matches a smoothed log-mel envelope of its output on 63 minutes of your speech, while the synthetic task and wav2vec content losses keep the content honest.
- Result (mask-only student): noisy gap frames 0.035 -> 0.000-0.002, identity 0.977-0.992, WER unchanged. It cannot reproduce the teacher's harmonic richness (voiced fraction 0.15 vs 0.27-0.37).
- Voice-space analysis (`train/voice_space.py`, `tone_eval.py`): the "TTS voices" are really two voices (130 Hz and 200 Hz), and your mic has +6-8 dB around 2.6-3.3 kHz and -4 dB at 400-1100 Hz relative to them. `tone.json` is the tone curve used by the Aesthetic/Studio Tone control.
- Controls: plugin ports `Strength` and `Aesthetic`; dictator `nve_enabled`, `nve_strength`, `nve_tone` (Settings > Voice Cleanup sliders); `dictatorflow --calibrate` records vocabulary-covering sentences to `~/.local/share/voicetype/calibration`.
