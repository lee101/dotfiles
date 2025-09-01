# Parallel Windows Development Environment Setup
# This script runs multiple winget installations concurrently for faster setup
# Run as Administrator: Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup-windows-parallel.ps1

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Parallel Windows Development Setup" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting parallel installations..." -ForegroundColor Green
Write-Host "This will take several minutes. Multiple installations will run simultaneously." -ForegroundColor Yellow
Write-Host ""

# Define all packages to install
$packages = @(
    @{id = "Git.Git"; name = "Git"},
    @{id = "Microsoft.VisualStudioCode"; name = "Visual Studio Code"},
    @{id = "OpenJS.NodeJS"; name = "Node.js"},
    @{id = "Python.Python.3.12"; name = "Python 3.12"},
    @{id = "Docker.DockerDesktop"; name = "Docker Desktop"},
    @{id = "Microsoft.WindowsTerminal"; name = "Windows Terminal"},
    @{id = "Microsoft.PowerShell"; name = "PowerShell 7"},
    @{id = "Yarn.Yarn"; name = "Yarn"},
    @{id = "JetBrains.IntelliJIDEA.Community"; name = "IntelliJ IDEA Community"},
    @{id = "Mozilla.Firefox.DeveloperEdition"; name = "Firefox Developer Edition"},
    @{id = "Google.Chrome"; name = "Google Chrome"},
    @{id = "7zip.7zip"; name = "7-Zip"},
    @{id = "Insomnia.Insomnia"; name = "Insomnia"},
    @{id = "Microsoft.Sysinternals.ProcessExplorer"; name = "Process Explorer"},
    @{id = "PostgreSQL.PostgreSQL"; name = "PostgreSQL"},
    @{id = "MongoDB.Server"; name = "MongoDB Server"},
    @{id = "Redis.Redis"; name = "Redis"},
    @{id = "Microsoft.DotNet.SDK.8"; name = ".NET SDK 8"},
    @{id = "Neovim.Neovim"; name = "Neovim"},
    @{id = "WinSCP.WinSCP"; name = "WinSCP"},
    @{id = "PuTTY.PuTTY"; name = "PuTTY"},
    @{id = "OBSProject.OBSStudio"; name = "OBS Studio"},
    @{id = "Discord.Discord"; name = "Discord"},
    @{id = "Notepad++.Notepad++"; name = "Notepad++"}
)

# Start all installations in parallel
$jobs = @()
foreach ($package in $packages) {
    Write-Host "Starting installation of $($package.name)..." -ForegroundColor Cyan
    $job = Start-Job -ScriptBlock {
        param($id, $name)
        try {
            winget install --id $id --accept-package-agreements --accept-source-agreements -h --silent
            return @{
                Package = $name
                Status = "Success"
                Error = $null
            }
        }
        catch {
            return @{
                Package = $name
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    } -ArgumentList $package.id, $package.name
    
    $jobs += @{
        Job = $job
        Package = $package.name
    }
}

Write-Host ""
Write-Host "Waiting for installations to complete..." -ForegroundColor Yellow
Write-Host "This may take 10-20 minutes depending on your internet connection." -ForegroundColor Gray
Write-Host ""

# Wait for all jobs to complete and display results
$completed = @()
$failed = @()

while ($jobs.Count -gt 0) {
    Start-Sleep -Seconds 5
    
    for ($i = $jobs.Count - 1; $i -ge 0; $i--) {
        $jobInfo = $jobs[$i]
        $job = $jobInfo.Job
        
        if ($job.State -eq "Completed") {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job
            
            if ($result.Status -eq "Success") {
                Write-Host "✓ $($result.Package) - Completed" -ForegroundColor Green
                $completed += $result.Package
            } else {
                Write-Host "✗ $($result.Package) - Failed: $($result.Error)" -ForegroundColor Red
                $failed += $result.Package
            }
            
            $jobs.RemoveAt($i)
        }
        elseif ($job.State -eq "Failed") {
            Write-Host "✗ $($jobInfo.Package) - Job Failed" -ForegroundColor Red
            $failed += $jobInfo.Package
            Remove-Job -Job $job
            $jobs.RemoveAt($i)
        }
    }
    
    if ($jobs.Count -gt 0) {
        Write-Host "Still installing: $($jobs.Count) packages remaining..." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Installing WSL..." -ForegroundColor Green
try {
    wsl --install
    Write-Host "✓ WSL installation initiated" -ForegroundColor Green
} catch {
    Write-Host "✗ WSL installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Successfully installed ($($completed.Count)):" -ForegroundColor Green
foreach ($app in $completed) {
    Write-Host "  ✓ $app" -ForegroundColor Green
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed installations ($($failed.Count)):" -ForegroundColor Red
    foreach ($app in $failed) {
        Write-Host "  ✗ $app" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "You can manually install failed packages using:" -ForegroundColor Yellow
    Write-Host "winget search <package-name>" -ForegroundColor Gray
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Restart your computer to complete WSL2 setup!" -ForegroundColor Red
Write-Host ""
Write-Host "After restart:" -ForegroundColor Yellow
Write-Host "1. Configure Git with your credentials" -ForegroundColor White
Write-Host "2. Generate SSH keys for GitHub" -ForegroundColor White
Write-Host "3. Set up WSL Ubuntu environment" -ForegroundColor White
Write-Host "4. Configure your development tools" -ForegroundColor White