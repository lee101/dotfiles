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

function gst { git status }
function u { Set-Location .. }
function c { Set-Location ~/code }

Write-Host "Profile loaded" -ForegroundColor Green 