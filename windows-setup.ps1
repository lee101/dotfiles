# Install required modules
Install-Module posh-git -Force
Install-Module PSReadLine -Force
Install-Module Terminal-Icons -Force 
Install-Module PSFzf -Force

# Create profile directory if it doesn't exist
$profileDir = Split-Path $PROFILE
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir
}

# Create/overwrite profile with our config
$config = @'
# Import modules
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSFzf

# FZF config
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Better tab completion
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Git aliases
function gst { git status }
function gsto { git status -uno }
function gco { git checkout $args }
function gcob { git checkout -b $args }
function gcom { git checkout master }
function gcl { git clone --recurse-submodules $args }
function gcm { git commit -m $args }
function gcma { git commit -a -m $args }
function gbr { git branch }
function gdf { git diff }
function glg { git log }
function gph { git push; git push --tags }
function gpl { git pull }
function gad { git add $args }
function gaa { git add -A }
function grb { git rebase $args }
function grbc { git rebase --continue }
function grba { git rebase --abort }

# Navigation
function u { cd .. }
function c { cd ~/code }

# Docker
function dps { docker ps }
function dim { docker images }
function dlg { docker logs $args }
function drm { docker rm $args }
function drmi { docker rmi $args }
function dkl { docker kill $args }
function dstt { docker start $args }
function dstp { docker stop $args }

# Utility functions
function mkcd { 
    param($path)
    New-Item -ItemType Directory -Path $path
    Set-Location $path
}

function extract {
    param($file)
    if (Test-Path $file) {
        switch -regex ($file) {
            '\.zip$' { Expand-Archive $file -DestinationPath . }
            '\.tar\.gz$' { tar -xzf $file }
            '\.tar$' { tar -xf $file }
            default { Write-Host "Don't know how to extract '$file'..." }
        }
    } else {
        Write-Host "'$file' is not a valid file!"
    }
}

# Kubernetes
Set-Alias -Name k -Value kubectl

# Common shortcuts
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name which -Value Get-Command

# Python aliases
function pin { pip install $args }
function pinu { pip install -U $args }
function pfr { pip freeze }
function pfrr { pip freeze > requirements.txt }

# Directory listing with colors
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.FileInfo.Directory = "`e[34m"
} else {
    # For older PowerShell versions, we can use Set-PSReadLineOption for some color customization
    Set-PSReadLineOption -Colors @{
        Command = 'Blue'
        Parameter = 'DarkCyan'
        String = 'DarkGreen'
    }
}

# Better history
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Custom prompt
function prompt {
    $location = Get-Location
    $git = git branch --show-current 2>$null
    $gitPrompt = if ($git) { " ($git)" } else { "" }
    "PS $location$gitPrompt> "
}

# Useful functions
function Find-String {
    param($pattern, $path = ".")
    Get-ChildItem -Path $path -Recurse | Select-String -Pattern $pattern
}

function Get-DirSize {
    param($path = ".")
    Get-ChildItem -Path $path -Recurse | Measure-Object -Property Length -Sum
}

# Environment variables
$env:EDITOR = "code"
'@

# Write config to profile
$config | Out-File -FilePath $PROFILE -Encoding utf8

winget install fzf

Write-Host "Setup complete! Restart PowerShell or run '. $PROFILE' to apply changes."