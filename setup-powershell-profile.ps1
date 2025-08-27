# PowerShell Profile Setup Script
# This configures PowerShell with useful aliases, functions, and prompt customization

Write-Host "Setting up PowerShell Profile..." -ForegroundColor Cyan

# Get PowerShell profile path
$profilePath = $PROFILE.CurrentUserAllHosts

# Create profile directory if it doesn't exist
$profileDir = Split-Path $profilePath -Parent
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force
}

# PowerShell profile content
$profileContent = @'
# PowerShell Profile Configuration
# =================================

# Import modules
Import-Module PSReadLine -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Import-Module posh-git -ErrorAction SilentlyContinue

# PSReadLine Configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Aliases
Set-Alias -Name vim -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name vi -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name ll -Value Get-ChildItemColorFormatWide
Set-Alias -Name ls -Value Get-ChildItemColor
Set-Alias -Name g -Value git
Set-Alias -Name grep -Value Select-String
Set-Alias -Name touch -Value New-Item
Set-Alias -Name which -Value Get-Command

# Git aliases
function gs { git status }
function ga { git add $args }
function gc { git commit $args }
function gp { git push $args }
function gl { git log --oneline $args }
function gd { git diff $args }
function gco { git checkout $args }
function gb { git branch $args }

# Docker aliases
function d { docker $args }
function dc { docker-compose $args }
function dps { docker ps $args }
function di { docker images $args }

# Navigation shortcuts
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ~ { Set-Location ~ }
function dev { Set-Location ~/dev }
function docs { Set-Location ~/Documents }
function dl { Set-Location ~/Downloads }
function dt { Set-Location ~/Desktop }

# Utility functions
function mkcd {
    param($dir)
    mkdir $dir
    Set-Location $dir
}

function la { Get-ChildItem -Force }

function path {
    $env:Path -split ';'
}

function reload {
    & $profile
}

function Get-ChildItemColor {
    $args = $args + "-Force"
    Invoke-Expression "Get-ChildItem $args | Format-Wide -Column 1"
}

function Get-ChildItemColorFormatWide {
    Get-ChildItem $args -Force | Format-Wide -Column 1
}

# Open Windows Explorer in current directory
function e {
    explorer .
}

# Open VS Code in current directory
function c {
    code .
}

# Quick edit profile
function Edit-Profile {
    code $PROFILE
}

# System information
function sysinfo {
    Get-ComputerInfo | Select-Object `
        WindowsProductName, `
        WindowsVersion, `
        OsArchitecture, `
        CsProcessors, `
        CsTotalPhysicalMemory, `
        LogonServer, `
        CsNetworkAdapters
}

# Network utilities
function ip {
    Get-NetIPAddress | Where-Object {$_.AddressState -eq "Preferred"} | Select-Object InterfaceAlias, IPAddress
}

function ports {
    netstat -an | Select-String -Pattern "LISTENING"
}

# Process utilities
function pgrep {
    param($name)
    Get-Process | Where-Object {$_.ProcessName -like "*$name*"}
}

function pkill {
    param($name)
    Get-Process | Where-Object {$_.ProcessName -like "*$name*"} | Stop-Process
}

# File search
function find {
    param($name)
    Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue
}

# Quick HTTP server
function http-server {
    param($port = 8080)
    python -m http.server $port
}

# Weather function
function weather {
    param($location = "")
    if ($location) {
        curl "wttr.in/$location"
    } else {
        curl wttr.in
    }
}

# Extract archives
function extract {
    param($file)
    if (Test-Path $file) {
        $extension = [System.IO.Path]::GetExtension($file)
        switch ($extension) {
            ".zip" { Expand-Archive $file -DestinationPath . }
            ".tar" { tar -xf $file }
            ".gz" { 
                if ($file -like "*.tar.gz") {
                    tar -xzf $file
                } else {
                    gzip -d $file
                }
            }
            ".7z" { 7z x $file }
            ".rar" { unrar x $file }
            default { Write-Host "Unknown archive format: $extension" -ForegroundColor Red }
        }
    } else {
        Write-Host "File not found: $file" -ForegroundColor Red
    }
}

# Quick calculator
function calc {
    param([string]$expression)
    Invoke-Expression $expression
}

# Show top processes by CPU
function top {
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WS
}

# Show directory size
function du {
    param($path = ".")
    Get-ChildItem $path -Recurse | Measure-Object -Property Length -Sum | Select-Object @{Name="Size(MB)";Expression={[math]::Round($_.Sum/1MB, 2)}}, Count
}

# Enhanced history search
function hgrep {
    param($pattern)
    Get-History | Where-Object {$_.CommandLine -like "*$pattern*"}
}

# Create a new Python virtual environment
function venv {
    param($name = "venv")
    python -m venv $name
    Write-Host "Virtual environment '$name' created. Activate with: .\$name\Scripts\Activate.ps1" -ForegroundColor Green
}

# Activate Python virtual environment
function activate {
    param($name = "venv")
    & ".\$name\Scripts\Activate.ps1"
}

# Quick git clone and cd
function gclone {
    param($url)
    $folder = [System.IO.Path]::GetFileNameWithoutExtension($url)
    git clone $url
    Set-Location $folder
}

# Check if running as admin
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Prompt customization with Oh-My-Posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\powerlevel10k_rainbow.omp.json" | Invoke-Expression
} else {
    # Fallback custom prompt
    function prompt {
        $location = Get-Location
        $host.UI.RawUI.WindowTitle = "PowerShell - $location"
        
        $isAdmin = Test-Admin
        $adminFlag = if ($isAdmin) { "[ADMIN] " } else { "" }
        
        Write-Host $adminFlag -NoNewline -ForegroundColor Red
        Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Green
        Write-Host "@" -NoNewline -ForegroundColor Gray
        Write-Host "$env:COMPUTERNAME" -NoNewline -ForegroundColor Blue
        Write-Host " " -NoNewline
        Write-Host $location -NoNewline -ForegroundColor Yellow
        
        # Git branch if in git repo
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $branch = git branch --show-current 2>$null
            if ($branch) {
                Write-Host " (" -NoNewline -ForegroundColor Gray
                Write-Host $branch -NoNewline -ForegroundColor Cyan
                Write-Host ")" -NoNewline -ForegroundColor Gray
            }
        }
        
        return "> "
    }
}

# Initialize zoxide if available
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Environment variables
$env:EDITOR = "nvim"
$env:VISUAL = "code"

# Add custom paths to PATH
$customPaths = @(
    "$HOME\.local\bin",
    "$HOME\scripts",
    "$HOME\AppData\Local\Programs\Microsoft VS Code\bin"
)

foreach ($customPath in $customPaths) {
    if ((Test-Path $customPath) -and ($env:Path -notlike "*$customPath*")) {
        $env:Path = "$customPath;$env:Path"
    }
}

# Welcome message
$psVersion = $PSVersionTable.PSVersion.ToString()
Write-Host ""
Write-Host "PowerShell $psVersion" -ForegroundColor Cyan
Write-Host "Type 'Get-Help' for help, 'Get-Command' to list commands" -ForegroundColor Gray
Write-Host ""

# Load custom scripts if they exist
$customScriptsPath = "$HOME\scripts\*.ps1"
if (Test-Path $customScriptsPath) {
    Get-ChildItem $customScriptsPath | ForEach-Object {
        . $_.FullName
    }
}
'@

# Write the profile
Set-Content -Path $profilePath -Value $profileContent -Force

Write-Host "PowerShell profile created at: $profilePath" -ForegroundColor Green

# Install PowerShell modules
Write-Host "Installing PowerShell modules..." -ForegroundColor Yellow

$modules = @(
    "PSReadLine",
    "Terminal-Icons",
    "posh-git",
    "PSFzf",
    "z"
)

foreach ($module in $modules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module..." -ForegroundColor Cyan
        Install-Module -Name $module -Force -SkipPublisherCheck -Scope CurrentUser
    }
}

Write-Host "PowerShell profile setup complete!" -ForegroundColor Green
Write-Host "Reload your PowerShell or run: . `$PROFILE" -ForegroundColor Yellow