# OBS CleanAudio Configuration

This repository contains an `OBS Studio` profile and scene collection that bootstraps a clean microphone chain with RNNoise suppression. The files live under `.config/obs-studio` so they can be symlinked by `linkdotfiles.py`.

## What you get

- **Profile `CleanAudio`** with 48 kHz audio, simple output mode, and neutral video defaults.
- **Scene collection `CleanAudio`** that keeps a single empty scene (`Mic Monitor`) so OBS starts quickly without probing a camera.
- **Global audio filter**: the default `Mic/Aux` device has an enabled Noise Suppression filter using the RNNoise model (`method = 2`) with a -30 dB suppression level for strong background rejection without over-artifacting.citeturn0search0turn0search1

## Linking the config

1. Run `python linkdotfiles.py` (or your usual dotfile deploy step) so `.config/obs-studio` is symlinked into `~/.config/obs-studio`.
2. Launch OBS. On first launch it will pick the `CleanAudio` profile and scene collection automatically because `global.ini` defaults are included.

If you already had OBS open, switch to the profile via **Profile → CleanAudio** and the scene collection via **Scene Collection → CleanAudio**.

## Tweaking suppression strength

- The RNNoise filter uses neural-network based denoising tuned for voice.citeturn0search1
- Suppression is set to -30 dB by default. If it feels too aggressive, open **Edit → Advanced Audio Properties → Filters** on `Mic/Aux`, select **Noise Suppression**, and adjust the slider toward -20 dB. RNNoise adapts automatically and usually preserves speech clarity better than the legacy Speex modes.citeturn0search0

## Verifying it works

1. In OBS, open **Edit → Advanced Audio Properties** and confirm `Mic/Aux` has the filter entry.
2. Talk near a constant noise source (fan, keyboard) and watch the **Filters** window meter drop when the filter is enabled.
3. (Optional) Record a short clip—without the filter toggled you should hear the raw noise; with RNNoise on, the background should collapse while voice remains natural.

## Troubleshooting

- If OBS starts with a different profile/collection, make sure `~/.config/obs-studio/global.ini` points to `CleanAudio` in the `[Basic]` section, then relaunch.
- To re-run with the bundled headless test harness you can execute:
  ```bash
  xvfb-run -a timeout 5 obs --disable-shutdown-check --collection CleanAudio --profile CleanAudio --minimize-to-tray --multi
  ```
  This should log `filter: 'RNNoise Suppression'` for the `Mic/Aux` source, proving the filter is active.
