# gpu-recovery

Auto-recover any box from NVIDIA driver/GSP crashes (nvidia-smi dead, `GspRmFree failed` / Xid storms, device handle lost).

Escalation ladder, verifying `nvidia-smi` after each stage:
1. wait + retry (transient)
2. restart persistenced + `nvidia-smi -r`
3. kill GPU-holding processes, reload nvidia modules
4. PCI remove + rescan
5. **reboot — last resort only**: failure must persist 1h (debug window), never within 1h of boot, max one auto-reboot per 6h (no bootloops). Diagnostics snapshot to `/var/lib/gpu-recover/diag-*.log` before touching anything.

Linux install (systemd timer, every 5 min):
```bash
sudo ./setup-gpu-recovery.sh
```
Tune via env in gpu-recover.service: `GPU_RECOVER_REBOOT_AFTER`, `GPU_RECOVER_MIN_UPTIME`, `GPU_RECOVER_COOLDOWN`, `GPU_RECOVER_ALLOW_REBOOT=0`, `GPU_RECOVER_ALERT_CMD` (gets message as $1, e.g. SES alert script).

Windows: `gpu-recover.ps1` (device disable/enable + service restart + same guarded reboot), install:
```
schtasks /create /tn gpu-recover /sc minute /mo 5 /ru SYSTEM /tr "powershell -ExecutionPolicy Bypass -File C:\tools\gpu-recover.ps1"
```

Also recommended: keep driver current (GSP fixes land constantly), enable persistence mode, serialize heavy batch CUDA jobs (`flock /var/lock/gpu-heavy.lock cmd`), avoid multi-hour single kernel launches.
