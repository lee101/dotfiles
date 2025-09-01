# Windows Dotfiles Setup Guide

This guide will help you set up your dotfiles on Windows with full feature parity to your Linux setup.

## Prerequisites

1. **PowerShell 7+** (recommended) or Windows PowerShell 5.1+
2. **Git** for version control
3. **Administrator privileges** (for creating symbolic links) OR Developer Mode enabled

### Enable Developer Mode (Recommended)
1. Go to Windows Settings → Update & Security → For developers
2. Turn on "Developer Mode"
3. This allows symbolic links without admin privileges

## Quick Setup

Run these commands in PowerShell:

```powershell
# Navigate to your dotfiles directory
cd C:\Users\<username>\code\dotfiles

# Set execution policy (if needed)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install PowerShell profile
.\windows\install-profile.ps1 -ProfileType minimal-safe

# Link dotfiles (use -Force to overwrite existing)
.\linkdotfiles.ps1 -Force

# Reload your profile
reload
```

## Detailed Setup Instructions

### 1. PowerShell Profile Setup

The dotfiles include several PowerShell profiles with different feature levels:

#### Available Profiles:
- **minimal-safe** - Recommended for most users
  - Essential git aliases (gst, gco, gcm, etc.)
  - Navigation shortcuts (u, c, o)
  - Editor aliases (vim, nvim)
  - Python/uv tools (piuv, uvls, uvun)
  - Safe module imports

- **simple** - More features
  - All minimal-safe features plus docker, node.js basics

- **full** - Complete bash feature parity
  - All aliases from Linux/bash version
  - Docker management, Python tools, Node.js tools
  - Advanced utilities and functions

#### Install a Profile:
```powershell
# Option 1: Use the installer script
.\windows\install-profile.ps1 -ProfileType minimal-safe

# Option 2: Manual installation
Copy-Item .\windows\minimal-safe-profile.ps1 $PROFILE -Force
```

### 2. Link Dotfiles

The `linkdotfiles.ps1` script creates symbolic links for your configuration files:

```powershell
# Basic linking
.\linkdotfiles.ps1

# Force overwrite existing files
.\linkdotfiles.ps1 -Force

# Show help
.\linkdotfiles.ps1 -Help
```

This will link:
- Git configuration (`.gitconfig`, `.gitignore_global`)
- Shell configuration files (like `.bashrc` if using WSL)
- Neovim configuration to `%LOCALAPPDATA%\nvim\`
- Other dotfiles as symbolic links to `~\.filename`

### 3. Verify Installation

```powershell
# Reload your PowerShell profile
reload

# Check which tools are available
check-tools

# Test git aliases
gst  # Should run 'git status'

# Test navigation
c    # Should go to ~/code directory
u    # Should go up one directory
o    # Should open current directory in Explorer
```

## Key Features

### Git Aliases
The profile includes all your favorite git aliases:
```powershell
gst          # git status
gco <branch> # git checkout
gcm <msg>    # git commit -m
gpl          # git pull  
gph          # git push
gcmep <msg>  # git add -A, commit, push (one command!)
lg           # lazygit (if installed)
```

### Navigation & Utilities
```powershell
u            # cd ..
c            # cd ~/code
o            # open current directory in Explorer
usager       # show directory sizes (like Linux 'usage')
reload       # reload PowerShell profile
```

### Development Tools
```powershell
# Python with uv
piuv <pkg>   # uv pip install
uvls         # uv tool list
uvun <pkg>   # uv tool uninstall

# Editor shortcuts
vim <file>   # Opens with Neovim
vi <file>    # Opens with Neovim
nvim <file>  # Opens with Neovim
```

## File Structure After Setup

```
C:\Users\<username>\
├── .gitconfig              -> dotfiles\gitconfig
├── .gitignore_global       -> dotfiles\gitignore_global
├── .bashrc                 -> dotfiles\bashrc (if using WSL)
├── .vimrc                  -> dotfiles\vimrc
├── Documents\
│   └── WindowsPowerShell\
│       └── Microsoft.PowerShell_profile.ps1  # Your PowerShell profile
└── AppData\Local\
    └── nvim\               -> dotfiles\nvim\ (or individual files)
        ├── init.lua
        └── lua\
```

## Advanced Configuration

### PowerShell Modules (Optional)

For enhanced functionality, install these PowerShell modules:

```powershell
# Git integration
Install-Module posh-git -Scope CurrentUser

# Beautiful file icons
Install-Module Terminal-Icons -Scope CurrentUser

# FZF integration (requires fzf binary)
Install-Module PSFzf -Scope CurrentUser
choco install fzf  # or scoop install fzf
```

### WSL Integration

If you use WSL, the profiles include shortcuts:
```powershell
w <cmd>      # Run command in WSL
wslhome      # Go to WSL home directory  
wslcode      # Go to WSL code directory
```

## Troubleshooting

### Profile Not Loading
1. Check execution policy: `Get-ExecutionPolicy`
2. If restricted: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. Reload profile: `reload` or `. $PROFILE`

### Symbolic Links Failed
1. **Option 1**: Enable Developer Mode in Windows Settings
2. **Option 2**: Run PowerShell as Administrator
3. **Option 3**: Use hard links instead: modify `linkdotfiles.ps1` to use `-ItemType HardLink`

### Tools Not Found
1. Run `check-tools` to see what's missing
2. Install missing tools with Chocolatey, Scoop, or direct download
3. Ensure tools are in your PATH
4. Run `reload` to refresh environment

### Git Configuration Issues
```powershell
# Verify git config is linked
Get-Item ~/.gitconfig
Test-Path ~/.gitconfig

# Re-link if needed
Remove-Item ~/.gitconfig -Force
New-Item -ItemType SymbolicLink -Path ~/.gitconfig -Target .\gitconfig
```

## Customization

### Adding Your Own Aliases
Add to your profile manually or use the provided functions:
```powershell
# Add to profile
function myalias { Write-Host "Custom function" }

# Or edit the profile file directly
notepad $PROFILE
```

### Profile Locations
- **Windows PowerShell**: `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- **PowerShell 7+**: `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

## Migration from Linux/Mac

Your Windows setup now has feature parity with your Linux setup:

| Linux/Bash | Windows PowerShell | Notes |
|------------|-------------------|-------|
| `alias gst='git status'` | `function gst { git status }` | Functions instead of aliases |
| `cd ~/code && cd -` | `c` | Direct navigation |
| `ls -la` | `ll` or `Get-ChildItem` | PowerShell native |
| `usage` | `usager` | Directory size utility |
| `source ~/.bashrc` | `reload` | Reload configuration |
| `which <tool>` | `Get-Command <tool>` | Find command location |

## Next Steps

1. Install development tools: Node.js, Python, Docker, etc.
2. Configure Windows Terminal for better experience
3. Set up SSH keys for Git repositories
4. Install additional PowerShell modules as needed
5. Customize the profile further for your workflow

## Getting Help

```powershell
# Show available functions
Get-Command -Module $null | Where-Object { $_.CommandType -eq 'Function' }

# Get help for PowerShell concepts
Get-Help about_profiles
Get-Help about_functions

# Check tool installation
check-tools
```

Your Windows environment is now configured with the same productivity features as your Linux setup!