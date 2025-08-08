# PowerShell script to set up uv and fix profile issues
# Run this script to ensure uv is in PATH and PowerShell profile works correctly

Write-Host "Setting up uv and PowerShell profile..." -ForegroundColor Cyan

# Check if uv is installed
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv..." -ForegroundColor Yellow
    winget install --id astral-sh.uv
    Write-Host "uv installed!" -ForegroundColor Green
} else {
    Write-Host "uv is already installed" -ForegroundColor Green
}

# Ensure uv is in user PATH
$uvPath = "$env:USERPROFILE\.local\bin"
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)

if ($currentUserPath -notlike "*$uvPath*") {
    Write-Host "Adding uv to user PATH..." -ForegroundColor Yellow
    $newPath = "$uvPath;$currentUserPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::User)
    Write-Host "uv added to PATH!" -ForegroundColor Green
} else {
    Write-Host "uv is already in PATH" -ForegroundColor Green
}

# Update current session PATH
if ($env:PATH -notlike "*$uvPath*") {
    $env:PATH = "$uvPath;$env:PATH"
}

# Install PowerShell modules if not present
$modules = @("posh-git", "Terminal-Icons", "PSFzf")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module..." -ForegroundColor Yellow
        Install-Module -Name $module -Force -Scope CurrentUser -SkipPublisherCheck
        Write-Host "$module installed!" -ForegroundColor Green
    } else {
        Write-Host "$module is already installed" -ForegroundColor Green
    }
}

# Install fzf if not present
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host "Installing fzf..." -ForegroundColor Yellow
    choco install fzf --yes
    Write-Host "fzf installed!" -ForegroundColor Green
} else {
    Write-Host "fzf is already installed" -ForegroundColor Green
}

# Check tools
Write-Host "`nChecking tools:" -ForegroundColor Cyan
$tools = @("uv", "fzf", "git", "node", "npm")
foreach ($tool in $tools) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Host "✓ $tool" -ForegroundColor Green
    } else {
        Write-Host "✗ $tool" -ForegroundColor Red
    }
}

Write-Host "`nSetup complete! You may need to restart your terminal for all changes to take effect." -ForegroundColor Green
Write-Host "Run 'reload' in PowerShell to reload your profile." -ForegroundColor Cyan
