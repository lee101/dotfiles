# Windows Development Environment Setup Script
# Run this script in PowerShell as Administrator
# Usage: Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup-windows-dev.ps1

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Windows Development Environment Setup Script" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to check if a command exists
function Test-CommandExists {
    param($command)
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Function to install software via winget
function Install-WingetPackage {
    param($id, $name)
    Write-Host "Installing $name..." -ForegroundColor Yellow
    winget install --id $id --accept-package-agreements --accept-source-agreements -h
}

Write-Host "Step 1: Installing Package Managers" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Install Chocolatey
if (-not (Test-CommandExists "choco")) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
} else {
    Write-Host "Chocolatey already installed" -ForegroundColor Green
}

# Install Scoop
if (-not (Test-CommandExists "scoop")) {
    Write-Host "Installing Scoop..." -ForegroundColor Yellow
    Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
    scoop bucket add extras
    scoop bucket add versions
    scoop bucket add java
} else {
    Write-Host "Scoop already installed" -ForegroundColor Green
}

# Install uv (Modern Python Package Manager)
if (-not (Test-CommandExists "uv")) {
    Write-Host "Installing uv..." -ForegroundColor Yellow
    powershell -Command "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "C:\Users\$env:USERNAME\.local\bin;$env:Path"
} else {
    Write-Host "uv already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 2: Core Development Tools" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# Git and GitHub CLI
Install-WingetPackage "Git.Git" "Git"
Install-WingetPackage "GitHub.cli" "GitHub CLI"

# Version Control GUIs
Install-WingetPackage "GitHub.GitHubDesktop" "GitHub Desktop"
Install-WingetPackage "Atlassian.Sourcetree" "SourceTree"

Write-Host ""
Write-Host "Step 3: Code Editors and IDEs" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

# VS Code and extensions
Install-WingetPackage "Microsoft.VisualStudioCode" "Visual Studio Code"
Install-WingetPackage "Microsoft.VisualStudio.2022.Community" "Visual Studio 2022 Community"
Install-WingetPackage "JetBrains.Toolbox" "JetBrains Toolbox"
Install-WingetPackage "Neovim.Neovim" "Neovim"
Install-WingetPackage "vim.vim" "Vim"
Install-WingetPackage "Notepad++.Notepad++" "Notepad++"
Install-WingetPackage "SublimeHQ.SublimeText.4" "Sublime Text 4"

Write-Host ""
Write-Host "Step 4: Programming Languages & Runtimes" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Node.js and package managers
Install-WingetPackage "OpenJS.NodeJS.LTS" "Node.js LTS"
Install-WingetPackage "Yarn.Yarn" "Yarn"
Install-WingetPackage "pnpm.pnpm" "pnpm"

# Python
Install-WingetPackage "Python.Python.3.12" "Python 3.12"

# Go
Install-WingetPackage "GoLang.Go" "Go"

# Rust
Install-WingetPackage "Rustlang.Rustup" "Rust"

# Java
Install-WingetPackage "Oracle.JDK.21" "Java JDK 21"

# .NET
Install-WingetPackage "Microsoft.DotNet.SDK.8" ".NET SDK 8"

# Ruby
Install-WingetPackage "RubyInstallerTeam.Ruby.3.2" "Ruby"

# PHP
choco install php -y

# Deno
Install-WingetPackage "DenoLand.Deno" "Deno"

# Bun
powershell -c "irm bun.sh/install.ps1 | iex"

Write-Host ""
Write-Host "Step 5: Terminal & Shell Tools" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# Windows Terminal
Install-WingetPackage "Microsoft.WindowsTerminal" "Windows Terminal"

# PowerShell 7
Install-WingetPackage "Microsoft.PowerShell" "PowerShell 7"

# Terminal emulators
Install-WingetPackage "Eugeny.Tabby" "Tabby Terminal"
Install-WingetPackage "Microsoft.PowerToys" "PowerToys"

# Shell enhancements
scoop install starship
scoop install zoxide
scoop install fzf
scoop install ripgrep
scoop install fd
scoop install bat
scoop install eza
scoop install delta
scoop install jq
scoop install yq
scoop install tldr

Write-Host ""
Write-Host "Step 6: WSL2 and Linux Tools" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

# Enable WSL2
Write-Host "Enabling WSL2..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Install WSL
wsl --install --no-launch
wsl --set-default-version 2

# Install Ubuntu
Write-Host "Installing Ubuntu for WSL..." -ForegroundColor Yellow
wsl --install -d Ubuntu-24.04

Write-Host ""
Write-Host "Step 7: Docker & Containers" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

Install-WingetPackage "Docker.DockerDesktop" "Docker Desktop"
Install-WingetPackage "RedHat.Podman-Desktop" "Podman Desktop"

Write-Host ""
Write-Host "Step 8: Database Tools" -ForegroundColor Green
Write-Host "=======================" -ForegroundColor Green

Install-WingetPackage "PostgreSQL.pgAdmin" "pgAdmin"
Install-WingetPackage "dbeaver.dbeaver" "DBeaver"
Install-WingetPackage "MongoDB.Compass.Community" "MongoDB Compass"
Install-WingetPackage "Redis.RedisInsight" "Redis Insight"

# Database servers via Scoop
scoop install postgresql
scoop install mysql
scoop install mongodb

Write-Host ""
Write-Host "Step 9: API & Network Tools" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

Install-WingetPackage "Postman.Postman" "Postman"
Install-WingetPackage "Insomnia.Insomnia" "Insomnia"
Install-WingetPackage "WiresharkFoundation.Wireshark" "Wireshark"
Install-WingetPackage "PuTTY.PuTTY" "PuTTY"
Install-WingetPackage "WinSCP.WinSCP" "WinSCP"

# CLI tools
scoop install curl
scoop install wget
scoop install httpie
scoop install ngrok

Write-Host ""
Write-Host "Step 10: Build Tools & Compilers" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

Install-WingetPackage "CMake.CMake" "CMake"
Install-WingetPackage "GNU.Make" "Make"
choco install mingw -y
choco install llvm -y

Write-Host ""
Write-Host "Step 11: Cloud Tools" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

Install-WingetPackage "Amazon.AWSCLI" "AWS CLI"
Install-WingetPackage "Microsoft.AzureCLI" "Azure CLI"
Install-WingetPackage "Google.CloudSDK" "Google Cloud SDK"
scoop install terraform
scoop install kubectl
scoop install helm
scoop install k9s

Write-Host ""
Write-Host "Step 12: Productivity Tools" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

Install-WingetPackage "Microsoft.Teams" "Microsoft Teams"
Install-WingetPackage "SlackTechnologies.Slack" "Slack"
Install-WingetPackage "Discord.Discord" "Discord"
Install-WingetPackage "Notion.Notion" "Notion"
Install-WingetPackage "Obsidian.Obsidian" "Obsidian"
Install-WingetPackage "Figma.Figma" "Figma"

Write-Host ""
Write-Host "Step 13: File Management & Utilities" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

Install-WingetPackage "7zip.7zip" "7-Zip"
Install-WingetPackage "voidtools.Everything" "Everything Search"
Install-WingetPackage "AntibodySoftware.WizTree" "WizTree"
Install-WingetPackage "Microsoft.Sysinternals.ProcessExplorer" "Process Explorer"
Install-WingetPackage "BleachBit.BleachBit" "BleachBit"

Write-Host ""
Write-Host "Step 14: Browsers" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

Install-WingetPackage "Google.Chrome" "Google Chrome"
Install-WingetPackage "Mozilla.Firefox.DeveloperEdition" "Firefox Developer Edition"
Install-WingetPackage "Brave.Brave" "Brave Browser"
Install-WingetPackage "Microsoft.Edge.Dev" "Edge Developer"

Write-Host ""
Write-Host "Step 15: Security Tools" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

Install-WingetPackage "Bitwarden.Bitwarden" "Bitwarden"
Install-WingetPackage "KeePassXCTeam.KeePassXC" "KeePassXC"
Install-WingetPackage "NordVPN.NordVPN" "NordVPN"

Write-Host ""
Write-Host "Step 16: Media Tools" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

Install-WingetPackage "VideoLAN.VLC" "VLC Media Player"
Install-WingetPackage "OBSProject.OBSStudio" "OBS Studio"
Install-WingetPackage "GIMP.GIMP" "GIMP"
Install-WingetPackage "Audacity.Audacity" "Audacity"

Write-Host ""
Write-Host "Step 17: System Configuration" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

# Enable Developer Mode
Write-Host "Enabling Developer Mode..." -ForegroundColor Yellow
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"

# Enable long paths
Write-Host "Enabling long paths..." -ForegroundColor Yellow
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" /t REG_DWORD /f /v "LongPathsEnabled" /d "1"

# Show file extensions
Write-Host "Configuring Explorer to show file extensions..." -ForegroundColor Yellow
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /t REG_DWORD /f /v "HideFileExt" /d "0"

# Show hidden files
Write-Host "Configuring Explorer to show hidden files..." -ForegroundColor Yellow
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /t REG_DWORD /f /v "Hidden" /d "1"

Write-Host ""
Write-Host "Step 18: Dotfiles Setup" -ForegroundColor Green
Write-Host "=======================" -ForegroundColor Green

# Setup PowerShell profile and dotfiles
Write-Host "Setting up PowerShell profile with bash-like aliases..." -ForegroundColor Yellow
if (Test-Path "$PSScriptRoot\windows\minimal.ps1") {
    Copy-Item "$PSScriptRoot\windows\minimal.ps1" "$PROFILE" -Force
    Write-Host "PowerShell profile installed" -ForegroundColor Green
} else {
    Write-Host "Warning: PowerShell profile not found. Please run linkdotfiles.ps1 manually." -ForegroundColor Yellow
}

# Link dotfiles
Write-Host "Linking dotfiles..." -ForegroundColor Yellow
if (Test-Path "$PSScriptRoot\linkdotfiles.ps1") {
    & "$PSScriptRoot\linkdotfiles.ps1" -Force
    Write-Host "Dotfiles linked successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: linkdotfiles.ps1 not found. Please run manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 19: Installing Oh My Posh for PowerShell" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

scoop install oh-my-posh
# Install fonts for terminal
oh-my-posh font install FiraCode
oh-my-posh font install CascadiaCode
oh-my-posh font install JetBrainsMono

Write-Host ""
Write-Host "Step 19: Python Development Tools" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green

# Install Python packages
Write-Host "Installing Python development packages..." -ForegroundColor Yellow
python -m pip install --upgrade pip
pip install pipx virtualenv poetry black flake8 mypy pytest ipython jupyter notebook pandas numpy matplotlib seaborn scikit-learn requests beautifulsoup4 flask django fastapi

Write-Host ""
Write-Host "Step 20: Node.js Global Packages" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

Write-Host "Installing Node.js global packages..." -ForegroundColor Yellow
npm install -g typescript ts-node nodemon pm2 create-react-app create-next-app @angular/cli @vue/cli vite eslint prettier webpack webpack-cli babel-cli jest mocha

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Restart your computer to complete WSL2 installation" -ForegroundColor White
Write-Host "2. Your git aliases are ready: gst, gco, gcm, gpl, gph" -ForegroundColor White
Write-Host "3. Your PowerShell profile with bash-like shortcuts is installed" -ForegroundColor White
Write-Host "4. Test your setup: 'gst' (git status), 'c' (go to ~/code), 'u' (go up)" -ForegroundColor White
Write-Host "5. Use 'uv' for Python packages: 'uv pip install package'" -ForegroundColor White
Write-Host "6. Set up SSH keys for GitHub: ssh-keygen -t ed25519 -C 'your.email@example.com'" -ForegroundColor White
Write-Host "7. Configure Windows Terminal with your preferred theme" -ForegroundColor White
Write-Host "8. Install VS Code extensions for your languages" -ForegroundColor White
Write-Host "9. Set up WSL2 Ubuntu by running: wsl" -ForegroundColor White
Write-Host ""
Write-Host "Some installations may require a restart to work properly." -ForegroundColor Yellow