# Simple PowerShell Profile

# Basic Git aliases
function gst { git status }
function gco { git checkout $args }
function gcm { git commit -m $args }
function gpl { git pull }
function gph { git push }

# Navigation
function u { Set-Location .. }
function c { Set-Location ~/code }

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
    $tools = @("node", "npm", "yarn", "git", "code")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "✓ $tool" -ForegroundColor Green
        } else {
            Write-Host "✗ $tool" -ForegroundColor Red
        }
    }
}

# Add common paths to PATH
$paths = @(
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