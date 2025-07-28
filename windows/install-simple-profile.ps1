Write-Host "Installing simple PowerShell profile..."

$profilePath = $PROFILE
Write-Host "Profile will be installed to: $profilePath"

# Create directory if needed
$profileDir = Split-Path $profilePath -Parent
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force
}

# Copy the simple profile
Copy-Item "simple-profile.ps1" $profilePath -Force

Write-Host "Simple profile installed successfully!"
Write-Host "Restart PowerShell or run: . `$PROFILE" 