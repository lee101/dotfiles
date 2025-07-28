# Minimal PowerShell Profile - Just the essentials
# Author: Lee Penkman

# Essential Git aliases  
function gst { git status }
function gco { git checkout $args }
function gcm { git commit -m $args }
function gpl { git pull }
function gph { git push }

# Essential navigation
function u { Set-Location .. }
function c { Set-Location ~/code }

# Essential file operations  
function o { explorer.exe . }
function usager {
    Get-ChildItem | ForEach-Object {
        if ($_.PSIsContainer) {
            try {
                $size = (Get-ChildItem $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
            } catch {
                $size = 0
            }
        } else {
            $size = $_.Length
        }
        $sizeMB = [math]::Round($size / 1MB, 2)
        Write-Output "$($_.Name) - $sizeMB MB"
    }
}

# Essential editor
function vi { nvim $args }
function n { nvim $args }

# Basic environment
$env:EDITOR = "nvim"

Write-Host "Minimal profile loaded" -ForegroundColor Green 