# ssh-unlock.ps1 - load passphrase-protected keys into the Windows OpenSSH agent.
#
# Dot-sourced from windows/profile.ps1. The passphrase comes from SSH_KEY_PW or
# from the gitignored ~/.secretbashrc. Nothing secret is stored in this file.
#
# Windows OpenSSH binaries are preferred over Git for Windows' MSYS build:
# MSYS ssh cannot talk to the Windows agent's named pipe.

$script:OpenSshDir = Join-Path $env:SystemRoot 'System32\OpenSSH'
$script:SshAdd = Join-Path $script:OpenSshDir 'ssh-add.exe'
$script:SshKeygen = Join-Path $script:OpenSshDir 'ssh-keygen.exe'
$script:SshAskPass = Join-Path $PSScriptRoot 'bin\ssh-askpass.cmd'
$script:SshAgentSock = '\\.\pipe\openssh-ssh-agent'

function Set-SshEnvironment {
    if (-not (Test-Path $script:OpenSshDir)) { return }

    # Put native OpenSSH ahead of Git's MSYS ssh/ssh-add.
    $parts = @($env:PATH -split ';' |
        Where-Object { $_ -and ($_ -ine $script:OpenSshDir) })
    $env:PATH = (@($script:OpenSshDir) + $parts) -join ';'

    # A stale MSYS socket makes native ssh-add fail with "No such file or
    # directory". Native Windows OpenSSH understands the named pipe.
    $env:SSH_AUTH_SOCK = $script:SshAgentSock

    # Override any inherited GIT_SSH_COMMAND that points git at MSYS ssh.
    # Forward slashes: git runs the command through sh, which eats backslashes.
    $env:GIT_SSH_COMMAND = (Join-Path $script:OpenSshDir 'ssh.exe') -replace '\\', '/'
}

function Get-SshKeyPassphrase {
    if ($env:SSH_KEY_PW) { return $env:SSH_KEY_PW }

    $f = Join-Path $HOME '.secretbashrc'
    if (Test-Path $f) {
        $m = Select-String -Path $f `
            -Pattern '^\s*(?:export\s+)?SSH_KEY_PW=[''"]?([^''"\r\n]+)' |
            Select-Object -First 1
        if ($m) { return $m.Matches[0].Groups[1].Value }
    }
    return $null
}

function Test-SshKeyLoaded {
    param([Parameter(Mandatory = $true)][string]$KeyPath)

    $pub = "$KeyPath.pub"
    if (-not (Test-Path $pub)) { return $false }

    $line = & $script:SshKeygen -lf $pub 2>$null | Select-Object -First 1
    if (-not $line) { return $false }
    $fp = ($line -split '\s+')[1]
    if (-not $fp) { return $false }

    $loaded = & $script:SshAdd -l 2>&1 | Out-String
    return $loaded.Contains($fp)
}

function Initialize-SshKeys {
    if (-not (Test-Path $script:SshAdd)) { return }

    $svc = Get-Service ssh-agent -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Running') {
        try {
            if ($svc.StartType -ne 'Automatic') {
                Set-Service ssh-agent -StartupType Automatic -ErrorAction Stop
            }
            Start-Service ssh-agent -ErrorAction Stop
        } catch {
            return
        }
    }

    $pw = Get-SshKeyPassphrase
    if (-not $pw) { return }
    if (-not (Test-Path $script:SshAskPass)) { return }

    $saved = @{}
    foreach ($n in 'SSH_KEY_PW', 'SSH_ASKPASS', 'SSH_ASKPASS_REQUIRE', 'DISPLAY') {
        $saved[$n] = [Environment]::GetEnvironmentVariable($n)
    }

    $env:SSH_AUTH_SOCK = $script:SshAgentSock
    $env:SSH_KEY_PW = $pw
    $env:SSH_ASKPASS = $script:SshAskPass
    $env:SSH_ASKPASS_REQUIRE = 'force'
    $env:DISPLAY = 'x'

    try {
        foreach ($name in 'id_ed25519', 'id_rsa') {
            $key = Join-Path $HOME ".ssh\$name"
            if (-not (Test-Path $key)) { continue }
            if (Test-SshKeyLoaded $key) { continue }
            & $script:SshAdd $key *> $null
        }
    } finally {
        foreach ($n in $saved.Keys) {
            [Environment]::SetEnvironmentVariable($n, $saved[$n])
        }
        # Deliberately do not restore a stale MSYS socket.
        $env:SSH_AUTH_SOCK = $script:SshAgentSock
    }
}

function ssh-reload { Initialize-SshKeys; & $script:SshAdd -l }
function ssh-list { & $script:SshAdd -l }
function ssh-clear { & $script:SshAdd -D }

Set-SshEnvironment
