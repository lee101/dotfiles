# PowerShell Script to Link Dotfiles on Windows
# This script creates symbolic links for dotfiles similar to the Python version

param(
    [switch]$Force,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\linkdotfiles.ps1 [-Force]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Force    Forcibly overwrite existing files/links"
    Write-Host "  -Help     Show this help message"
    Write-Host ""
    Write-Host "This script creates symbolic links from dotfiles in the current directory" -ForegroundColor White
    Write-Host "to the user's home directory, prefixed with a dot."
    Write-Host ""
    Write-Host "Files to skip: .*. linkdotfiles*, README*, *.ps1, *.sh, lua, init.lua" -ForegroundColor Gray
    exit 0
}

$ErrorActionPreference = "Continue"

# Skip these files (uses wildcards)
$skipPatterns = @('.*', 'linkdotfiles*', 'README*', '*.ps1', '*.sh', 'lua', 'init.lua', 'windows', 'scripts', 'tools', 'docs', 'flamegraph-analyzer', 'nvim')

$currentDir = Get-Location
$homeDir = $env:USERPROFILE

Write-Host "Linking dotfiles from $currentDir to $homeDir" -ForegroundColor Cyan
Write-Host ""

$files = Get-ChildItem -Path $currentDir | Where-Object { 
    $item = $_
    $skip = $false
    
    foreach ($pattern in $skipPatterns) {
        if ($item.Name -like $pattern) {
            $skip = $true
            break
        }
    }
    
    return !$skip -and !$item.PSIsContainer
}

foreach ($file in $files) {
    $sourcePath = $file.FullName
    $targetPath = Join-Path $homeDir ".$($file.Name)"
    
    Write-Host "Processing: $($file.Name)" -ForegroundColor White
    
    if (Test-Path $targetPath) {
        if ($Force) {
            Write-Host "  Removing existing: $targetPath" -ForegroundColor Yellow
            try {
                Remove-Item $targetPath -Force -Recurse
            } catch {
                Write-Host "  Failed to remove: $targetPath - $($_.Exception.Message)" -ForegroundColor Red
                continue
            }
        } else {
            Write-Host "  Skipping (exists): $targetPath" -ForegroundColor Gray
            Write-Host "  Use -Force to overwrite" -ForegroundColor Gray
            continue
        }
    }
    
    try {
        # Create symbolic link
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force:$Force | Out-Null
        Write-Host "  Created link: $targetPath -> $sourcePath" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to create link: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Handle Windows-specific gitconfig
$winGitconfig = Join-Path $currentDir "gitconfig.windows"
if (Test-Path $winGitconfig) {
    Write-Host ""
    Write-Host "Linking Windows-specific gitconfig..." -ForegroundColor Cyan
    $targetPath = Join-Path $homeDir ".gitconfig.windows"

    if (Test-Path $targetPath) {
        if ($Force) {
            Write-Host "  Removing existing: $targetPath" -ForegroundColor Yellow
            Remove-Item $targetPath -Force
        } else {
            Write-Host "  Skipping (exists): $targetPath" -ForegroundColor Gray
        }
    }

    if (!(Test-Path $targetPath)) {
        try {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $winGitconfig -Force:$Force | Out-Null
            Write-Host "  Created link: $targetPath -> $winGitconfig" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to create link: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Handle lib directory files (like git_aliases)
$libPath = Join-Path $currentDir "lib"
if (Test-Path $libPath) {
    Write-Host ""
    Write-Host "Processing lib directory..." -ForegroundColor Cyan
    
    $libFiles = Get-ChildItem -Path $libPath -File | Where-Object { 
        $_.Name -ne 'winbashrc'  # Skip Windows-specific bash file
    }
    
    foreach ($file in $libFiles) {
        $sourcePath = $file.FullName
        $targetPath = Join-Path $homeDir ".$($file.Name)"
        
        Write-Host "Processing lib file: $($file.Name)" -ForegroundColor White
        
        if (Test-Path $targetPath) {
            if ($Force) {
                Write-Host "  Removing existing: $targetPath" -ForegroundColor Yellow
                try {
                    Remove-Item $targetPath -Force
                } catch {
                    Write-Host "  Failed to remove: $targetPath - $($_.Exception.Message)" -ForegroundColor Red
                    continue
                }
            } else {
                Write-Host "  Skipping (exists): $targetPath" -ForegroundColor Gray
                continue
            }
        }
        
        try {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force:$Force | Out-Null
            Write-Host "  Created link: $targetPath -> $sourcePath" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to create link: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Handle Neovim configuration
$nvimSourceInit = Join-Path $currentDir "init.lua"
$nvimSourceLua = Join-Path $currentDir "lua"
$nvimSourceDir = Join-Path $currentDir "nvim"

# Prefer the nvim directory if it exists, otherwise use init.lua and lua in root
if (Test-Path $nvimSourceDir) {
    Write-Host ""
    Write-Host "Setting up Neovim configuration from nvim directory..." -ForegroundColor Cyan
    $nvimConfigDir = Join-Path $homeDir "AppData\Local\nvim"
    
    if (!(Test-Path $nvimConfigDir)) {
        New-Item -ItemType Directory -Path $nvimConfigDir -Force | Out-Null
        Write-Host "Created nvim config directory: $nvimConfigDir" -ForegroundColor Green
    }
    
    # Link the entire nvim directory contents
    $nvimItems = Get-ChildItem -Path $nvimSourceDir
    foreach ($item in $nvimItems) {
        $sourcePath = $item.FullName
        $targetPath = Join-Path $nvimConfigDir $item.Name
        
        Write-Host "Processing nvim: $($item.Name)" -ForegroundColor White
        
        if (Test-Path $targetPath) {
            if ($Force) {
                Write-Host "  Removing existing: $targetPath" -ForegroundColor Yellow
                Remove-Item $targetPath -Force -Recurse
            } else {
                Write-Host "  Skipping (exists): $targetPath" -ForegroundColor Gray
                continue
            }
        }
        
        try {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force:$Force | Out-Null
            Write-Host "  Created link: $targetPath -> $sourcePath" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to create link: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} elseif ((Test-Path $nvimSourceInit) -or (Test-Path $nvimSourceLua)) {
    Write-Host ""
    Write-Host "Setting up Neovim configuration from root files..." -ForegroundColor Cyan
    $nvimConfigDir = Join-Path $homeDir "AppData\Local\nvim"
    
    if (!(Test-Path $nvimConfigDir)) {
        New-Item -ItemType Directory -Path $nvimConfigDir -Force | Out-Null
        Write-Host "Created nvim config directory: $nvimConfigDir" -ForegroundColor Green
    }
    
    # Link init.lua
    if (Test-Path $nvimSourceInit) {
        $targetInit = Join-Path $nvimConfigDir "init.lua"
        if (Test-Path $targetInit) {
            if ($Force) {
                Write-Host "Removing existing init.lua" -ForegroundColor Yellow
                Remove-Item $targetInit -Force
            } else {
                Write-Host "Skipping init.lua (exists)" -ForegroundColor Gray
            }
        }
        
        if (!(Test-Path $targetInit)) {
            try {
                New-Item -ItemType SymbolicLink -Path $targetInit -Target $nvimSourceInit -Force:$Force | Out-Null
                Write-Host "Created link: $targetInit -> $nvimSourceInit" -ForegroundColor Green
            } catch {
                Write-Host "Failed to create init.lua link: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Link lua directory
    if (Test-Path $nvimSourceLua) {
        $targetLua = Join-Path $nvimConfigDir "lua"
        if (Test-Path $targetLua) {
            if ($Force) {
                Write-Host "Removing existing lua directory" -ForegroundColor Yellow
                Remove-Item $targetLua -Force -Recurse
            } else {
                Write-Host "Skipping lua directory (exists)" -ForegroundColor Gray
            }
        }
        
        if (!(Test-Path $targetLua)) {
            try {
                New-Item -ItemType SymbolicLink -Path $targetLua -Target $nvimSourceLua -Force:$Force | Out-Null
                Write-Host "Created link: $targetLua -> $nvimSourceLua" -ForegroundColor Green
            } catch {
                Write-Host "Failed to create lua directory link: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "Dotfile linking complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: You may need to run PowerShell as Administrator for symbolic links to work properly." -ForegroundColor Yellow
Write-Host "Alternative: Enable Developer Mode in Windows Settings to allow symlinks without admin rights." -ForegroundColor Yellow