# Simple PowerShell Profile

# Basic Git aliases
function gst { git status }
function gco { git checkout $args }
function gcm { git commit -m $args }
function gpl { git pull }
function gph { git push }

# Hub aliases (GitHub CLI)
function hcl { hub clone $args }
function hpr { hub pull-request $args }

# Navigation
function u { Set-Location .. }
function c { Set-Location ~/code }

# Editor aliases
function vim { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function vi { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function nvim { & "C:\Program Files\Neovim\bin\nvim.exe" $args }

# Python/uv aliases
function piuv { uv pip install $args }
function uvls { uv tool list }

# The usager function you wanted
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

# Utility functions
function o { explorer.exe . }

# Check if tools are available
function check-tools {
    $tools = @("uv", "git", "gh", "hub", "node", "npm", "code", "nvim")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "✓ $tool" -ForegroundColor Green
        } else {
            Write-Host "✗ $tool" -ForegroundColor Red
        }
    }
}

# Reload profile function (consistent with bash)
function reload {
    Write-Host "Reloading PowerShell profile..." -ForegroundColor Cyan
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

# Add common paths to PATH
$paths = @(
    # uv (Python package installer)
    "$env:USERPROFILE\.local\bin",
    "$env:APPDATA\npm",
    "$env:LOCALAPPDATA\Yarn\bin",
    "$env:ALLUSERSPROFILE\chocolatey\bin"
)

foreach ($path in $paths) {
    if ((Test-Path $path) -and ($env:PATH -notlike "*$path*")) {
        $env:PATH = "$path;$env:PATH"
    }
}

Write-Host "PowerShell profile loaded!" -ForegroundColor Green 