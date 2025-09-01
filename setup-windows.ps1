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

# SSH/FTP Tools
Install-WingetPackage "WinSCP.WinSCP" "WinSCP"
Install-WingetPackage "PuTTY.PuTTY" "PuTTY"

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