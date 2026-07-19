# Windows Development Environment Setup Script
# Run as Administrator: Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup-windows.ps1

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Windows Development Environment Setup" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to install via winget
function Install-WingetPackage {
    param($id, $name)
    Write-Host "Installing $name..." -ForegroundColor Yellow
    winget install --id $id --accept-package-agreements --accept-source-agreements -h
}

Write-Host "Step 1: Core Development Tools" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# Version Control
Install-WingetPackage "Git.Git" "Git"

# Code Editors and IDEs
Install-WingetPackage "Microsoft.VisualStudioCode" "Visual Studio Code"
Install-WingetPackage "Neovim.Neovim" "Neovim"
Install-WingetPackage "Notepad++.Notepad++" "Notepad++"
Install-WingetPackage "JetBrains.IntelliJIDEA.Community" "IntelliJ IDEA Community"

Write-Host ""
Write-Host "Step 2: Programming Languages & Runtimes" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Node.js and package managers
Install-WingetPackage "OpenJS.NodeJS" "Node.js"
Install-WingetPackage "Yarn.Yarn" "Yarn"

# Python
Install-WingetPackage "Python.Python.3.12" "Python 3.12"

# .NET
Install-WingetPackage "Microsoft.DotNet.SDK.8" ".NET SDK 8"

Write-Host ""
Write-Host "Step 3: Terminal & Shell Tools" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# Terminal
Install-WingetPackage "Microsoft.WindowsTerminal" "Windows Terminal"
Install-WingetPackage "Microsoft.PowerShell" "PowerShell 7"
Install-WingetPackage "aristocratos.btop4win" "btop4win"

# SSH/FTP Tools
Install-WingetPackage "WinSCP.WinSCP" "WinSCP"
Install-WingetPackage "PuTTY.PuTTY" "PuTTY"

Write-Host ""
Write-Host "Step 3b: Git Bash Process Monitors" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
$bashCandidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "C:\msys64\usr\bin\bash.exe"
) | Where-Object { Test-Path $_ } | Select-Object -Unique

if ($bashCandidates.Count -eq 0) {
    Write-Host "Git Bash not found yet; btop4win is installed and lib/winbashrc provides fallbacks after dotfiles are linked." -ForegroundColor Yellow
}
else {
    foreach ($bashExe in $bashCandidates) {
        Write-Host "Checking $bashExe" -ForegroundColor DarkGray
        & $bashExe -lc "if command -v pacman >/dev/null 2>&1; then pacman -S --needed --noconfirm htop procps-ng; else exit 42; fi"
        if ($LASTEXITCODE -eq 42) {
            Write-Host "  No pacman here. Git Bash will use btop for htop/top when available." -ForegroundColor Gray
        }
        elseif ($LASTEXITCODE -eq 0) {
            Write-Host "  Installed/verified htop and top via pacman." -ForegroundColor Green
        }
        else {
            Write-Host "  Could not install htop/procps-ng via pacman. Git Bash fallbacks will still work." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Step 4: Containerization" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

Install-WingetPackage "Docker.DockerDesktop" "Docker Desktop"

Write-Host ""
Write-Host "Step 5: Databases" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

Install-WingetPackage "PostgreSQL.PostgreSQL" "PostgreSQL"
Install-WingetPackage "MongoDB.Server" "MongoDB Server"
Install-WingetPackage "Redis.Redis" "Redis"

Write-Host ""
Write-Host "Step 6: Browsers" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green

Install-WingetPackage "Google.Chrome" "Google Chrome"
Install-WingetPackage "Mozilla.Firefox.DeveloperEdition" "Firefox Developer Edition"

Write-Host ""
Write-Host "Step 7: API Tools" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

Install-WingetPackage "Insomnia.Insomnia" "Insomnia"

Write-Host ""
Write-Host "Step 8: Utilities" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

Install-WingetPackage "7zip.7zip" "7-Zip"
Install-WingetPackage "Microsoft.Sysinternals.ProcessExplorer" "Process Explorer"

Write-Host ""
Write-Host "Step 9: Communication & Media" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

Install-WingetPackage "Discord.Discord" "Discord"
Install-WingetPackage "OBSProject.OBSStudio" "OBS Studio"

Write-Host ""
Write-Host "Step 10: Enabling WSL2" -ForegroundColor Green
Write-Host "=======================" -ForegroundColor Green

Write-Host "Installing WSL with default Ubuntu distribution..." -ForegroundColor Yellow
wsl --install

# Fix Git Bash / MSYS2 console allocation limit (max 32 consoles error).
# Sets MSYS=disable_pcon and CYGWIN=disable_pcon as USER env vars so Git Bash
# can open unlimited terminals. Safe to re-run; idempotent.
Write-Host ""
Write-Host "Step 11: Git Bash Console Limit Fix" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
$fixConsole = Join-Path $PSScriptRoot 'windows\fix-console-limit.ps1'
if (Test-Path $fixConsole) {
    & $fixConsole
} else {
    Write-Host "Skipping: $fixConsole not found" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: You must restart your computer to complete WSL2 installation!" -ForegroundColor Red
Write-Host ""
Write-Host "After restart, run the following commands:" -ForegroundColor Yellow
Write-Host "1. Configure Git:" -ForegroundColor White
Write-Host "   git config --global user.name 'Your Name'" -ForegroundColor Gray
Write-Host "   git config --global user.email 'your.email@example.com'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Generate SSH key for GitHub:" -ForegroundColor White
Write-Host "   ssh-keygen -t ed25519 -C 'your.email@example.com'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Setup WSL Ubuntu (after restart):" -ForegroundColor White
Write-Host "   wsl" -ForegroundColor Gray
Write-Host "   bash /mnt/c/Users/lee_p/code/dotfiles/setup-wsl.sh" -ForegroundColor Gray
