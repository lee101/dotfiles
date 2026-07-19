# Quick Windows Dev Setup
# Installs PowerShell profile, familiar Linux CLI tools, and configures Git Bash
#
# Usage (run in PowerShell, optionally as Admin for symlinks):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\quick-setup-windows.ps1
#
# What this does:
#   1. Installs familiar Linux CLI tools via winget
#   2. Installs the PowerShell profile with all aliases (git, claude, codex, docker, etc.)
#   3. Configures Git Bash to source the dotfiles bashrc (gives you cld, gst, etc. in bash too)
#   4. Links dotfiles (gitconfig, ctags, etc.) to home directory
#
# Aliases you get (both PowerShell and Git Bash):
#   htop/top     - Familiar process monitor commands in Git Bash
#   cld/cldd     - Claude Code (skip permissions)
#   cldc/cldr    - Claude --continue / --resume
#   cldp         - Claude --print
#   cr/crc       - Claude review (all / staged)
#   ccmt/cgcmep  - Claude commit / add+commit+push
#   cx/cxm/cxf   - Local Codex low/medium/high/full-auto helpers
#   goats/goatb  - Goat Simulator save status/backup
#   gst/gco/gph  - Git status/checkout/push
#   c            - cd ~/code
#   reload       - Reload shell profile
#   check-tools  - Verify installed tools

param(
    [switch]$SkipTools,
    [switch]$SkipProfile,
    [switch]$SkipBash,
    [switch]$SkipDotfiles
)

$dotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Quick Windows Dev Setup" -ForegroundColor Cyan
Write-Host "Dotfiles: $dotfilesDir" -ForegroundColor Gray
Write-Host ""

# ==========================================
# Step 1: Install CLI tools via winget
# ==========================================
if (-not $SkipTools) {
    Write-Host "[1/4] Installing CLI tools via winget..." -ForegroundColor Green

    # winget packages: [winget ID, command name, description]
    $wingetTools = @(
        @("Git.Git",                 "git",    "Git and Git Bash"),
        @("junegunn.fzf",           "fzf",    "fuzzy finder"),
        @("BurntSushi.ripgrep.MSVC", "rg",     "fast grep"),
        @("sharkdp.fd",             "fd",     "fast find"),
        @("sharkdp.bat",            "bat",    "cat with syntax highlighting"),
        @("eza-community.eza",      "eza",    "modern ls"),
        @("dandavison.delta",       "delta",  "better git diff"),
        @("jqlang.jq",              "jq",     "JSON processor"),
        @("MikeFarah.yq",           "yq",     "YAML processor"),
        @("tldr-pages.tlrc",        "tldr",   "simplified man pages"),
        @("aristocratos.btop4win",  "btop",   "familiar process monitor"),
        @("ajeetdsouza.zoxide",     "zoxide", "smarter cd"),
        @("DominikReichl.KeePass",  "keepass","password manager")
    )

    foreach ($tool in $wingetTools) {
        $id = $tool[0]; $cmd = $tool[1]; $desc = $tool[2]
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-Host "  Installing $cmd ($desc)..." -ForegroundColor Yellow
            winget install --id $id --accept-package-agreements --accept-source-agreements -h 2>$null
        } else {
            Write-Host "  $cmd already installed" -ForegroundColor DarkGray
        }
    }

    # Install uv if missing
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host "  Installing uv (Python package manager)..." -ForegroundColor Yellow
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    } else {
        Write-Host "  uv already installed" -ForegroundColor DarkGray
    }

    # Install real Unix process monitors when Git Bash is backed by MSYS2.
    # Git for Windows normally has no pacman, so lib/winbashrc maps htop to
    # btop and provides a top fallback using Get-Process.
    Write-Host ""
    Write-Host "  Configuring Git Bash process monitors..." -ForegroundColor Green
    $bashCandidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "C:\msys64\usr\bin\bash.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -Unique

    if ($bashCandidates.Count -eq 0) {
        Write-Host "  Git Bash not found yet; install Git and rerun this script for bash-native htop/top." -ForegroundColor Yellow
    }
    else {
        foreach ($bashExe in $bashCandidates) {
            Write-Host "  Checking $bashExe" -ForegroundColor DarkGray
            & $bashExe -lc "if command -v pacman >/dev/null 2>&1; then pacman -S --needed --noconfirm htop procps-ng; else exit 42; fi"
            if ($LASTEXITCODE -eq 42) {
                Write-Host "    No pacman here. Git Bash will use btop for htop and a PowerShell-backed top fallback." -ForegroundColor Gray
            }
            elseif ($LASTEXITCODE -eq 0) {
                Write-Host "    Installed/verified htop and top via pacman." -ForegroundColor Green
            }
            else {
                Write-Host "    Could not install htop/procps-ng via pacman. Git Bash fallbacks will still work." -ForegroundColor Yellow
            }
        }
    }

    # sshpass - only available via Git Bash / MSYS2, not native Windows
    Write-Host ""
    Write-Host "  Note: sshpass is available in Git Bash (via MSYS2)." -ForegroundColor Gray
    Write-Host "  In Git Bash run: pacman -S sshpass  (if MSYS2)" -ForegroundColor Gray
    Write-Host "  Or use ssh-copy-id + key-based auth instead." -ForegroundColor Gray

    Write-Host ""
} else {
    Write-Host "[1/4] Skipping CLI tools (--SkipTools)" -ForegroundColor DarkGray
}

# ==========================================
# Step 2: Install PowerShell profile
# ==========================================
if (-not $SkipProfile) {
    Write-Host "[2/4] Installing PowerShell profile..." -ForegroundColor Green

    $profileSource = Join-Path $dotfilesDir "windows\profile.ps1"
    $profileDir = Split-Path $PROFILE -Parent

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    Copy-Item $profileSource $PROFILE -Force
    Write-Host "  Installed to: $PROFILE" -ForegroundColor Green

    # Install PowerShell modules
    $modules = @("PSReadLine", "Terminal-Icons", "posh-git")
    foreach ($mod in $modules) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            Write-Host "  Installing module: $mod..." -ForegroundColor Yellow
            Install-Module -Name $mod -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction SilentlyContinue
        } else {
            Write-Host "  Module $mod already installed" -ForegroundColor DarkGray
        }
    }

    # Install PSFzf if fzf is available
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        if (-not (Get-Module -ListAvailable -Name PSFzf)) {
            Write-Host "  Installing module: PSFzf..." -ForegroundColor Yellow
            Install-Module -Name PSFzf -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
} else {
    Write-Host "[2/4] Skipping PowerShell profile (--SkipProfile)" -ForegroundColor DarkGray
}

# ==========================================
# Step 3: Configure Git Bash
# ==========================================
if (-not $SkipBash) {
    Write-Host "[3/4] Configuring Git Bash..." -ForegroundColor Green

    $bashrcTarget = Join-Path $env:USERPROFILE ".bashrc"
    $bashProfileTarget = Join-Path $env:USERPROFILE ".bash_profile"

    # The dotfiles bashrc is the main config - just symlink/copy it
    # It sources lib/common_shell which has all the cld, git, etc. aliases
    $bashrcSource = Join-Path $dotfilesDir "bashrc"
    $bashProfileSource = Join-Path $dotfilesDir "bash_profile"

    # Link .bashrc
    if (Test-Path $bashrcSource) {
        try {
            if (Test-Path $bashrcTarget) { Remove-Item $bashrcTarget -Force }
            New-Item -ItemType SymbolicLink -Path $bashrcTarget -Target $bashrcSource -Force | Out-Null
            Write-Host "  Linked ~/.bashrc -> dotfiles/bashrc" -ForegroundColor Green
        } catch {
            # Symlink failed (no admin/dev mode), fall back to copy
            Copy-Item $bashrcSource $bashrcTarget -Force
            Write-Host "  Copied dotfiles/bashrc -> ~/.bashrc (symlink failed, using copy)" -ForegroundColor Yellow
        }
    }

    # Link .bash_profile
    if (Test-Path $bashProfileSource) {
        try {
            if (Test-Path $bashProfileTarget) { Remove-Item $bashProfileTarget -Force }
            New-Item -ItemType SymbolicLink -Path $bashProfileTarget -Target $bashProfileSource -Force | Out-Null
            Write-Host "  Linked ~/.bash_profile -> dotfiles/bash_profile" -ForegroundColor Green
        } catch {
            Copy-Item $bashProfileSource $bashProfileTarget -Force
            Write-Host "  Copied dotfiles/bash_profile -> ~/.bash_profile (symlink failed, using copy)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
} else {
    Write-Host "[3/4] Skipping Git Bash config (--SkipBash)" -ForegroundColor DarkGray
}

# ==========================================
# Step 4: Link dotfiles
# ==========================================
if (-not $SkipDotfiles) {
    Write-Host "[4/4] Linking dotfiles..." -ForegroundColor Green

    $linkScript = Join-Path $dotfilesDir "linkdotfiles.ps1"
    if (Test-Path $linkScript) {
        & $linkScript -Force
    } else {
        Write-Host "  linkdotfiles.ps1 not found, skipping" -ForegroundColor Yellow
    }

    Write-Host ""
} else {
    Write-Host "[4/4] Skipping dotfiles linking (--SkipDotfiles)" -ForegroundColor DarkGray
}

# ==========================================
# Step 5: Fix Git Bash console limit
# ==========================================
# Sets MSYS=disable_pcon + CYGWIN=disable_pcon as USER env vars so Git Bash
# doesn't hit the "too many consoles in use, max consoles is 32" error.
# Idempotent, safe to re-run.
$fixConsole = Join-Path $dotfilesDir "windows\fix-console-limit.ps1"
if (Test-Path $fixConsole) {
    Write-Host "[5/5] Applying Git Bash console-limit fix..." -ForegroundColor Green
    & $fixConsole
    Write-Host ""
}

# ==========================================
# Summary
# ==========================================
Write-Host "Setup complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Key aliases (PowerShell + Git Bash):" -ForegroundColor Yellow
Write-Host "  htop/top     Familiar process monitor commands in Git Bash" -ForegroundColor White
Write-Host "  cld/cldd     Claude Code (skip permissions)" -ForegroundColor White
Write-Host "  cldc/cldr    Claude --continue / --resume" -ForegroundColor White
Write-Host "  cldp         Claude --print" -ForegroundColor White
Write-Host "  cr/crc       Claude review (all / staged)" -ForegroundColor White
Write-Host "  ccmt/cgcmep  Claude commit / add+commit+push" -ForegroundColor White
Write-Host "  cx/cxm/cxf   Local Codex helpers (default / medium / full-auto)" -ForegroundColor White
Write-Host "  goats/goatb  Goat Simulator save status / backup" -ForegroundColor White
Write-Host "  gst/gco/gph  Git status/checkout/push" -ForegroundColor White
Write-Host "  gpsh         Git push + set upstream" -ForegroundColor White
Write-Host "  c            cd ~/code" -ForegroundColor White
Write-Host "  reload       Reload shell profile" -ForegroundColor White
Write-Host "  check-tools  Verify installed tools" -ForegroundColor White
Write-Host ""
Write-Host "Reload: . `$PROFILE (PowerShell) or open a new terminal" -ForegroundColor Yellow
