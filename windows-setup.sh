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

Invoke-WebRequest -Uri "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" -OutFile "Miniconda3-latest-Windows-x86_64.exe"
Start-Process -Wait -FilePath .\Miniconda3-latest-Windows-x86_64.exe -ArgumentList "/InstallationType=JustMe", "/AddToPath=1", "/RegisterPython=0", "/S", "/D={install_path}"

$env:Path += ";{miniconda_path}\Scripts;{miniconda_path}\Library\bin"

# Add Docker paths to environment
$env:Path += ";C:\Program Files\Docker\Docker\resources\bin;C:\ProgramData\DockerDesktop\version-bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
