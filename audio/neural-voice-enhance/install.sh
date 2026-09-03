#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
deepfilter_version="1.0.2"
deepfilter_sha256="7994ccd41d113d3f97fa1ab7cf4742af56c1b1e88f31d8a86395bd07eb019583"
deepfilter_url="https://github.com/ismailivanov/DeepFilterNetPlus/releases/download/v${deepfilter_version}/libdeep_filter_ladspa.so"
configured_source=""
attenuation_db=24
post_filter=0.02
enable_service=1
uninstall=0

usage() {
    cat <<'EOF'
Usage: install.sh [options]

Install a user-local DeepFilterNet microphone and OBS launcher.

Options:
  --source NAME       Physical pactl source name (auto-detected by default)
  --attenuation DB    Maximum suppression; 18-24 is natural, 30-40 stronger
  --post-filter N     DeepFilterNet post-filter beta, from 0 to 0.05
  --no-enable         Install files without enabling the login service
  --uninstall         Remove the managed files and restore the physical mic
  -h, --help          Show this help
EOF
}

while (($#)); do
    case "$1" in
        --source) configured_source="${2:?--source needs a pactl source name}"; shift 2 ;;
        --attenuation) attenuation_db="${2:?--attenuation needs a value}"; shift 2 ;;
        --post-filter) post_filter="${2:?--post-filter needs a value}"; shift 2 ;;
        --no-enable) enable_service=0; shift ;;
        --uninstall) uninstall=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
bin_dir="$HOME/.local/bin"
ladspa_dir="$HOME/.ladspa"
service_dir="$config_home/systemd/user"
app_dir="$data_home/applications"
config_dir="$config_home/neural-voice-enhance"
service_name="neural-voice-enhance.service"

if ((uninstall)); then
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user disable --now "$service_name" 2>/dev/null || true
    fi
    if [[ -x "$bin_dir/neural-voice-enhance" ]]; then
        "$bin_dir/neural-voice-enhance" stop 2>/dev/null || true
    fi
    rm -f -- \
        "$bin_dir/neural-voice-enhance" \
        "$bin_dir/obs-neural" \
        "$bin_dir/obs" \
        "$ladspa_dir/libdeep_filter_ladspa.so" \
        "$service_dir/$service_name" \
        "$app_dir/com.obsproject.Studio.desktop" \
        "$config_dir/config"
    if [[ -e "$bin_dir/obs.pre-neural-voice" ]]; then
        if grep -q 'obs-neural' "$bin_dir/obs.pre-neural-voice"; then
            rm -f -- "$bin_dir/obs.pre-neural-voice"
        else
            mv -- "$bin_dir/obs.pre-neural-voice" "$bin_dir/obs"
        fi
    fi
    if [[ -e "$app_dir/com.obsproject.Studio.desktop.pre-neural-voice" ]]; then
        mv -- "$app_dir/com.obsproject.Studio.desktop.pre-neural-voice" \
            "$app_dir/com.obsproject.Studio.desktop"
    fi
    systemctl --user daemon-reload 2>/dev/null || true
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$app_dir" || true
    printf 'Neural voice enhancement removed.\n'
    exit 0
fi

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    printf 'This installer currently supports x86-64 Linux desktops only.\n' >&2
    exit 1
fi
for required_command in curl install pactl sha256sum systemctl; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        printf 'Required command is missing: %s\n' "$required_command" >&2
        exit 1
    fi
done
if ! pactl info >/dev/null 2>&1; then
    printf 'Start a PulseAudio-compatible desktop session before installing.\n' >&2
    exit 1
fi

if [[ -z "$configured_source" && -r "$config_dir/config" ]]; then
    existing_source="$(
        # The installer owns this user-local configuration file.
        # shellcheck disable=SC1090
        source "$config_dir/config"
        printf '%s\n' "${SOURCE:-}"
    )"
    if [[ -n "$existing_source" ]] && \
       pactl list short sources | awk -v source="$existing_source" '$2 == source { found=1 } END { exit !found }'; then
        configured_source="$existing_source"
    fi
fi
if [[ -z "$configured_source" ]]; then
    current_default="$(pactl get-default-source 2>/dev/null || true)"
    if [[ "$current_default" != enhanced_voice && "$current_default" != deepfilter_voice_bus.monitor && "$current_default" != *.monitor ]]; then
        configured_source="$current_default"
    fi
fi
if [[ -z "$configured_source" ]] || ! pactl list short sources | awk -v source="$configured_source" '$2 == source { found=1 } END { exit !found }'; then
    configured_source="$(pactl list short sources | awk '$2 !~ /\.monitor$/ && $2 ~ /^(alsa|bluez)_input\./ { print $2; exit }')"
fi
if [[ -z "$configured_source" ]]; then
    printf 'No physical microphone found. Connect one or pass --source NAME.\n' >&2
    exit 1
fi

if ! awk -v value="$attenuation_db" 'BEGIN { exit !(value >= 0 && value <= 100) }'; then
    printf 'Attenuation must be between 0 and 100 dB.\n' >&2
    exit 2
fi
if ! awk -v value="$post_filter" 'BEGIN { exit !(value >= 0 && value <= 0.05) }'; then
    printf 'Post-filter must be between 0 and 0.05.\n' >&2
    exit 2
fi

download_dir=""
cleanup_download() {
    if [[ -n "$download_dir" && -d "$download_dir" && \
          "${download_dir##*/}" == neural-voice-install.* ]]; then
        rm -rf -- "$download_dir"
    fi
}
trap cleanup_download EXIT

plugin_target="$ladspa_dir/libdeep_filter_ladspa.so"
plugin_source="$plugin_target"
if [[ -r "$plugin_target" ]] && \
   printf '%s  %s\n' "$deepfilter_sha256" "$plugin_target" | sha256sum -c - >/dev/null 2>&1; then
    printf 'DeepFilterNet Plus v%s is already installed and verified.\n' "$deepfilter_version"
else
    download_dir="$(mktemp -d "${TMPDIR:-/tmp}/neural-voice-install.XXXXXX")"
    plugin_source="$download_dir/libdeep_filter_ladspa.so"
    printf 'Downloading DeepFilterNet Plus v%s...\n' "$deepfilter_version"
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
        --output "$plugin_source" "$deepfilter_url"
    printf '%s  %s\n' "$deepfilter_sha256" "$plugin_source" | sha256sum -c -
fi

mkdir -p "$bin_dir" "$ladspa_dir" "$service_dir" "$app_dir" "$config_dir"
if [[ "$plugin_source" != "$plugin_target" ]]; then
    install -m 0755 "$plugin_source" "$plugin_target"
fi
install -m 0755 "$script_dir/neural-voice-enhance" "$bin_dir/neural-voice-enhance"
install -m 0755 "$script_dir/obs-neural" "$bin_dir/obs-neural"

if [[ -e "$bin_dir/obs.pre-neural-voice" ]] && grep -q 'obs-neural' "$bin_dir/obs.pre-neural-voice"; then
    rm -f -- "$bin_dir/obs.pre-neural-voice"
fi
if [[ -e "$bin_dir/obs" ]] && ! cmp -s "$script_dir/obs-wrapper" "$bin_dir/obs" && \
   ! grep -q 'obs-neural' "$bin_dir/obs" && [[ ! -e "$bin_dir/obs.pre-neural-voice" ]]; then
    mv -- "$bin_dir/obs" "$bin_dir/obs.pre-neural-voice"
fi
install -m 0755 "$script_dir/obs-wrapper" "$bin_dir/obs"
install -m 0644 "$script_dir/neural-voice-enhance.service" "$service_dir/$service_name"
if [[ -e "$app_dir/com.obsproject.Studio.desktop" ]] && \
   ! grep -q '^Name=OBS Studio (Neural Voice)$' "$app_dir/com.obsproject.Studio.desktop" && \
   [[ ! -e "$app_dir/com.obsproject.Studio.desktop.pre-neural-voice" ]]; then
    mv -- "$app_dir/com.obsproject.Studio.desktop" \
        "$app_dir/com.obsproject.Studio.desktop.pre-neural-voice"
fi
sed "s|@HOME@|$HOME|g" "$script_dir/com.obsproject.Studio.desktop.in" > "$app_dir/com.obsproject.Studio.desktop"
chmod 0644 "$app_dir/com.obsproject.Studio.desktop"

{
    printf '# Managed by %s/install.sh\n' "$script_dir"
    printf 'SOURCE=%q\n' "$configured_source"
    printf 'ATTENUATION_DB=%q\n' "$attenuation_db"
    printf 'POST_FILTER=%q\n' "$post_filter"
    printf 'BUFFER_FRAMES=1\n'
    printf 'LOOPBACK_LATENCY_MS=40\n'
} > "$config_dir/config"
chmod 0600 "$config_dir/config"

systemctl --user daemon-reload
if ((enable_service)); then
    systemctl --user enable "$service_name"
    systemctl --user restart "$service_name"
else
    systemctl --user disable "$service_name" 2>/dev/null || true
    "$bin_dir/neural-voice-enhance" restart
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$app_dir" || true

printf '\nInstalled neural voice enhancement.\n'
printf 'Physical microphone: %s\n' "$configured_source"
printf 'OBS/default microphone: Enhanced_Voice_DeepFilterNet\n'
printf 'Commands: neural-voice-enhance status | restart | stop\n'
printf 'Launcher: OBS Studio (Neural Voice), or run obs\n'
