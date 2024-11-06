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

# Additional Git aliases from bashrc
function gclo { git clone }
function gcmt { git commit }
function gcmts { git commit -n }
function gcms { git commit -n -m }
function gcmamd { git commit --amend -C HEAD }
function gdfc { git diff --cached }
function gdfx { git diff --cached }
function gdfm { git diff --diff-filter=M --ignore-space-change }
function glglee { git log --author=lee }
function glgme { git log --author=lee }
function gmg { git merge }
function gmga { git merge --abort }
function gmgm { git merge master }
function gmm { git merge master }
function gmgmn { git merge main }
function gadi { git add -i }
function gphf { git push -f; git push -f --tags }
function gpshf { git push -f; git push -f --tags }
function gplrb { git pull --rebase }
function gpm { git checkout master; git pull; git checkout -; }
function gplm { git checkout master; git pull; git checkout -; }
function gpgr { git checkout green; git pull; git checkout -; }
function gplh { git pull origin $(git rev-parse --abbrev-ref HEAD) }
function gpshh { git push origin $(git rev-parse --abbrev-ref HEAD) }
function gct { git checkout --track }
function gexport { git archive --format zip --output }
function gdel { git branch -D }
function gmu { git fetch origin -v; git fetch upstream -v; git merge upstream/master }
function gll { git log --graph --pretty=oneline --abbrev-commit }
function gg { git log --graph --pretty=format:"%C(bold)%h%Creset%C(yellow)%d%Creset %s %C(yellow)%an %C(cyan)%cr%Creset" --abbrev-commit --date=relative }
function ggs { gg --stat }
function gpf { git push -f }
function gsw { git show }
function grs { git reset }
function grsm { git reset master }
function grsh { git reset --hard }
function grshh { git reset --hard HEAD }
function grshm { git reset --hard master }
function grss { git reset --soft }
function grssm { git reset --soft master }
function gcp { git cherry-pick }
function gcpc { git cherry-pick --continue }
function gcpa { git cherry-pick --abort }
function gus { git reset HEAD }
function gsm { git submodule }
function gsmu { git submodule update --init }
function grpo { git remote prune origin }
function grmte { git remote -v }
function grmta { git remote add }
function grmtau { git remote add upstream }
function grmtao { git remote add origin }
function grmts { git remote set-url }
function grmtsu { git remote set-url upstream }
function grmtso { git remote set-url origin }
function gdel { git clean -f }
function gclf { git clean -f }
function grv { git revert }
function gds { git describe }
function gw { git whatchanged }
function gdfb { git diff master... }
function gdfbm { git diff main... }
function gdfbd { git diff develop... }

# Additional Git command combinations from bashrc
function gcmp { 
    git commit -m $args
    gpsh
}

function gcmps { 
    git commit -n -m $args
    gpsh
}

function gcmpf { 
    git commit -m $args
    git push -f
}

function gcmap { 
    git commit -a -m $args
    git push
}

function gcmapf { 
    git commit -a -m $args
    git push -f
}

function gcme { 
    git add -A
    git commit -a -m $args
}

function gcmep { 
    git add -A
    git commit -a -m $args
    gpsh
}

function gcmeps { 
    git add -A
    git commit -a -n -m $args
    gpsh
}

function gcmepf { 
    git add -A
    git commit -a -m $args
    git push -f
}

function gpsh {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    git push --set-upstream origin $currentBranch
}

function gbsu {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    git branch --set-upstream-to=origin/$currentBranch $currentBranch
}

function gcof {
    $branchName = gbr | fzf
    git checkout $branchName
}

function gusco { 
    git reset HEAD $args
    git checkout -- $args
}

# Git stash functions
function gss { git stash save $args }
function gssw { git stash show $args }
function gssw1 { git stash show -p stash@{0} }
function gssw2 { git stash show -p stash@{1} }
function gssw3 { git stash show -p stash@{2} }
function gsp { git stash pop $args }
function gsp1 { git stash pop stash@{0} }
function gsp2 { git stash pop stash@{1} }
function gsp3 { git stash pop stash@{2} }

# Additional utility functions from bashrc
function findn { 
    param($pattern)
    Get-ChildItem -Recurse -Filter $pattern
}

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

# Additional Docker aliases
function dklall { docker stop $(docker ps -a -q); docker rm $(docker ps --no-trunc -a -q) }
function dkillall { docker stop $(docker ps -a -q); docker rm $(docker ps --no-trunc -a -q) }
function dkillunused { docker rm $(docker ps --no-trunc -a -q); docker rmi $(docker images -a -q) }
function dkillallunused { dkillunused }
function dklalli { dklall; docker rmi $(docker images -a -q) }
function dkillalli { dklall; docker rmi $(docker images -a -q) }
function dis { docker inspect }
function drmiunused { docker rmi $(docker images --filter "dangling=true" -q --no-trunc) }
function dprna { docker system prune -a --volumes }
function dprn { docker system prune }
function ddf { docker system df }

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

# Utility functions
function usage { 
    Get-ChildItem -Force | ForEach-Object { 
        $_.Name + " " + [math]::Round((Get-ChildItem $_.FullName -Recurse | Measure-Object Length -Sum).Sum / 1MB, 2) + " MB"
    } | Sort-Object
}