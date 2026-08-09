#!/usr/bin/env bash
# Installs gpu-recover.sh + systemd timer (every 5 min). Idempotent. Run as root.
set -eu
cd "$(dirname "$0")"

install -m 755 gpu-recover.sh /usr/local/bin/gpu-recover

cat > /etc/systemd/system/gpu-recover.service <<'EOF'
[Unit]
Description=NVIDIA GPU auto-recovery (escalating, reboot only after persistent failure)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gpu-recover
# tune via env, e.g.:
# Environment=GPU_RECOVER_REBOOT_AFTER=3600 GPU_RECOVER_ALLOW_REBOOT=1
# Environment=GPU_RECOVER_ALERT_CMD=/usr/local/bin/ses-alert
EOF

cat > /etc/systemd/system/gpu-recover.timer <<'EOF'
[Unit]
Description=Run GPU health check + recovery every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now gpu-recover.timer
systemctl enable nvidia-persistenced 2>/dev/null || true
echo "gpu-recover installed. Test: sudo gpu-recover; state/logs in /var/lib/gpu-recover/"
