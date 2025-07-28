# Windows PowerShell Profiles

This directory contains PowerShell profiles with feature parity to the bash/zsh configurations.

## Available Profiles

### 1. `profile.ps1` - Full Feature Profile
The comprehensive profile with complete bash feature parity including:
- **Git aliases** - All bash git aliases (gst, gco, gcm, gph, etc.)
- **Mercurial aliases** - hg commands (hcl, hst, hdf, etc.)
- **Docker aliases** - Complete docker management (dps, dim, dklall, etc.)
- **Python tools** - pip/uv integration (pin, pinu, pfr, etc.)
- **Node.js tools** - npm/yarn/pnpm aliases (ni, yi, pn, etc.)
- **Kubernetes** - kubectl aliases (k, kbash, etc.)
- **Utility functions** - extract, compress, findn, usage, etc.
- **Network tools** - my-ip, local-ip functions
- **WSL integration** - Windows Subsystem for Linux commands
- **Advanced history** - Enhanced PowerShell history settings

### 2. `simple-profile.ps1` - Simple Profile
A lighter version with common development tools:
- Basic git aliases
- Essential navigation functions
- Docker basics
- Python/Node.js essentials
- Tool checking function

### 3. `minimal-profile.ps1` - Minimal Profile
Just the bare essentials:
- Core git commands (gst, gco, gcm, gpl, gph)
- Basic navigation (u, c)
- File operations (o, usager)
- Editor shortcuts (vi, n)

## Installation

### Quick Install (Recommended)
```powershell
# Install full profile
.\install-profile.ps1

# Install simple profile
.\install-profile.ps1 -ProfileType simple

# Install minimal profile
.\install-profile.ps1 -ProfileType minimal

# Force install (overwrite existing)
.\install-profile.ps1 -Force
```

### Manual Install
1. Choose your profile (e.g., `profile.ps1`)
2. Copy to your PowerShell profile location:
   ```powershell
   # Find your profile location
   $PROFILE
   
   # Copy the profile
   Copy-Item profile.ps1 $PROFILE
   
   # Reload profile
   . $PROFILE
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