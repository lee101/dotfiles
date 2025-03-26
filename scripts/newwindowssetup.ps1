# Setup script for new Windows development environment with WSL

# ====== CHOCOLATEY INSTALLATION AND REPAIR ======
Write-Host "Setting up Chocolatey package manager..." -ForegroundColor Cyan

# Check if Chocolatey exists but isn't working
$chocoInstalled = $false
$chocoPath = "C:\ProgramData\chocolatey"

if (Test-Path $chocoPath) {
    Write-Host "Found existing Chocolatey installation at $chocoPath" -ForegroundColor Yellow
    
    # Check if choco command works
    try {
        $chocoVersion = (& "$chocoPath\bin\choco.exe" --version) 2>$null
        if ($chocoVersion) {
            Write-Host "Chocolatey is already installed and functional (version: $chocoVersion)" -ForegroundColor Green
            $chocoInstalled = $true
        }
    } catch {
        Write-Host "Existing Chocolatey installation found but not working properly" -ForegroundColor Red
    }
    
    # If not working, fix the PATH
    if (-not $chocoInstalled) {
        Write-Host "Attempting to fix Chocolatey by adding it to PATH..." -ForegroundColor Yellow
        
        # Add to current session PATH
        $env:Path = "$chocoPath\bin;" + $env:Path
        
        # Add to permanent PATH if not already there
        $systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if (-not ($systemPath -like "*$chocoPath\bin*")) {
            [Environment]::SetEnvironmentVariable("PATH", "$chocoPath\bin;$systemPath", "Machine")
            Write-Host "Added Chocolatey to system PATH" -ForegroundColor Green
        }
        
        # Check if it works now
        try {
            $chocoVersion = (& "$chocoPath\bin\choco.exe" --version) 2>$null
            if ($chocoVersion) {
                Write-Host "Chocolatey is now functional (version: $chocoVersion)" -ForegroundColor Green
                $chocoInstalled = $true
            }
        } catch {
            Write-Host "Failed to fix Chocolatey by adding to PATH" -ForegroundColor Red
        }
        
        # If still not working, try manual repair
        if (-not $chocoInstalled) {
            Write-Host "Attempting to repair Chocolatey installation..." -ForegroundColor Yellow
            
            # Backup existing installation
            $backupFolder = "C:\ProgramData\chocolatey_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $chocoPath -Destination $backupFolder -Recurse -Force
            Write-Host "Backed up existing installation to $backupFolder" -ForegroundColor Yellow
            
            # Remove existing installation
            Remove-Item -Path $chocoPath -Recurse -Force
            Write-Host "Removed existing Chocolatey installation" -ForegroundColor Yellow
            
            # Reinstall Chocolatey
            Write-Host "Reinstalling Chocolatey..." -ForegroundColor Green
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            # Verify new installation
            try {
                $chocoVersion = (choco --version) 2>$null
                if ($chocoVersion) {
                    Write-Host "Chocolatey reinstalled successfully (version: $chocoVersion)" -ForegroundColor Green
                    $chocoInstalled = $true
                }
            } catch {
                Write-Host "Failed to reinstall Chocolatey" -ForegroundColor Red
            }
        }
    }
} else {
    # Chocolatey not installed, install it fresh
    Write-Host "Installing Chocolatey..." -ForegroundColor Green
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Verify installation
    try {
        $chocoVersion = (choco --version) 2>$null
        if ($chocoVersion) {
            Write-Host "Chocolatey installed successfully (version: $chocoVersion)" -ForegroundColor Green
            $chocoInstalled = $true
        }
    } catch {
        Write-Host "Failed to install Chocolatey" -ForegroundColor Red
    }
}

# Refresh environment variables to ensure choco is in PATH for the remainder of the script
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Check one more time if Chocolatey is working
if ($chocoInstalled) {
    Write-Host "Chocolatey is ready to use. You can run 'choco install <package>' to install packages." -ForegroundColor Green
} else {
    Write-Host "WARNING: Chocolatey installation/repair failed. Some parts of the script may not work." -ForegroundColor Red
    Write-Host "You might need to restart your PowerShell session or computer and try again." -ForegroundColor Yellow
}

# Install Podman
Write-Host "Installing Podman tools..." -ForegroundColor Cyan
winget install RedHat.Podman
winget install PodmanDesktop.PodmanDesktop
winget install RedHat.Buildah

# ====== WSL SETUP FOR MICROSOFT DEVBOX ENVIRONMENTS ======
Write-Host "Setting up WSL for DevBox environment..." -ForegroundColor Cyan

# Step 1: Enable required Windows features
Write-Host "1. Enabling Windows features..." -ForegroundColor Cyan
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Step 2: Install WSL kernel update package
Write-Host "2. Installing WSL2 Linux kernel update package..." -ForegroundColor Cyan
$wslUpdateInstallerUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
$wslUpdateInstaller = "$env:TEMP\wsl_update_x64.msi"
Invoke-WebRequest -Uri $wslUpdateInstallerUrl -OutFile $wslUpdateInstaller
Start-Process -FilePath $wslUpdateInstaller -Args "/quiet" -Wait
Remove-Item $wslUpdateInstaller

# Step 3: Set WSL 2 as default
Write-Host "3. Setting WSL 2 as default version..." -ForegroundColor Cyan
wsl --set-default-version 2

# Step 4: Configure hypervisor
Write-Host "4. Setting hypervisor launch type to Auto..." -ForegroundColor Cyan
bcdedit /set hypervisorlaunchtype Auto

# Step 5: Check if we're in a Microsoft DevBox environment
$systemInfo = Get-WmiObject -Class Win32_ComputerSystem
$isDevBox = $systemInfo.Manufacturer -like "*Microsoft*" -and $systemInfo.Model -like "*Virtual Machine*"

# ====== DEVBOX-SPECIFIC APPROACH ======
if ($isDevBox) {
    Write-Host "`n=== MICROSOFT DEVBOX ENVIRONMENT DETECTED ===" -ForegroundColor Green
    Write-Host "Using optimized WSL installation for DevBox..." -ForegroundColor Cyan
    
    # First update WSL to latest version
    Write-Host "Updating WSL to latest version..." -ForegroundColor Cyan
    wsl --update
    
    # Try offline installation method (better for DevBox)
    Write-Host "Attempting offline WSL installation..." -ForegroundColor Cyan
    wsl --install --no-distribution
    
    # Try to install Ubuntu directly
    $wslInstallSuccess = $false
    Write-Host "Installing Ubuntu distribution..." -ForegroundColor Cyan
    try {
        # First attempt - with WSL2
        wsl --install -d Ubuntu-22.04
        $wslInstallSuccess = $true
    }
    catch {
        Write-Host "Initial WSL2 installation attempt failed: $_" -ForegroundColor Yellow
        
        # If that fails, explicitly try the offline approach
        try {
            Write-Host "Trying alternative installation method..." -ForegroundColor Yellow
            wsl --install --no-distribution
            Start-Sleep -Seconds 5  # Wait a bit for WSL to initialize
            wsl --install -d Ubuntu-22.04
            $wslInstallSuccess = $true
        }
        catch {
            Write-Host "Secondary WSL2 installation attempt failed: $_" -ForegroundColor Yellow
            
            # Final attempt - fallback to WSL1
            try {
                Write-Host "Falling back to WSL1..." -ForegroundColor Yellow
                wsl --set-default-version 1
                wsl --install -d Ubuntu-22.04
                $wslInstallSuccess = $true
                Write-Host "Successfully installed WSL1" -ForegroundColor Green
            }
            catch {
                Write-Host "All WSL installation attempts failed" -ForegroundColor Red
            }
        }
    }
    
    # Print guidance based on results
    if ($wslInstallSuccess) {
        Write-Host "`nWSL installation appears successful!" -ForegroundColor Green
    }
    else {
        Write-Host "`n=== MANUAL WSL INSTALLATION GUIDANCE ===" -ForegroundColor Yellow
        Write-Host "1. Try installing WSL1 manually:" -ForegroundColor White
        Write-Host "   wsl --set-default-version 1" -ForegroundColor Green
        Write-Host "   wsl --install -d Ubuntu-22.04" -ForegroundColor Green
        Write-Host "2. If Microsoft Store is available, try installing Ubuntu from there" -ForegroundColor White
        Write-Host "3. Contact DevBox support - nested virtualization may need to be enabled" -ForegroundColor White
    }
    
    # DevBox-specific guidance
    Write-Host "`n=== DEVBOX WSL USAGE NOTES ===" -ForegroundColor Magenta
    Write-Host "• DevBox VMs work best with WSL1 if you encounter virtualization errors" -ForegroundColor White
    Write-Host "• For specific packages or versions, use the VS Code Remote WSL extension" -ForegroundColor White
    Write-Host "• If you have persistent issues, contact your DevBox administrator" -ForegroundColor White
}
else {
    # Standard non-DevBox environment
    Write-Host "`n=== STANDARD ENVIRONMENT DETECTED ===" -ForegroundColor Green
    Write-Host "Installing WSL with Ubuntu distribution..." -ForegroundColor Cyan
    wsl --install -d Ubuntu-22.04
}

# Remind about restart requirements
Write-Host "`nPlease restart your computer to complete the WSL installation." -ForegroundColor Green
Write-Host "After restart, Ubuntu will continue its setup when you first launch it." -ForegroundColor Green 

