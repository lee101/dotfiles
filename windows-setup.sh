winget install --id GitHub.cli
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

# Install Neovim for Windows
winget install --id Neovim.Neovim

# Install ripgrep and fd for better nvim experience
choco install ripgrep
choco install fd

Invoke-WebRequest -Uri "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" -OutFile "Miniconda3-latest-Windows-x86_64.exe"
Start-Process -Wait -FilePath .\Miniconda3-latest-Windows-x86_64.exe -ArgumentList "/InstallationType=JustMe", "/AddToPath=1", "/RegisterPython=0", "/S", "/D={install_path}"

$env:Path += ";{miniconda_path}\Scripts;{miniconda_path}\Library\bin"

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

