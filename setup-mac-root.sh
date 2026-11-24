#!/usr/bin/env bash
# setup-mac-root.sh - the macOS setup steps that need sudo (run after mac-setup.sh).
# Idempotent: each step checks first. Prompts for your password once.
#
#   ./setup-mac-root.sh                 all root steps
#   ./setup-mac-root.sh --permissions   also launch apps + open Privacy panes to grant access
#
# Accessibility / Screen Recording permissions can't be granted by any script:
# the TCC database is SIP-protected and only MDM (PPPC profiles) can pre-approve.
# --permissions gets you as close as possible: launches each app so it registers,
# then opens the right Settings pane so it's one toggle per app.
set -uo pipefail

[[ "$OSTYPE" == darwin* ]] || { echo "macOS only" >&2; exit 1; }
WITH_PERMS=0
for a in "$@"; do case "$a" in --permissions) WITH_PERMS=1 ;; -h|--help) sed -n '2,12p' "$0"; exit 0 ;; esac; done

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
BREW_PREFIX="$( [ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew || echo /usr/local )"

sudo -v || exit 1
# keep sudo alive for the duration of the script
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# ── Touch ID for sudo (sudo_local survives macOS updates) ────────────
step "Touch ID for sudo"
if grep -qs '^auth.*pam_tid.so' /etc/pam.d/sudo_local; then ok "already enabled"
else
    {
        # pam_reattach makes Touch ID work inside tmux/zellij
        [ -f "$BREW_PREFIX/lib/pam/pam_reattach.so" ] && echo "auth       optional       $BREW_PREFIX/lib/pam/pam_reattach.so ignore_ssh"
        echo "auth       sufficient     pam_tid.so"
    } | sudo tee /etc/pam.d/sudo_local >/dev/null && ok "enabled (/etc/pam.d/sudo_local)"
fi

# ── Homebrew shells in /etc/shells ───────────────────────────────────
step "/etc/shells"
for sh in "$BREW_PREFIX/bin/bash" "$BREW_PREFIX/bin/zsh"; do
    [ -x "$sh" ] || continue
    grep -qx "$sh" /etc/shells && ok "$sh listed" || { echo "$sh" | sudo tee -a /etc/shells >/dev/null && ok "added $sh"; }
done

# ── Rosetta 2 (x86_64 binaries / old toolchains) ─────────────────────
step "Rosetta 2"
if [ "$(uname -m)" != arm64 ]; then ok "not Apple Silicon"
elif /usr/bin/pgrep -q oahd || arch -x86_64 /usr/bin/true 2>/dev/null; then ok "installed"
else sudo softwareupdate --install-rosetta --agree-to-license >/dev/null && ok "installed"; fi

# ── Higher open-file limits (watchers, builds, dev servers) ──────────
step "maxfiles limit"
PLIST=/Library/LaunchDaemons/limit.maxfiles.plist
if [ -f "$PLIST" ]; then ok "already raised ($(launchctl limit maxfiles | awk '{print $2"/"$3}'))"
else
    sudo tee "$PLIST" >/dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>limit.maxfiles</string>
  <key>ProgramArguments</key><array>
    <string>launchctl</string><string>limit</string><string>maxfiles</string>
    <string>524288</string><string>524288</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF
    sudo chown root:wheel "$PLIST" && sudo chmod 644 "$PLIST"
    sudo launchctl bootstrap system "$PLIST" 2>/dev/null || sudo launchctl load -w "$PLIST" 2>/dev/null
    ok "maxfiles -> 524288"
fi

# ── Firewall on + stealth mode ───────────────────────────────────────
step "Application firewall"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
if "$FW" --getglobalstate | grep -q enabled; then ok "already on"
else sudo "$FW" --setglobalstate on >/dev/null && sudo "$FW" --setstealthmode on >/dev/null && ok "on (stealth)"; fi

# ── Automatic security updates ───────────────────────────────────────
step "Software update"
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
ok "automatic checks + security responses on"

# ── Permissions helper (not root, but needs you at the screen) ──────
if [ "$WITH_PERMS" = 1 ]; then
    step "App permissions"
    for app in Rectangle AltTab Raycast Stats Ghostty; do
        [ -d "/Applications/$app.app" ] && open -ga "$app" && ok "launched $app"
    done
    sleep 2
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    echo "  Toggle ON: Rectangle, AltTab, Raycast (and your terminal if you want it to control apps)."
    read -r -p "  Press Enter when done to open Screen Recording (AltTab window previews)..." _ </dev/tty || true
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
fi

step "Done"
