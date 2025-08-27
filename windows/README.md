# Windows PowerShell Profiles

This directory contains PowerShell profiles with feature parity to the bash/zsh configurations.

## Available Profiles

### 1. `profile.ps1` - Full Feature Profile
The comprehensive profile with complete bash feature parity including:
- **Git aliases** - All bash git aliases (gst, gco, gcm, gph, etc.)
- **Docker aliases** - Complete docker management (dps, dim, dklall, etc.)
- **Python tools** - pip/uv integration (pin, pinu, pfr, piuv, etc.)
- **Node.js tools** - npm/yarn/pnpm aliases (ni, yi, pn, etc.)
- **Utility functions** - extract, compress, findn, usage, etc.
- **Advanced features** - FZF integration, enhanced history, smart imports

### 2. `simple-profile.ps1` - Simple Profile
A lighter version with common development tools:
- Basic git aliases
- Essential navigation functions
- Python/uv basics
- Tool checking function

### 3. `minimal-safe-profile.ps1` - Minimal Safe Profile
Safe version that handles missing dependencies gracefully:
- Core git commands (gst, gco, gcm, gpl, gph, gcmep)
- Basic navigation (u, c, o)
- uv/Python tools (piuv, uvls, uvun)
- Safe module imports that won't fail
- Essential utilities (usager, reload, check-tools)

### 4. `setup-uv-profile.ps1` - Setup Script
Automated setup script that:
- Installs uv if not present
- Adds uv to user PATH
- Installs required PowerShell modules
- Installs fzf
- Verifies tool installation

## Installation

### Quick Install with uv Setup (Recommended)
```powershell
# Run the setup script first
.\setup-uv-profile.ps1

# Then install your preferred profile
.\install-profile.ps1 -ProfileType minimal-safe
```

### Manual Install
```powershell
# Choose your profile (e.g., minimal-safe-profile.ps1)
Copy-Item minimal-safe-profile.ps1 $PROFILE

# Reload profile
reload  # or . $PROFILE
```

## Key Features

### Git Aliases (Full Feature Parity)
```powershell
gst          # git status
gco <branch> # git checkout
gcm <msg>    # git commit -m
gph          # git push (with tags)
gpl          # git pull
gaa          # git add -A
gbr          # git branch
gdf          # git diff
gpsh         # git push with upstream
gcmep <msg>  # git add -A, commit, push
```

### Docker Management
```powershell
dps          # docker ps
dim          # docker images
dlg <id>     # docker logs
dklall       # stop and remove all containers
drmiunused   # remove unused images
```

### Python Tools
```powershell
pin <pkg>    # pip install using uv
pfr          # pip freeze
pfrr         # pip freeze > requirements.txt
```

### Navigation & Files
```powershell
u            # cd ..
c            # cd ~/code
o            # open current directory
usager       # show directory sizes
```

### Utilities
```powershell
extract <file>   # extract various archive formats
compress <dir>   # create tar.gz archive
findn <pattern>  # find files by name
check-tools      # verify installed tools
```

## Environment Variables

The profiles set up these environment variables:
- `$env:EDITOR = "nvim"`
- `$env:VISUAL = "nvim"`
- `$env:GIT_EDITOR = "nvim"`
- `$env:AWS_REGION = "us-east-1"`
- `$env:GO111MODULE = "on"`

## PATH Management

Automatically adds common development tool paths:
- Node.js (`$env:APPDATA\npm`)
- Yarn (`$env:LOCALAPPDATA\Yarn\bin`)
- Python Scripts directories
- Chocolatey tools
- Rust/Cargo tools
- Go tools
- Neovim installations

## WSL Integration

If WSL is available, adds shortcuts:
```powershell
w <cmd>      # wsl command
wslhome      # cd to WSL home
wslcode      # cd to WSL code directory
cdw <path>   # cd to WSL path
```

## Troubleshooting

### Profile Not Loading
1. Check execution policy: `Get-ExecutionPolicy`
2. If restricted, run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. Reload profile: `. $PROFILE`

### Tool Not Found
1. Run `check-tools` to see missing tools
2. Install missing tools via chocolatey, scoop, or direct download
3. Reload profile: `refresh`

### PATH Issues
1. Run `refresh-env` to reload environment variables
2. Manually add paths if needed
3. Restart PowerShell

## Customization

### Adding Your Own Aliases
```powershell
# Add to profile manually
function myalias { Write-Host "Custom function" }

# Or use the ali function
ali myalias=Write-Host "Custom function"
```

### Profile Locations
- Windows PowerShell: `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- PowerShell Core: `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

## Migration from Bash

This profile provides near-complete compatibility with the bash configuration:

| Bash Feature | PowerShell Equivalent | Notes |
|--------------|----------------------|-------|
| `alias gst='git status'` | `function gst { git status }` | Functions instead of aliases |
| `pbcopy/pbpaste` | `pbcopy/pbpaste` | Uses Set-Clipboard/Get-Clipboard |
| `usage` | `usage` | PowerShell equivalent using Measure-Object |
| `extract` | `extract` | Supports same archive formats |
| `which` | `Get-Command` | Built-in PowerShell equivalent |

## Contributing

When adding new features:
1. Add to the appropriate profile(s)
2. Update this README
3. Test on fresh PowerShell session
4. Ensure cross-platform compatibility where possible 