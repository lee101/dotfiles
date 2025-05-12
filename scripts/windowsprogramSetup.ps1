# Install Python
Write-Host "Installing Python..." -ForegroundColor Cyan
winget install Python.Python.3.12

# Add Python to PATH if not already added
$pythonPath = "$env:LOCALAPPDATA\Programs\Python\Python312"
$pythonScriptsPath = "$pythonPath\Scripts"

if (-not ($env:Path -like "*$pythonPath*")) {
    Write-Host "Adding Python to PATH..." -ForegroundColor Cyan
    $env:Path = "$pythonPath;$pythonScriptsPath;$env:Path"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
}

# Verify Python installation
Write-Host "Verifying Python installation..." -ForegroundColor Cyan
try {
    python --version
    Write-Host "Python installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Python installation may have failed. Please check manually." -ForegroundColor Red
}

# pyenv
# Install pyenv-win
Write-Host "Installing pyenv-win..." -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"
& ./install-pyenv-win.ps1

# Add pyenv to PATH if not already added
$pyenvPath = "$env:USERPROFILE\.pyenv\pyenv-win"
$pyenvBinPath = "$pyenvPath\bin"
$pyenvShimsPath = "$pyenvPath\shims"

if (-not ($env:Path -like "*$pyenvBinPath*")) {
    Write-Host "Adding pyenv to PATH..." -ForegroundColor Cyan
    $env:Path = "$pyenvShimsPath;$pyenvBinPath;$env:Path"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
    [Environment]::SetEnvironmentVariable("PYENV", $pyenvPath, [System.EnvironmentVariableTarget]::User)
    [Environment]::SetEnvironmentVariable("PYENV_HOME", $pyenvPath, [System.EnvironmentVariableTarget]::User)
}

# Verify pyenv installation
Write-Host "Verifying pyenv installation..." -ForegroundColor Cyan
try {
    pyenv --version
    Write-Host "pyenv installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "pyenv installation may have failed. Please check manually." -ForegroundColor Red
}
