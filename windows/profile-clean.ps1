# Clean PowerShell Profile - Essential Functions Only

# Git aliases
function gst { git status }
function gco { git checkout $args }
function gcob { git checkout -b $args }
function gcom { git checkout master }
function gcm { git commit -m $args }
function gcma { git commit -a -m $args }
function gbr { git branch }
function gdf { git diff }
function gph { git push; git push --tags }
function gpl { git pull }
function gad { git add $args }
function gaa { git add -A }

# Navigation
function u { cd .. }
function c { cd ~/code }

# Directory usage (the usager function you wanted)
function usager { 
    Get-ChildItem | ForEach-Object { 
        $size = if ($_.PSIsContainer) { 
            try {
                (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum 
            } catch {
                0
            }
        } else { 
            $_.Length 
        }
        [PSCustomObject]@{
            Name = $_.Name
            SizeStr = "{0:N2} MB" -f ($size / 1MB)
        }
    } | Sort-Object { [double]($_.SizeStr -replace ' MB','') } | Format-Table Name, SizeStr -AutoSize
}

# Environment tools
function check-tools {
    $tools = @("node", "npm", "yarn", "git", "code", "nvim", "python", "pip")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "✓ $tool" -ForegroundColor Green
        } else {
            Write-Host "✗ $tool" -ForegroundColor Red
        }
    }
}

function refresh-env {
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "Environment refreshed!" -ForegroundColor Green
}

# PATH Configuration
$pathsToAdd = @(
    "$env:APPDATA\npm",
    "$env:LOCALAPPDATA\Yarn\bin",
    "$env:ALLUSERSPROFILE\chocolatey\bin",
    "${env:ProgramFiles}\Git\bin"
)

foreach ($path in $pathsToAdd) {
    if ((Test-Path $path) -and ($env:PATH -notlike "*$path*")) {
        $env:PATH = "$path;$env:PATH"
    }
}

# Node.js aliases
function ni { npm install $args }
function yi { yarn install $args }
function ya { yarn add $args }
function ys { yarn start }

# Utility functions
function o { explorer.exe . }
function pbcopy { $input | Set-Clipboard }
function pbpaste { Get-Clipboard }

# Environment variables
$env:EDITOR = "code"

# Try to import modules if available
try {
    Import-Module posh-git -ErrorAction SilentlyContinue
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    Import-Module PSFzf -ErrorAction SilentlyContinue
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue
} catch {
    # Silently continue if modules aren't available
}

Write-Host "PowerShell profile loaded successfully!" -ForegroundColor Green 