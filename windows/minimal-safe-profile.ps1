# Minimal PowerShell Profile - Safe version without problematic imports

# Basic PATH setup for essential tools
$pathsToAdd = @(
    "$env:USERPROFILE\.local\bin",           # uv and other local tools
    "$env:APPDATA\npm",                      # npm global packages
    "$env:LOCALAPPDATA\Yarn\bin",            # yarn global packages
    "$env:ALLUSERSPROFILE\chocolatey\bin"    # chocolatey tools
)

foreach ($path in $pathsToAdd) {
    if ((Test-Path $path) -and ($env:PATH -notlike "*$path*")) {
        $env:PATH = "$path;$env:PATH"
    }
}

# Essential Git aliases
function gst { git status }
function gco { git checkout $args }
function gcm { git commit -m $args }
function gpl { git pull }
function gph { git push }
function gcmep { git add -A; git commit -a -m $args; git push }
function lg { lazygit }

# Navigation
function u { Set-Location .. }
function c { Set-Location ~/code }
function o { explorer.exe . }

# Editor aliases
function vim { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function vi { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function nvim { & "C:\Program Files\Neovim\bin\nvim.exe" $args }

# Python/uv aliases
function piuv { uv pip install $args }
function uvls { uv tool list }
function uvun { uv tool uninstall $args }

# Utility functions
function reload {
    Write-Host "Reloading PowerShell profile..." -ForegroundColor Cyan
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

function Test-Tools {
    $tools = @("uv", "git", "gh", "hub", "node", "npm", "code", "nvim")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "✓ $tool" -ForegroundColor Green
        } else {
            Write-Host "✗ $tool" -ForegroundColor Red
        }
    }
}

# Alias for easier use
Set-Alias -Name check-tools -Value Test-Tools

function usager {
    Get-ChildItem | ForEach-Object {
        $item = $_
        if ($item.PSIsContainer) {
            $size = 0
            try {
                $size = (Get-ChildItem $item.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            } catch {
                $size = 0
            }
        } else {
            $size = $item.Length
        }
        
        $sizeMB = [math]::Round($size / 1MB, 2)
        Write-Host ("{0,-30} {1,10} MB" -f $item.Name, $sizeMB)
    }
}

# Safe module imports - only if available and working
try {
    if (Get-Module -ListAvailable -Name posh-git) {
        Import-Module posh-git -ErrorAction SilentlyContinue
    }
} catch {
    # Silently continue if posh-git fails
}

try {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    }
} catch {
    # Silently continue if Terminal-Icons fails
}

# Only try PSFzf if fzf binary is available
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    try {
        if (Get-Module -ListAvailable -Name PSFzf) {
            Import-Module PSFzf -ErrorAction SilentlyContinue
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue
        }
    } catch {
        # Silently continue if PSFzf fails
    }
}

Write-Host "Minimal PowerShell profile loaded! Use 'check-tools' to verify installation." -ForegroundColor Green
