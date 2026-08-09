#!/usr/bin/env bash
# gpu-recover: escalating NVIDIA GPU recovery. Safe by design:
#  - reboots ONLY as last resort, ONLY after failure has persisted REBOOT_AFTER_SECS (default 1h)
#  - never reboots within MIN_UPTIME_SECS of boot and at most once per REBOOT_COOLDOWN_SECS
#  - every stage logs to syslog + $STATE_DIR so you can debug what it tried
# Run from cron/systemd timer (see setup-gpu-recovery.sh). Root required for recovery stages.
set -u

STATE_DIR=${GPU_RECOVER_STATE:-/var/lib/gpu-recover}
REBOOT_AFTER_SECS=${GPU_RECOVER_REBOOT_AFTER:-3600}     # failure must persist this long before reboot
MIN_UPTIME_SECS=${GPU_RECOVER_MIN_UPTIME:-3600}         # never reboot a box younger than this
REBOOT_COOLDOWN_SECS=${GPU_RECOVER_COOLDOWN:-21600}     # min gap between auto-reboots (6h)
ALLOW_KILL=${GPU_RECOVER_ALLOW_KILL:-1}                 # allow killing GPU-holding processes
ALLOW_REBOOT=${GPU_RECOVER_ALLOW_REBOOT:-1}
ALERT_CMD=${GPU_RECOVER_ALERT_CMD:-}                    # optional: gets message as $1
SMI_TIMEOUT=25

mkdir -p "$STATE_DIR"
log() { echo "[gpu-recover] $*"; logger -t gpu-recover -p daemon.warning -- "$*"; echo "$(date -Is) $*" >> "$STATE_DIR/log"; }
alert() { log "ALERT: $*"; [ -n "$ALERT_CMD" ] && "$ALERT_CMD" "gpu-recover: $*" || true; }

gpu_ok() { timeout $SMI_TIMEOUT nvidia-smi >/dev/null 2>&1; }

clear_failure() { rm -f "$STATE_DIR/first_failure"; }

if gpu_ok; then
    [ -f "$STATE_DIR/first_failure" ] && alert "GPU recovered, clearing failure state"
    clear_failure
    exit 0
fi

# record when trouble started
now=$(date +%s)
if [ ! -f "$STATE_DIR/first_failure" ]; then
    echo "$now" > "$STATE_DIR/first_failure"
    log "nvidia-smi failed; starting recovery ladder (first failure recorded)"
fi
first=$(cat "$STATE_DIR/first_failure")

# snapshot diagnostics before touching anything
snap="$STATE_DIR/diag-$(date +%Y%m%d-%H%M%S).log"
{
    echo "== nvidia-smi"; timeout $SMI_TIMEOUT nvidia-smi 2>&1
    echo "== dmesg NVRM/Xid"; dmesg 2>/dev/null | grep -iE 'NVRM|Xid|nvidia' | tail -80
    echo "== gpu procs"; fuser -v /dev/nvidia* 2>&1
    echo "== lsmod"; lsmod | grep nvidia
    echo "== lspci"; lspci | grep -i nvidia
} > "$snap" 2>&1
log "diagnostics -> $snap"

if [ "$(id -u)" != 0 ]; then log "not root; diagnostics only"; exit 1; fi

# stage 1: transient? wait and retry
sleep 10
gpu_ok && { alert "GPU recovered after wait"; clear_failure; exit 0; }

# stage 2: restart persistence daemon + attempt GPU reset
systemctl restart nvidia-persistenced 2>/dev/null
nvidia-smi -r >/dev/null 2>&1
sleep 5
gpu_ok && { alert "GPU recovered via nvidia-smi -r"; clear_failure; exit 0; }

# stage 3: kill holders + reload modules
if [ "$ALLOW_KILL" = 1 ]; then
    log "killing GPU-holding processes"
    fuser -k -9 /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm 2>/dev/null
    sleep 5
    for m in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do rmmod "$m" 2>/dev/null; done
    sleep 2
    modprobe nvidia 2>/dev/null && modprobe nvidia_uvm 2>/dev/null && modprobe nvidia_drm 2>/dev/null
    sleep 5
    gpu_ok && { alert "GPU recovered via module reload"; clear_failure; exit 0; }
fi

# stage 4: PCI remove + rescan per NVIDIA device
for dev in $(lspci -Dn | awk '$2 ~ /^03/ && $3 ~ /^10de/ {print $1}'); do
    log "PCI remove/rescan $dev"
    echo 1 > "/sys/bus/pci/devices/$dev/remove" 2>/dev/null
done
sleep 5
echo 1 > /sys/bus/pci/rescan 2>/dev/null
sleep 10
modprobe nvidia 2>/dev/null; modprobe nvidia_uvm 2>/dev/null
sleep 5
gpu_ok && { alert "GPU recovered via PCI rescan"; clear_failure; exit 0; }

# stage 5: last resort reboot, heavily guarded
elapsed=$((now - first))
uptime_s=$(cut -d. -f1 /proc/uptime)
last_reboot=$(cat "$STATE_DIR/last_auto_reboot" 2>/dev/null || echo 0)
if [ "$ALLOW_REBOOT" != 1 ]; then
    alert "GPU still dead; reboot disabled (GPU_RECOVER_ALLOW_REBOOT=0)"
elif [ "$elapsed" -lt "$REBOOT_AFTER_SECS" ]; then
    alert "GPU still dead ${elapsed}s; will consider reboot after ${REBOOT_AFTER_SECS}s of persistent failure"
elif [ "$uptime_s" -lt "$MIN_UPTIME_SECS" ]; then
    alert "GPU dead but uptime ${uptime_s}s < ${MIN_UPTIME_SECS}s; refusing reboot (anti-bootloop)"
elif [ $((now - last_reboot)) -lt "$REBOOT_COOLDOWN_SECS" ]; then
    alert "GPU dead but last auto-reboot $((now - last_reboot))s ago < cooldown ${REBOOT_COOLDOWN_SECS}s; refusing reboot"
else
    alert "GPU dead ${elapsed}s, all recovery stages failed -> REBOOTING in 60s"
    echo "$now" > "$STATE_DIR/last_auto_reboot"
    clear_failure
    sleep 60
    systemctl reboot
fi
exit 1
