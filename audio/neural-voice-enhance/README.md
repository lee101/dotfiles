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
