# Windows Dotfiles - Quick Start Guide

## 30-Second Setup

Run in PowerShell (as Administrator or with Developer Mode enabled):

```powershell
# Clone your dotfiles (if not already done)
git clone https://github.com/YOUR_USERNAME/dotfiles.git C:\Users\$env:USERNAME\code\dotfiles
cd C:\Users\$env:USERNAME\code\dotfiles

# Enable script execution
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Install PowerShell profile with all your bash aliases
.\windows\install-profile.ps1 -ProfileType minimal-safe

# Link all dotfiles (creates symlinks)
.\linkdotfiles.ps1 -Force

# Reload and verify
. $PROFILE
gst  # Should run 'git status'
```

## That's it! Your environment is ready.

### Your Git Aliases Now Work
- `gst` - git status
- `gco` - git checkout  
- `gcm` - git commit -m
- `gcmep` - add all, commit, and push in one command
- `gpl` - git pull
- `gph` - git push

### Navigation Shortcuts
- `c` - go to ~/code directory
- `u` - go up one directory
- `o` - open current directory in Explorer

### Test Your Setup
```powershell
check-tools  # See what tools are installed
gst          # Test git status alias
c            # Navigate to code directory
reload       # Reload profile anytime
```

## Troubleshooting

If symlinks fail, either:
1. Enable Developer Mode: Settings → Update & Security → For developers → Developer Mode ON
2. Or run PowerShell as Administrator

Full documentation: [WINDOWS_SETUP.md](WINDOWS_SETUP.md)