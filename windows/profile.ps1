
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
function sscp { ssh -o StrictHostKeyChecking=no administrator@93.127.141.100 @args }

# Modern Git tools
function lg { lazygit }
function gti { tig status }
function tgi { tig status }  # Alternative alias for tig
function tg { tig $args }    # Short tig alias
function gdiff { git difftool --no-symlinks --dir-diff $args }
function gmerge { git mergetool $args }

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

# Hub functions (GitHub CLI)
function hcl { hub clone $args }
function hcr { hub create $args }
function hpr { hub pull-request $args }
function hbr { hub browse $args }
function hfork { hub fork $args }

# Additional utility functions from bashrc
function findn {
    param($pattern)
    Get-ChildItem -Recurse -Filter $pattern
}

# Navigation
function d { Set-Location @args }
function u { cd .. }
function c { cd ~/code }
function z { zoxide query -i @args | ForEach-Object { Set-Location $_ } }
function zi { zoxide query -i @args | ForEach-Object { Set-Location $_ } }

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
Set-Alias -Name which -Value Get-Command

function ls { Get-ChildItem @args }
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force @args }
function l { Get-ChildItem @args }
function lt { Get-ChildItem -Force @args | Sort-Object LastWriteTime -Descending }
function lsize { Get-ChildItem -Force @args | Sort-Object Length -Descending }
function lrecent { lt @args }

# Python aliases
function pip { uv pip @args }
function pin { uv pip install @args }
function pinu { uv pip install -U @args }
function pfr { uv pip freeze @args }
function pfrr { uv pip freeze > requirements.txt }

# Node.js/Yarn/NPM aliases
if (Test-Path Alias:ni) { Remove-Item Alias:ni -Force }
function ni { npm install $args }
function nig { npm install -g $args }
function nis { npm install --save $args }
function nid { npm install --save-dev $args }
function nu { npm uninstall $args }
function nug { npm uninstall -g $args }
function nrs { npm run start }
function nrt { npm run test }
function nrb { npm run build }
function nrd { npm run dev }
function nls { npm list }
function nlsg { npm list -g --depth=0 }

function yi { yarn install $args }
function ya { yarn add $args }
function yad { yarn add --dev $args }
function yag { yarn global add $args }
function yr { yarn remove $args }
function yrg { yarn global remove $args }
function ys { yarn start }
function yt { yarn test }
function yb { yarn build }
function yd { yarn dev }
function yls { yarn list }
function ylsg { yarn global list }

# Directory usage (like bash usager/usage)
function usager {
    Get-ChildItem | ForEach-Object {
        $size = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse | Measure-Object Length -Sum).Sum
        } else {
            $_.Length
        }
        [PSCustomObject]@{
            Name = $_.Name
            Size = $size
            SizeStr = "{0:N2} MB" -f ($size / 1MB)
        }
    } | Sort-Object Size | Format-Table Name, SizeStr -AutoSize
}

function usage {
    Get-ChildItem -Force | ForEach-Object {
        $size = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse -Force | Measure-Object Length -Sum).Sum
        } else {
            $_.Length
        }
        [PSCustomObject]@{
            Name = $_.Name
            Size = $size
            SizeStr = "{0:N2} MB" -f ($size / 1MB)
        }
    } | Sort-Object Size | Format-Table Name, SizeStr -AutoSize
}

# Archive functions
function compress {
    param($path)
    $name = (Get-Item $path).BaseName
    Compress-Archive -Path $path -DestinationPath "$name.zip"
}

function mktgz {
    param($path)
    $name = (Get-Item $path).BaseName
    tar -czf "$name.tar.gz" $path
}

# Find by name (findn equivalent)
function findn {
    param($pattern)
    Get-ChildItem -Recurse -Filter "*$pattern*" | Select-Object FullName
}

# Simple web server
function webserver {
    param($port = 8080)
    python -m http.server $port
}

# More npm/yarn shortcuts
function pn { pnpm $args }
function yt { yarn test $args }
function yr { yarn remove $args }

# ==========================================
# Claude Code aliases (mirrors bashrc)
# ==========================================
function cld { claude --dangerously-skip-permissions @args }
function cldd { claude --dangerously-skip-permissions @args }
function cla { claude @args }
function cldc { cld --continue @args }
function cldf { cld --continue --fork-session @args }
function cldr { cld --resume @args }
function cldp { cld --print @args }

# Claude review aliases
function cr { claude-review @args }
function creview { claude-review @args }
function crc { claude-review --staged @args }
function crw { claude-review @args }

# Claude Git workflow functions
function cldcmt {
    # Claude commit: stage all, generate commit message, push
    git add -A
    git diff --cached | claude --print "Write a concise commit message for these changes" | ForEach-Object {
        git commit -m $_
    }
}

function cldgcmep {
    # Claude add+commit+push workflow
    git add -A
    $msg = git diff --cached | claude --print "Write a concise commit message for these changes"
    git commit -m $msg
    $branch = git rev-parse --abbrev-ref HEAD
    git push --set-upstream origin $branch
}

function cldfix {
    # Claude fix issues in current changes
    git diff | claude "Fix any issues in these changes"
}

function cldpr {
    # Claude PR generator
    $base = git merge-base HEAD main 2>$null
    if (-not $base) { $base = git merge-base HEAD master 2>$null }
    git diff "$base..HEAD" | claude "Generate a PR title and description for these changes"
}

# Short aliases for Claude Git workflows
function ccmt { cldcmt }
function cgcmep { cldgcmep }
function cfix { cldfix }
function cpr { cldpr }

# Claude + Git diff functions
function cldgdfaa {
    param([string]$prompt)
    if (-not $prompt) {
        Write-Host "Usage: cldgdfaa 'your prompt text'"
        return
    }
    $diff = git diff
    $staged = git diff --cached
    "$prompt`n`nHere are all the changes in the repository:`n`n$diff`n$staged" | claude
}

function cldgdf {
    param([string]$prompt)
    if (-not $prompt) {
        Write-Host "Usage: cldgdf 'your prompt text'"
        return
    }
    $diff = git diff
    "$prompt`n`nHere are the unstaged changes:`n`n$diff" | claude
}

# ==========================================
# Codex CLI aliases
# ==========================================
$script:CodexLocalCandidates = @(
    "$HOME\code\codex-infinity\codex-rs\target\release\codex.exe",
    "$HOME\code\codex\codex-rs\target\release\codex.exe",
    "$HOME\code\codex-infinity\codex-rs\target\release\codex",
    "$HOME\code\codex\codex-rs\target\release\codex"
)

function Get-CodexLocal {
    foreach ($candidate in $script:CodexLocalCandidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Invoke-CodexLocal {
    param([string[]]$CodexArgs)
    $codexLocal = Get-CodexLocal
    if ($codexLocal) {
        & $codexLocal @CodexArgs
        return
    }
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        codex @CodexArgs
        return
    }
    Write-Host "Codex not found. Install codex or build local Codex under ~/code/codex-infinity or ~/code/codex." -ForegroundColor Yellow
}

function Invoke-CodexUpstream {
    param([string[]]$CodexArgs)
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        codex @CodexArgs
        return
    }
    Write-Host "OpenAI Codex not found. Install with: npm install -g @openai/codex" -ForegroundColor Yellow
}

function Invoke-CodexModel {
    param(
        [string]$Model,
        [string]$ReasoningEffort,
        [string[]]$CodexArgs = @()
    )
    Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "-m", $Model, "--config", "model_reasoning_effort=$ReasoningEffort") + $CodexArgs)
}

function cx { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox") + $args) }
function cxi { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--auto-next-idea") + $args) }
function cxn { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--auto-next-steps") + $args) }
function cxl { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--config", "model_reasoning_effort=low") + $args) }
function cxm { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--config", "model_reasoning_effort=medium") + $args) }
function cxh { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--config", "model_reasoning_effort=high") + $args) }
function cxxh { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--config", "model_reasoning_effort=xhigh") + $args) }
function cxf { Invoke-CodexLocal (@("--dangerously-bypass-approvals-and-sandbox", "--config", "model_reasoning_effort=high", "--full-auto") + $args) }
function cxll { Invoke-CodexModel -Model "gpt-5.6-luna" -ReasoningEffort "low" -CodexArgs $args }
function cxlm { Invoke-CodexModel -Model "gpt-5.6-luna" -ReasoningEffort "medium" -CodexArgs $args }
function cxlh { Invoke-CodexModel -Model "gpt-5.6-luna" -ReasoningEffort "high" -CodexArgs $args }
function cxsl { Invoke-CodexModel -Model "gpt-5.6-sol" -ReasoningEffort "low" -CodexArgs $args }
function cxt { Invoke-CodexModel -Model "gpt-5.6-terra" -ReasoningEffort "xhigh" -CodexArgs $args }
function cxtl { Invoke-CodexModel -Model "gpt-5.6-terra" -ReasoningEffort "low" -CodexArgs $args }
function cxtm { Invoke-CodexModel -Model "gpt-5.6-terra" -ReasoningEffort "medium" -CodexArgs $args }
function cxth { Invoke-CodexModel -Model "gpt-5.6-terra" -ReasoningEffort "high" -CodexArgs $args }
function ccxt { Invoke-CodexUpstream (@("--dangerously-bypass-approvals-and-sandbox", "-m", "gpt-5.6-terra", "--config", "model_reasoning_effort=xhigh") + $args) }
function ccxtl { Invoke-CodexUpstream (@("--dangerously-bypass-approvals-and-sandbox", "-m", "gpt-5.6-terra", "--config", "model_reasoning_effort=low") + $args) }
function ccxtm { Invoke-CodexUpstream (@("--dangerously-bypass-approvals-and-sandbox", "-m", "gpt-5.6-terra", "--config", "model_reasoning_effort=medium") + $args) }
function ccxth { Invoke-CodexUpstream (@("--dangerously-bypass-approvals-and-sandbox", "-m", "gpt-5.6-terra", "--config", "model_reasoning_effort=high") + $args) }
function cxbuild {
    $codexDir = if (Test-Path "$HOME\code\codex-infinity\codex-rs") { "$HOME\code\codex-infinity" } elseif (Test-Path "$HOME\code\codex\codex-rs") { "$HOME\code\codex" } else { $null }
    if (-not $codexDir) {
        Write-Host "No local Codex checkout found under ~/code/codex-infinity or ~/code/codex" -ForegroundColor Yellow
        return
    }
    Push-Location $codexDir
    try { cargo build --release -p codex } finally { Pop-Location }
}

function cxa { codex --auto-edit @args }
function cdx { codex @args }
function cdxd { codex --dangerously-bypass-approvals-and-sandbox @args }
function cdxf { codex --full-auto @args }
function cdxr { codex --sandbox read-only @args }
function cdxw { codex --sandbox workspace-write @args }
function cdxa { codex apply @args }
function cdxe { codex exec @args }
function cdxs { codex --search @args }
function cdxed { codex exec --dangerously-bypass-approvals-and-sandbox @args }

# Tooling parity helpers
function btop {
    $btopWin = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\aristocratos.btop4win_Microsoft.Winget.Source_8wekyb3d8bbwe\btop4win\btop4win.exe"
    if (Test-Path $btopWin) {
        & $btopWin @args
    } else {
        Write-Host "btop4win is not installed." -ForegroundColor Yellow
    }
}
function bt { btop @args }
function dtop { dua interactive @args }
function bench { hyperfine @args }
function http { xh @args }
function topc {
    if (Get-Command btop -ErrorAction SilentlyContinue) {
        btop @args
    } else {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 30
    }
}
function tx { tmux attach @args }
function tls { tmux ls @args }
function tn { tmux new -s @args }
function lg { lazygit @args }

# IP address functions
function my-ip {
    (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing).Content.Trim()
}

function local-ip {
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object IPAddress, InterfaceAlias
}

# Enhanced pip with uv (Python package installer and resolver)
function piuv { uv pip install $args }
function pinuv { uv pip install $args }
function piuvg { uv tool install $args }
function puvg { uv tool install $args }
function uvls { uv tool list }
function uvun { uv tool uninstall $args }

# Goat Simulator saves
function Get-GoatSaveRoots {
    @(
        @{ Name = "Goat2"; Path = "$env:LOCALAPPDATA\Goat2\Saved" },
        @{ Name = "Goatsim_UE4"; Path = "$env:LOCALAPPDATA\Goatsim_UE4\Saved" },
        @{ Name = "CoffeeStainStudios.GoatSimulator3PC_496a1srhmar9w"; Path = "$env:LOCALAPPDATA\Packages\CoffeeStainStudios.GoatSimulator3PC_496a1srhmar9w\SystemAppData" },
        @{ Name = "CoffeeStainStudios.364399A20F4FD_496a1srhmar9w"; Path = "$env:LOCALAPPDATA\Packages\CoffeeStainStudios.364399A20F4FD_496a1srhmar9w\SystemAppData" },
        @{ Name = "CoffeeStainStudios.56359B5191BB3_496a1srhmar9w"; Path = "$env:LOCALAPPDATA\Packages\CoffeeStainStudios.56359B5191BB3_496a1srhmar9w\SystemAppData" }
    ) | Where-Object { Test-Path $_.Path }
}

function Get-GoatSavePaths {
    Get-GoatSaveRoots | ForEach-Object { $_.Path }
}

function goat-save-status {
    $paths = Get-GoatSavePaths
    if (-not $paths) {
        Write-Host "No Goat Simulator save roots found under AppData\\Local." -ForegroundColor Yellow
        return
    }
    $rows = @()
    foreach ($path in $paths) {
        $files = Get-ChildItem -Path $path -Recurse -Force -File -ErrorAction SilentlyContinue
        $latest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $rows += [PSCustomObject]@{
            Path = $path
            Files = @($files).Count
            LatestWrite = if ($latest) { $latest.LastWriteTime } else { $null }
            LatestFile = if ($latest) { $latest.FullName } else { $null }
        }
    }
    $rows | Format-Table -AutoSize
}

function goat-save-backup {
    param([string]$Destination = "$HOME\Games\Backups\goat-simulator")
    $roots = Get-GoatSaveRoots
    if (-not $roots) {
        Write-Host "No Goat Simulator save roots found to back up." -ForegroundColor Yellow
        return
    }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $Destination $stamp
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    foreach ($root in $roots) {
        $target = Join-Path $backupRoot $root.Name
        Copy-Item -Path $root.Path -Destination $target -Recurse -Force
    }
    Write-Host "Backed up Goat Simulator saves to: $backupRoot" -ForegroundColor Green
}

function goat-save-restore {
    param([Parameter(Mandatory = $true)][string]$BackupPath)
    if (-not (Test-Path $BackupPath)) {
        Write-Host "Backup path not found: $BackupPath" -ForegroundColor Red
        return
    }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safetyBackup = "$HOME\Games\Backups\goat-simulator\pre-restore-$stamp"
    goat-save-backup $safetyBackup

    foreach ($root in (Get-GoatSaveRoots)) {
        $source = Join-Path $BackupPath $root.Name
        if (Test-Path $source) {
            if (Test-Path $root.Path) {
                Remove-Item -LiteralPath $root.Path -Recurse -Force
            }
            New-Item -ItemType Directory -Path (Split-Path $root.Path -Parent) -Force | Out-Null
            Copy-Item -Path $source -Destination $root.Path -Recurse -Force
            Write-Host "Restored $($root.Name) -> $($root.Path)" -ForegroundColor Green
        }
    }
}

function goats { goat-save-status }
function goatb { goat-save-backup @args }
function goatr { goat-save-restore @args }

# Alias management functions
function ali {
    param($aliasDefinition)
    Add-Content -Path $PROFILE -Value "Set-Alias -Name $aliasDefinition"
    . $PROFILE
    Write-Host "Added alias: $aliasDefinition" -ForegroundColor Green
}

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
$env:EDITOR = "nvim"
$env:GIT_EDITOR = "nvim"
$env:VISUAL = "nvim"

# PATH Configuration - Add common development tool paths
$pathsToAdd = @(
    # uv (Python package installer)
    "$env:USERPROFILE\.local\bin",
    # WinGet command shims
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
    # Node.js global modules
    "$env:APPDATA\npm",
    # Yarn global binaries
    "$env:LOCALAPPDATA\Yarn\bin",
    # Python Scripts (if using Python)
    "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts",
    "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts",
    "$env:LOCALAPPDATA\Programs\Python\Python310\Scripts",
    # Chocolatey tools
    "$env:ALLUSERSPROFILE\chocolatey\bin",
    # Windows Kits (for development tools)
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64",
    # Git (in case it's not in PATH)
    "${env:ProgramFiles}\Git\bin",
    # Additional common paths
    "$env:USERPROFILE\.cargo\bin",
    "$env:USERPROFILE\go\bin",
    # btop4win package layout does not always expose a working shim
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\aristocratos.btop4win_Microsoft.Winget.Source_8wekyb3d8bbwe\btop4win"
)

# Add paths to current session PATH if they exist and aren't already there
foreach ($path in $pathsToAdd) {
    if ((Test-Path $path) -and ($env:PATH -notlike "*$path*")) {
        $env:PATH = "$path;$env:PATH"
    }
}

# Node.js environment variables
if (Get-Command node -ErrorAction SilentlyContinue) {
    $env:NODE_PATH = "$env:APPDATA\npm\node_modules"
}

# Utility functions
function usage {
    Get-ChildItem -Force | ForEach-Object {
        $_.Name + " " + [math]::Round((Get-ChildItem $_.FullName -Recurse | Measure-Object Length -Sum).Sum / 1MB, 2) + " MB"
    } | Sort-Object
}

# Directory usage (like bash usager/usage)
function usager {
    Get-ChildItem | ForEach-Object {
        $size = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse | Measure-Object Length -Sum).Sum
        } else {
            $_.Length
        }
        [PSCustomObject]@{
            Name = $_.Name
            Size = $size
            SizeStr = "{0:N2} MB" -f ($size / 1MB)
        }
    } | Sort-Object Size | Format-Table Name, SizeStr -AutoSize
}

function pkill {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )

    $pattern = [regex]::Escape($Name)
    $matches = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match $pattern }

    if (-not $matches) {
        Write-Host "No process matched '$Name'." -ForegroundColor Yellow
        return
    }

    $matches | ForEach-Object {
        Write-Host ("Killing {0} ({1})" -f $_.ProcessName, $_.Id) -ForegroundColor Cyan
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
}

function memtop {
    param([int]$Count = 20)

    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First $Count Id, ProcessName,
            @{Name = "RAM_MB"; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 1) }},
            @{Name = "CPU_s"; Expression = { [math]::Round($_.CPU, 1) }} |
        Format-Table -AutoSize
}

function kill-heavy-browsers {
    $names = @("chrome", "msedge", "firefox", "claude")
    foreach ($name in $names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Get-Process -Name $names -ErrorAction SilentlyContinue |
        Select-Object Id, ProcessName,
            @{Name = "RAM_MB"; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 1) }} |
        Format-Table -AutoSize
}

function reswap {
    $os = Get-CimInstance Win32_OperatingSystem
    $page = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        RAM_Total_GB       = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        RAM_Free_GB        = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        Virtual_Total_GB   = [math]::Round($os.TotalVirtualMemorySize / 1MB, 2)
        Virtual_Free_GB    = [math]::Round($os.FreeVirtualMemory / 1MB, 2)
        Pagefile_Path      = ($page | Select-Object -ExpandProperty Name) -join ", "
        Pagefile_Used_MB   = ($page | Measure-Object CurrentUsage -Sum).Sum
        Pagefile_Peak_MB   = ($page | Measure-Object PeakUsage -Sum).Sum
    }
}

function vim { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function vi { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function nvim { & "C:\Program Files\Neovim\bin\nvim.exe" $args }
function n { nvim @args }

# Open in Windows File Explorer (cross-platform parity with bash 'o'/'oo')
function o {
    param($Path = ".")
    explorer.exe $Path
}
function oo {
    param($Path = ".")
    explorer.exe $Path
}

# Environment management
function reload {
    Write-Host "Reloading PowerShell profile..." -ForegroundColor Cyan
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

function refresh-env {
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "Environment refreshed!" -ForegroundColor Green
}

function check-tools {
    $tools = @("node", "npm", "yarn", "git", "gh", "claude", "codex", "code", "nvim", "python", "uv", "fzf", "bun", "rg", "fd", "bat", "eza", "delta", "jq", "yq", "zoxide", "btop", "tmux", "lazygit", "sshpass", "dust", "hyperfine", "procs", "sd", "xh", "tokei")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "[OK] $tool" -ForegroundColor Green
        } else {
            Write-Host "[--] $tool" -ForegroundColor Red
        }
    }
}

function check-optional-tools {
    $tools = @("gitui", "difft", "dua", "btm")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "[OK] $tool" -ForegroundColor Green
        } else {
            Write-Host "[optional] $tool" -ForegroundColor Yellow
        }
    }
}

# FZF-like functionality (if fzf is available)
function fe {
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        $file = Get-ChildItem -Recurse -File | ForEach-Object { $_.FullName } | fzf
        if ($file) { & $env:EDITOR $file }
    } else {
        Write-Host "fzf not installed. Install with: choco install fzf" -ForegroundColor Yellow
    }
}

function fd {
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        $dir = Get-ChildItem -Recurse -Directory | ForEach-Object { $_.FullName } | fzf
        if ($dir) { Set-Location $dir }
    } else {
        Write-Host "fzf not installed. Install with: choco install fzf" -ForegroundColor Yellow
    }
}

# Clipboard functions (Windows native)
function pbcopy {
    $input | Set-Clipboard
}

function pbpaste {
    Get-Clipboard
}

# Enhanced ls with git status (if in git repo)
function lsg {
    Get-ChildItem
    if (git rev-parse --git-dir 2>$null) {
        Write-Host ""
        Write-Host 'Git Status:' -ForegroundColor Cyan
        git status --porcelain
    }
}


# Import modules - make conditional to avoid errors
if (Get-Module -ListAvailable -Name posh-git) {
    Import-Module posh-git
}

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# PSFzf - only import if fzf binary is available
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    if (Get-Module -ListAvailable -Name PSFzf) {
        Import-Module PSFzf
        # FZF config
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
} else {
    Write-Host "Note: fzf not found in PATH. Install with: choco install fzf" -ForegroundColor Yellow
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Better tab completion
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete 
