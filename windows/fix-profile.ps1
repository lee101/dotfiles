# Fix PowerShell Profile Script
Write-Host "Fixing PowerShell Profile..."
Write-Host "Profile location: $PROFILE"

# Ensure directory exists
$profileDir = Split-Path $PROFILE -Parent
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force
    Write-Host "Created profile directory: $profileDir"
}

# Copy our clean profile
Copy-Item -Path "profile-clean.ps1" -Destination $PROFILE -Force
Write-Host "Clean profile copied successfully!"

# Test if it loads without errors
Write-Host "Testing profile..."
try {
    . $PROFILE
    Write-Host "Profile loads successfully!" -ForegroundColor Green
    Write-Host "Testing usager function..."
    if (Get-Command usager -ErrorAction SilentlyContinue) {
        Write-Host "✓ usager function is available!" -ForegroundColor Green
    } else {
        Write-Host "✗ usager function not found" -ForegroundColor Red
    }
} catch {
    Write-Host "Profile has errors: $($_.Exception.Message)" -ForegroundColor Red
} 