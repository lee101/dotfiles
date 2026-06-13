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

# Handle Neovim configuration (improved for Git Bash + PowerShell + full config)
# We prefer the root init.lua + lua/ (the active one with user.* modules and Lazy bootstrap).
# We also support the nvim/ subdir for any extra files (lazy-lock etc.).
# We link to BOTH the Windows-preferred AppData location AND the XDG ~/.config/nvim location.
# This makes `vi` / `nvim` work consistently from PowerShell, Git Bash, WSL, etc.

$nvimSourceInit = Join-Path $currentDir "init.lua"
$nvimSourceLua  = Join-Path $currentDir "lua"
$nvimSourceDir  = Join-Path $currentDir "nvim"   # secondary / extra files

$targets = @(
    (Join-Path $homeDir "AppData\Local\nvim"),   # Windows Neovim default (used by the exe)
    (Join-Path $homeDir ".config\nvim")          # XDG / Git Bash / WSL / many tools friendly path
)

foreach ($nvimConfigDir in $targets) {
    if (!(Test-Path $nvimConfigDir)) {
        New-Item -ItemType Directory -Path $nvimConfigDir -Force | Out-Null
        Write-Host "Created Neovim config dir: $nvimConfigDir" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Linking Neovim config into $nvimConfigDir ..." -ForegroundColor Cyan

    # Primary: root init.lua (the real config with Lazy + require("user.*"))
    if (Test-Path $nvimSourceInit) {
        $targetInit = Join-Path $nvimConfigDir "init.lua"
        if ((Test-Path $targetInit) -and $Force) { Remove-Item $targetInit -Force -ErrorAction SilentlyContinue }
        if (!(Test-Path $targetInit)) {
            try {
                New-Item -ItemType SymbolicLink -Path $targetInit -Target $nvimSourceInit -Force:$Force | Out-Null
                Write-Host "  Linked init.lua" -ForegroundColor Green
            } catch {
                Write-Host "  (init.lua link may need admin / Dev Mode): $($_.Exception.Message)" -ForegroundColor Yellow
                # Fallback copy for robustness on Git Bash / restricted envs
                Copy-Item $nvimSourceInit $targetInit -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Primary: root lua/ (contains user/ with options, keymaps, lsp-optimized, etc.)
    if (Test-Path $nvimSourceLua) {
        $targetLua = Join-Path $nvimConfigDir "lua"
        if ((Test-Path $targetLua) -and $Force) { Remove-Item $targetLua -Force -Recurse -ErrorAction SilentlyContinue }
        if (!(Test-Path $targetLua)) {
            try {
                New-Item -ItemType SymbolicLink -Path $targetLua -Target $nvimSourceLua -Force:$Force | Out-Null
                Write-Host "  Linked lua/" -ForegroundColor Green
            } catch {
                Write-Host "  (lua/ link may need admin): $($_.Exception.Message)" -ForegroundColor Yellow
                Copy-Item -Recurse -Force $nvimSourceLua $targetLua -ErrorAction SilentlyContinue
            }
        }
    }

    # Also bring in anything useful from the nvim/ subdir (lazy-lock.json, extra plugins, etc.)
    if (Test-Path $nvimSourceDir) {
        $items = Get-ChildItem -Path $nvimSourceDir -Force | Where-Object { $_.Name -notin @('init.lua', 'lua') }
        foreach ($item in $items) {
            $dest = Join-Path $nvimConfigDir $item.Name
            if ((Test-Path $dest) -and $Force) { Remove-Item $dest -Force -Recurse -ErrorAction SilentlyContinue }
            if (!(Test-Path $dest)) {
                try {
                    New-Item -ItemType SymbolicLink -Path $dest -Target $item.FullName -Force:$Force | Out-Null
                    Write-Host "  Linked extra: $($item.Name)" -ForegroundColor DarkGreen
                } catch {
                    Copy-Item -Recurse -Force $item.FullName $dest -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# One-time helpful note for Git Bash users
Write-Host ""
Write-Host "Neovim linking done for both AppData and ~/.config/nvim (Git Bash friendly)." -ForegroundColor Green

Write-Host ""
Write-Host "Dotfile linking complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: You may need to run PowerShell as Administrator for symbolic links to work properly." -ForegroundColor Yellow
Write-Host "Alternative: Enable Developer Mode in Windows Settings to allow symlinks without admin rights." -ForegroundColor Yellow