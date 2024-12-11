# Install required modules
function Install-RequiredModules {
    $modules = @(
        'posh-git',
        'PSReadLine',
        'Terminal-Icons',
        'PSFzf'
    )

    foreach ($module in $modules) {
        if (!(Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing $module..."
            Install-Module $module -Force -Scope CurrentUser
        } else {
            Write-Host "$module is already installed"
        }
    }
}

# Create profile directory if it doesn't exist
function Initialize-ProfileDirectory {
    $profileDir = Split-Path $PROFILE
    if (!(Test-Path $profileDir)) {
        Write-Host "Creating PowerShell profile directory..."
        New-Item -ItemType Directory -Path $profileDir
    }
}

# Install FZF using winget
function Install-Fzf {
    Write-Host "Installing FZF..."
    winget install fzf
}

# Copy profile configuration
function Copy-ProfileConfig {
    $scriptPath = $PSScriptRoot
    if (!$scriptPath) {
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $profileSource = Join-Path $scriptPath "profile.ps1"
    
    if (!(Test-Path $profileSource)) {
        Write-Error "Profile source file not found at: $profileSource"
        return
    }

    Write-Host "Copying profile configuration..."
    Copy-Item -Path $profileSource -Destination $PROFILE -Force
}

# Main setup function
function Initialize-PowerShellEnvironment {
    Write-Host "Starting PowerShell environment setup..."
    
    Install-RequiredModules
    Initialize-ProfileDirectory
    Install-Fzf
    Copy-ProfileConfig

    Write-Host "`nSetup complete! Please restart PowerShell or run '. `$PROFILE' to apply changes."
}

# Run the setup
Initialize-PowerShellEnvironment 

