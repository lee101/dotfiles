# OBS CleanAudio configuration

This repository includes an OBS profile and scene collection plus an optional
DeepFilterNet3 microphone installer. Together they provide a clean 48 kHz voice
chain without applying two neural suppressors in series.

## Recommended: DeepFilterNet microphone

Install the portable user service and OBS launcher:

```bash
./audio/neural-voice-enhance/install.sh
```

The installer detects the current physical microphone, downloads and verifies
the pinned DeepFilterNet Plus LADSPA release, and creates the normal input
`Enhanced_Voice_DeepFilterNet`. It becomes the default microphone at login and
whenever `obs` or the **OBS Studio (Neural Voice)** launcher starts.

The `CleanAudio` profile uses `Mic/Aux = Default`, so no machine-specific device
identifier is committed. Its legacy RNNoise filter remains present as a quick
fallback but is disabled by default.

Useful commands:

```bash
neural-voice-enhance status
neural-voice-enhance restart
neural-voice-enhance stop
```

See [the neural voice README](../audio/neural-voice-enhance/README.md) for
suppression tuning and uninstall instructions.

## What the OBS profile provides

- Profile `CleanAudio` with 48 kHz stereo output and neutral video defaults.
- Scene collection `CleanAudio` with one lightweight `Mic Monitor` scene.
- Global `Mic/Aux` set to the default system microphone.
- A disabled RNNoise filter that can be enabled if DeepFilterNet is unavailable.

## Linking the OBS configuration

Run `python linkdotfiles.py` (or your normal dotfile deployment) so the files in
`.config/obs-studio` are linked beneath `~/.config/obs-studio`. If OBS is already
open, switch to **Profile → CleanAudio** and **Scene Collection → CleanAudio**.

## Verification

1. Run `neural-voice-enhance status`; it should report `active` and
   `default-source: enhanced_voice`.
2. In OBS, leave **Settings → Audio → Mic/Auxiliary Audio** on **Default**, or
   explicitly select **Enhanced_Voice_DeepFilterNet**.
3. Confirm **Mic/Aux → Filters → RNNoise Suppression** is disabled.
4. Record a short clip with speech, keyboard noise, and silence. Increase from
   the default 24 dB attenuation only if the background remains distracting.

For a lightweight headless OBS configuration check:

```bash
xvfb-run -a timeout 5 /usr/bin/obs \
  --disable-shutdown-check --collection CleanAudio --profile CleanAudio \
  --minimize-to-tray --multi
```

## Troubleshooting

- If the enhanced source is absent, run `neural-voice-enhance restart` and
  inspect `journalctl --user -u neural-voice-enhance.service`.
- If the wrong hardware microphone is detected, reinstall with
  `./audio/neural-voice-enhance/install.sh --source NAME`; obtain `NAME` from
  `pactl list short sources`.
- If audio sounds watery or clipped, use the 24 dB default and keep RNNoise
  disabled.
- Launch `/usr/bin/obs` to bypass the enhancer wrapper temporarily.
