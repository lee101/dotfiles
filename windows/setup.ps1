# Windows PowerShell Profile Setup Script
# This script helps you choose and install the right PowerShell profile

param(
    [string]$ProfileType = "",
    [switch]$Force,
    [switch]$List,
    [switch]$Info
)

$ErrorActionPreference = "Stop"

# Colors for output
$green = "Green"
$yellow = "Yellow"
$red = "Red"
$cyan = "Cyan"
$gray = "DarkGray"

# Available profiles
$profiles = @{
    "full" = @{
        "file" = "profile.ps1"
        "description" = "Complete bash feature parity - All aliases, docker, python, node.js, etc."
        "size" = "Large (~15KB)"
        "recommended" = "For full development environments"
    }
    "simple" = @{
        "file" = "simple-profile.ps1"
        "description" = "Common development tools - Git, docker basics, node.js, python basics"
        "size" = "Medium (~1.6KB)"
        "recommended" = "For everyday development work"
    }
    "minimal" = @{
        "file" = "minimal-profile.ps1"
        "description" = "Just the essentials - Basic git, navigation, and editor shortcuts"
        "size" = "Small (~1KB)"
        "recommended" = "For minimal setups or slow systems"
    }
}

function Show-ProfileInfo {
    Write-Host "📋 Available PowerShell Profiles:" -ForegroundColor $cyan
    Write-Host ""
    
    foreach ($key in $profiles.Keys) {
        $profile = $profiles[$key]
        Write-Host "🔹 $($key.ToUpper())" -ForegroundColor $green
        Write-Host "   File: $($profile.file)" -ForegroundColor $gray
        Write-Host "   Description: $($profile.description)" -ForegroundColor White
        Write-Host "   Size: $($profile.size)" -ForegroundColor $gray
        Write-Host "   Recommended: $($profile.recommended)" -ForegroundColor $yellow
        Write-Host ""
    }
}

function Get-UserChoice {
    Write-Host "Which profile would you like to install?" -ForegroundColor $cyan
    Write-Host "1. Full Profile (recommended for development)" -ForegroundColor White
    Write-Host "2. Simple Profile (good balance)" -ForegroundColor White  
    Write-Host "3. Minimal Profile (lightweight)" -ForegroundColor White
    Write-Host "4. Show detailed info" -ForegroundColor $gray
    Write-Host "5. Exit" -ForegroundColor $gray
    Write-Host ""
    
    do {
        $choice = Read-Host "Enter your choice (1-5)"
        switch ($choice) {
            "1" { return "full" }
            "2" { return "simple" }
            "3" { return "minimal" }
            "4" { Show-ProfileInfo; return Get-UserChoice }
            "5" { Write-Host "Goodbye!" -ForegroundColor $yellow; exit 0 }
            default { Write-Host "Invalid choice. Please enter 1-5." -ForegroundColor $red }
        }
    } while ($true)
}

function Install-Profile {
    param($ProfileType)
    
    if (-not $profiles.ContainsKey($ProfileType)) {
        Write-Host "❌ Unknown profile type: $ProfileType" -ForegroundColor $red
        Write-Host "Available types: $($profiles.Keys -join ', ')" -ForegroundColor $gray
        exit 1
    }
    
    $profile = $profiles[$ProfileType]
    $sourceFile = $profile.file
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $sourceFilePath = Join-Path $scriptDir $sourceFile
    
    # Check if source file exists
    if (-not (Test-Path $sourceFilePath)) {
        Write-Host "❌ Source profile file not found: $sourceFilePath" -ForegroundColor $red
        exit 1
    }
    
    # Get PowerShell profile path
    $profilePath = $PROFILE
    
    # Create profile directory if it doesn't exist
    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path $profileDir)) {
        Write-Host "📁 Creating profile directory: $profileDir" -ForegroundColor $cyan
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Check if profile already exists
    if ((Test-Path $profilePath) -and -not $Force) {
        Write-Host "⚠️  PowerShell profile already exists at: $profilePath" -ForegroundColor $yellow
        $overwrite = Read-Host "Do you want to overwrite it? (y/N)"
        if ($overwrite -notmatch "^[yY]") {
            Write-Host "Installation cancelled." -ForegroundColor $yellow
            exit 0
        }
        
        # Create backup
        $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "💾 Creating backup: $backupPath" -ForegroundColor $cyan
        Copy-Item $profilePath $backupPath
    }
    
    # Install the profile
    Write-Host "🚀 Installing PowerShell profile ($ProfileType)..." -ForegroundColor $green
    Write-Host "   Source: $sourceFilePath" -ForegroundColor $gray
    Write-Host "   Target: $profilePath" -ForegroundColor $gray
    
    Copy-Item $sourceFilePath $profilePath -Force
    
    # Test the profile
    Write-Host "🔍 Testing profile..." -ForegroundColor $cyan
    try {
        . $profilePath
        Write-Host "✅ Profile installed and loaded successfully!" -ForegroundColor $green
    } catch {
        Write-Host "❌ Error loading profile: $($_.Exception.Message)" -ForegroundColor $red
        Write-Host "You may need to set execution policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor $yellow
        exit 1
    }
    
    # Show success message
    Write-Host ""
    Write-Host "🎉 PowerShell Profile Setup Complete!" -ForegroundColor $green
    Write-Host "Profile: $($profile.description)" -ForegroundColor White
    Write-Host "Location: $profilePath" -ForegroundColor $gray
    Write-Host ""
    Write-Host "💡 Tips:" -ForegroundColor $cyan
    Write-Host "• Run 'check-tools' to verify your development tools" -ForegroundColor White
    Write-Host "• Use 'refresh' to reload your profile anytime" -ForegroundColor White
    Write-Host "• Try 'gst' for git status, 'c' to cd to ~/code, 'o' to open current dir" -ForegroundColor White
    Write-Host ""
    Write-Host "📚 Run 'Get-Help about_profiles' for more PowerShell profile info" -ForegroundColor $gray
}

# Main script logic
Write-Host "🚀 Windows PowerShell Profile Setup" -ForegroundColor $green
Write-Host "===================================" -ForegroundColor $green
Write-Host ""

# Handle command line arguments
if ($Info -or $List) {
    Show-ProfileInfo
    exit 0
}

# Get profile type
if (-not $ProfileType) {
    $ProfileType = Get-UserChoice
}

# Validate and install
Install-Profile $ProfileType 