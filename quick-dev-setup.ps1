# Quick Windows Development Setup
# Essential tools only - run this first!
# Usage: powershell -ExecutionPolicy Bypass -File quick-dev-setup.ps1

Write-Host "Quick Windows Development Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Function to install software via winget
function Install-Tool {
    param($id, $name)
    Write-Host "Installing $name..." -ForegroundColor Yellow
    winget install --id $id --accept-package-agreements --accept-source-agreements -h
}

# Essential development tools
Write-Host "Installing Essential Development Tools..." -ForegroundColor Green
Install-Tool "Microsoft.VisualStudioCode" "VS Code"
Install-Tool "Git.Git" "Git"
Install-Tool "GitHub.cli" "GitHub CLI"
Install-Tool "Neovim.Neovim" "Neovim"
Install-Tool "OpenJS.NodeJS.LTS" "Node.js LTS"
Install-Tool "Python.Python.3.12" "Python 3.12"

# Modern package managers
Write-Host "Installing Modern Package Managers..." -ForegroundColor Green
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv (Python)..." -ForegroundColor Yellow
    powershell -Command "irm https://astral.sh/uv/install.ps1 | iex"
}

# Popular languages
Write-Host "Installing Programming Languages..." -ForegroundColor Green
Install-Tool "Rustlang.Rustup" "Rust"
Install-Tool "GoLang.Go" "Go"

# Essential utilities
Write-Host "Installing Essential Utilities..." -ForegroundColor Green
Install-Tool "7zip.7zip" "7-Zip"
Install-Tool "Mozilla.Firefox" "Firefox"
Install-Tool "JetBrains.Toolbox" "JetBrains Toolbox"

# Setup PowerShell profile and dotfiles
Write-Host "Setting up development environment..." -ForegroundColor Green
if (Test-Path "$PSScriptRoot\windows\minimal.ps1") {
    New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force
    Copy-Item "$PSScriptRoot\windows\minimal.ps1" "$PROFILE" -Force
    Write-Host "PowerShell profile with git aliases installed!" -ForegroundColor Green
}

if (Test-Path "$PSScriptRoot\linkdotfiles.ps1") {
    & "$PSScriptRoot\linkdotfiles.ps1" -Force
    Write-Host "Dotfiles linked!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Quick Setup Complete! 🎉" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host "Your git aliases are ready:" -ForegroundColor Yellow
Write-Host "  gst - git status" -ForegroundColor White
Write-Host "  gco - git checkout" -ForegroundColor White
Write-Host "  gcm - git commit -m" -ForegroundColor White
Write-Host "  gpl - git pull" -ForegroundColor White
Write-Host "  gph - git push" -ForegroundColor White
Write-Host ""
Write-Host "Navigation shortcuts:" -ForegroundColor Yellow
Write-Host "  c - go to ~/code" -ForegroundColor White
Write-Host "  u - go up one directory" -ForegroundColor White
Write-Host ""
Write-Host "Restart PowerShell to use the new profile!" -ForegroundColor Cyan
Write-Host "Run setup-windows-dev.ps1 for full development environment." -ForegroundColor Cyan