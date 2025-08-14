# Install GitHub CLI and Git tools
winget install --id GitHub.cli
winget install --id GitHub.hub

# Install uv - Python package installer and resolver
winget install --id astral-sh.uv

# Install Git tools via chocolatey
choco install git-delta --yes
choco install lazygit --yes
choco install tig --yes
choco install fzf --yes

# difftastic installation for Windows - download from releases
$difftUrl = "https://github.com/Wilfred/difftastic/releases/download/0.60.0/difft-x86_64-pc-windows-msvc.zip"
$difftPath = "$env:TEMP\difft.zip"
Invoke-WebRequest -Uri $difftUrl -OutFile $difftPath
Expand-Archive -Path $difftPath -DestinationPath "$env:TEMP\difft"
Copy-Item "$env:TEMP\difft\difft.exe" "$env:ProgramFiles\Git\usr\bin\difft.exe"
Remove-Item $difftPath, "$env:TEMP\difft" -Recurse -Force

# Install useful PowerShell modules
Install-Module -Name posh-git -Force -Scope CurrentUser
Install-Module -Name Terminal-Icons -Force -Scope CurrentUser
Install-Module -Name PSFzf -Force -Scope CurrentUser

gh auth login
gh extension install github/gh-copilot

# uninstalled powertoys as causes issues 
#winget install --id Microsoft.PowerToys
#winget uninstall Microsoft.PowerToys
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# also remember to run startup.ps1
# choco install git
# choco install git-lfs
# choco install curl
# choco install wget
# choco install 7zip
# choco install vscode
choco install node 
choco install tree

# Install espeak for text-to-speech
choco install espeak

# Install clipboard utilities for Git Bash
choco install win32yank
# Note: Configure clipboard in .bashrc with conditional for Git Bash

# Install Neovim for Windows (using winget for latest version)
winget install --id Neovim.Neovim

# Fallback: Install via chocolatey if winget fails
# choco install neovim --yes

# Install ripgrep and fd for better nvim experience
choco install ripgrep
choco install fd

Invoke-WebRequest -Uri "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" -OutFile "Miniconda3-latest-Windows-x86_64.exe"
Start-Process -Wait -FilePath .\Miniconda3-latest-Windows-x86_64.exe -ArgumentList "/InstallationType=JustMe", "/AddToPath=1", "/RegisterPython=0", "/S", "/D={install_path}"

$env:Path += ";{miniconda_path}\Scripts;{miniconda_path}\Library\bin"

# Add paths to user PATH environment variable
$userPaths = @(
    "$env:USERPROFILE\.local\bin",           # uv and other local tools
    "$env:APPDATA\npm",                      # npm global packages
    "$env:LOCALAPPDATA\Yarn\bin",            # yarn global packages
    "$env:USERPROFILE\.cargo\bin",           # rust/cargo tools
    "$env:USERPROFILE\go\bin"                # go tools
)

$currentPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
foreach ($path in $userPaths) {
    if ((Test-Path $path) -and ($currentPath -notlike "*$path*")) {
        $currentPath = "$path;$currentPath"
        Write-Host "Added $path to user PATH" -ForegroundColor Green
    }
}
[Environment]::SetEnvironmentVariable("Path", $currentPath, [System.EnvironmentVariableTarget]::User)

# Add Docker paths to environment
$env:Path += ";C:\Program Files\Docker\Docker\resources\bin;C:\ProgramData\DockerDesktop\version-bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)

# Create Neovim config directory if it doesn't exist
$nvimConfigDir = "$env:LOCALAPPDATA\nvim"
if (-not (Test-Path $nvimConfigDir)) {
    New-Item -ItemType Directory -Path $nvimConfigDir -Force
}

# Check if the user has a dotfiles repository
$dotfilesDir = "$env:USERPROFILE\.dotfiles.git"
$altDotfilesDir = "$env:USERPROFILE\dotfiles"

if (Test-Path "$dotfilesDir\.config\nvim\init.lua") {
    $sourceConfigDir = "$dotfilesDir\.config\nvim"
    Write-Host "Found Neovim config in $sourceConfigDir" -ForegroundColor Green
} elseif (Test-Path "$altDotfilesDir\.config\nvim\init.lua") {
    $sourceConfigDir = "$altDotfilesDir\.config\nvim"
    Write-Host "Found Neovim config in $sourceConfigDir" -ForegroundColor Green
} else {
    Write-Host "Neovim config not found in dotfiles. Please create or copy your init.lua file." -ForegroundColor Yellow
    exit
}

# Link init.lua file
$sourceInitLua = "$sourceConfigDir\init.lua"
$targetInitLua = "$nvimConfigDir\init.lua"

if (Test-Path $targetInitLua) {
    Remove-Item $targetInitLua -Force
}
New-Item -ItemType SymbolicLink -Path $targetInitLua -Target $sourceInitLua -Force
Write-Host "Successfully linked init.lua to $targetInitLua" -ForegroundColor Green

# Link the entire nvim directory to ensure all config files are available
if (Test-Path $nvimConfigDir) {
    # Backup any existing files that aren't the init.lua we just linked
    Get-ChildItem -Path $nvimConfigDir -Exclude init.lua | ForEach-Object {
        if (-not (Test-Path "$sourceConfigDir\$($_.Name)")) {
            Move-Item $_.FullName "$($_.FullName).bak" -Force
        } else {
            Remove-Item $_.FullName -Force -Recurse
        }
    }
}

# Copy or link all other files from the source config
Get-ChildItem -Path $sourceConfigDir -Exclude init.lua | ForEach-Object {
    $targetPath = "$nvimConfigDir\$($_.Name)"
    if (-not (Test-Path $targetPath)) {
        if ($_.PSIsContainer) {
            Copy-Item $_.FullName $targetPath -Recurse -Force
        } else {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $_.FullName -Force
        }
    }
}

Write-Host "Neovim configuration setup complete" -ForegroundColor Green

# PowerShell Profile Setup
Write-Host "`nSetting up PowerShell profile..." -ForegroundColor Cyan
$windowsDir = Join-Path $PSScriptRoot "windows"
if (Test-Path "$windowsDir\setup-uv-profile.ps1") {
    Write-Host "Running PowerShell profile setup..." -ForegroundColor Yellow
    & "$windowsDir\setup-uv-profile.ps1"
} else {
    Write-Host "PowerShell setup script not found. Please run setup-uv-profile.ps1 manually." -ForegroundColor Yellow
}

Write-Host "`nWindows setup complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart your terminal to ensure all PATH changes take effect" -ForegroundColor White
Write-Host "2. Run 'check-tools' in PowerShell to verify installations" -ForegroundColor White
Write-Host "3. Run 'reload' in PowerShell if the profile doesn't load automatically" -ForegroundColor White

