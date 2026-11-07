# Windows counterpart to linux-setup.sh.
# Installs the everyday CLI toolset that the Linux script provides (rsync, jj,
# helix, imagemagick, wget, nasm, ...) and skips anything already on PATH.
# Safe to re-run. No admin needed for winget per-user installs; MSYS2 installs
# to C:\msys64 and may prompt for UAC.
#
# Usage: powershell -ExecutionPolicy Bypass -File .\setup-windows-tools.ps1

$ErrorActionPreference = 'Continue'

function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

function Install-WingetTool {
    param([string]$Id, [string]$Command, [string]$Name, [string]$Fallback = '')
    # -CommandType Application: PowerShell aliases (e.g. wget -> Invoke-WebRequest) must not count.
    if ($Command -and (Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Host "  [skip]    $Name" -ForegroundColor DarkGray
        return
    }
    Write-Host "  [install] $Name ($Id)" -ForegroundColor Yellow
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        # -1978335189 = already installed / no upgrade available
        Write-Warning "winget exited $LASTEXITCODE for $Name"
        if ($Fallback -and (Get-Command scoop -CommandType Application -ErrorAction SilentlyContinue)) {
            Write-Host "  [retry]   $Name via scoop ($Fallback)" -ForegroundColor Yellow
            scoop install $Fallback
        }
    }
}

Write-Step 'Winget tools'
$tools = @(
    @{ Id = 'jj-vcs.jj';                Cmd = 'jj';      Name = 'Jujutsu (jj)' },
    @{ Id = 'Helix.Helix';              Cmd = 'hx';      Name = 'Helix editor' },
    @{ Id = 'ImageMagick.ImageMagick';  Cmd = 'magick';  Name = 'ImageMagick'; Fallback = 'imagemagick' },
    @{ Id = 'JernejSimoncic.Wget';      Cmd = 'wget';    Name = 'wget' },
    @{ Id = 'NASM.NASM';                Cmd = 'nasm';    Name = 'NASM' },
    @{ Id = 'Cloudflare.cloudflared';   Cmd = 'cloudflared'; Name = 'cloudflared' },
    @{ Id = 'MSYS2.MSYS2';              Cmd = '';        Name = 'MSYS2 (provides rsync)' }
)
foreach ($t in $tools) {
    if ($t.Id -eq 'MSYS2.MSYS2') {
        if (Test-Path 'C:\msys64\usr\bin\bash.exe') {
            Write-Host "  [skip]    $($t.Name)" -ForegroundColor DarkGray
        } else {
            Install-WingetTool -Id $t.Id -Command $t.Cmd -Name $t.Name
        }
    } else {
        Install-WingetTool -Id $t.Id -Command $t.Cmd -Name $t.Name -Fallback $t.Fallback
    }
}

Write-Step 'rsync (MSYS2 build)'
$msysBash = 'C:\msys64\usr\bin\bash.exe'
$msysRsync = 'C:\msys64\usr\bin\rsync.exe'
if (Test-Path $msysRsync) {
    Write-Host "  [skip]    rsync already in MSYS2" -ForegroundColor DarkGray
} elseif (Test-Path $msysBash) {
    Write-Host "  [install] rsync via pacman" -ForegroundColor Yellow
    & $msysBash -lc 'pacman -Sy --needed --noconfirm rsync openssh'
    if (-not (Test-Path $msysRsync)) {
        Write-Warning "rsync not found after pacman. Open an MSYS2 shell and run: pacman -Syu  then  pacman -S rsync"
    }
} else {
    Write-Warning "MSYS2 not found at C:\msys64; skipping rsync."
}

Write-Step 'rsync shims in ~/bin'
$binDir = Join-Path $HOME 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# Git Bash: extensionless sh script (bash does not run .cmd files).
# Uses /c/... paths; rsync treats C:\... as host:path.
# Uses MSYS2 ssh: the native Windows ssh.exe breaks rsync's pipes.
# Keys need an unlocked agent: run ssh-add under MSYS2 once per session.
$shShim = @'
#!/bin/sh
# rsync from MSYS2 (set up by setup-windows-tools.ps1). Use /c/... paths here.
export HOME=/c/Users/lee_p
export RSYNC_RSH=/c/msys64/usr/bin/ssh.exe
exec /c/msys64/usr/bin/rsync.exe "$@"
'@

# PowerShell / cmd: .cmd shim.
$cmdShim = @'
@echo off
rem rsync from MSYS2 (set up by setup-windows-tools.ps1). Use /c/... paths; C:\ paths are read as host:path.
rem Uses MSYS2 ssh (native Windows ssh.exe breaks rsync pipes). Keys need an unlocked agent.
set "HOME=C:\Users\lee_p"
set "RSYNC_RSH=/c/msys64/usr/bin/ssh.exe"
"C:\msys64\usr\bin\rsync.exe" %*
'@

if (Test-Path 'C:\msys64\usr\bin\rsync.exe') {
    $shPath = Join-Path $binDir 'rsync'
    $cmdPath = Join-Path $binDir 'rsync.cmd'
    $shText = $shShim -replace "`r`n", "`n"
    if (-not (Test-Path $shPath) -or (Get-Content $shPath -Raw) -ne $shText) {
        [System.IO.File]::WriteAllText($shPath, $shText, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  [write]   $shPath" -ForegroundColor Yellow
    } else {
        Write-Host "  [skip]    $shPath" -ForegroundColor DarkGray
    }
    if (-not (Test-Path $cmdPath) -or (Get-Content $cmdPath -Raw) -ne ($cmdShim -replace "`r`n", "`r`n")) {
        Set-Content -Path $cmdPath -Value $cmdShim -Encoding ASCII
        Write-Host "  [write]   $cmdPath" -ForegroundColor Yellow
    } else {
        Write-Host "  [skip]    $cmdPath" -ForegroundColor DarkGray
    }
} else {
    Write-Warning "Skipping rsync shims: rsync.exe missing."
}

Write-Step 'Done'
Write-Host "Open a new terminal so PATH picks up new tools, then check:" -ForegroundColor Green
Write-Host "  jj --version; hx --version; magick -version; rsync --version; wget --version"
