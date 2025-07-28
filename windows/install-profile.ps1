# PowerShell Profile Installer
# This script installs the PowerShell profile to the appropriate location

param(
    [string]$ProfileType = "full",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Determine which profile to install
$sourceProfile = switch ($ProfileType.ToLower()) {
    "simple" { "simple-profile.ps1" }
    "minimal" { "minimal-profile.ps1" }
    "full" { "profile.ps1" }
    default { "profile.ps1" }
}

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourceFile = Join-Path $scriptDir $sourceProfile

# Check if source file exists
if (-not (Test-Path $sourceFile)) {
    Write-Error "Source profile file not found: $sourceFile"
    exit 1
}

# Get PowerShell profile path
$profilePath = $PROFILE

# Create profile directory if it doesn't exist
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    Write-Host "Creating profile directory: $profileDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Backup existing profile if it exists
if ((Test-Path $profilePath) -and -not $Force) {
    $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "Backing up existing profile to: $backupPath" -ForegroundColor Yellow
    Copy-Item $profilePath $backupPath
}

# Copy the profile
Write-Host "Installing PowerShell profile ($ProfileType): $sourceFile -> $profilePath" -ForegroundColor Green
Copy-Item $sourceFile $profilePath -Force

# Reload profile
Write-Host "Reloading profile..." -ForegroundColor Cyan
. $profilePath

Write-Host "✅ PowerShell profile installed successfully!" -ForegroundColor Green
Write-Host "Profile location: $profilePath" -ForegroundColor DarkGray
Write-Host "You can now use all the aliases and functions defined in the profile." -ForegroundColor Cyan
Write-Host ""
Write-Host "To test the installation, try running: check-tools" -ForegroundColor Yellow 