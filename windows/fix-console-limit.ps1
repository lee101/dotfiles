# fix-console-limit.ps1
# ----------------------------------------------------------------------------
# Fixes the Git Bash / MSYS2 / Cygwin error:
#
#     fatal error - console device allocation failure - too many consoles
#     in use, max consoles is 32
#
# Cygwin/MSYS2 on modern Windows uses the Windows pseudo-console (conpty) API
# for each bash process, and is subject to a hardcoded limit of 32 simultaneous
# pseudo-consoles per session. Setting MSYS=disable_pcon (or CYGWIN=disable_pcon
# for plain Cygwin) disables the conpty path and reverts to the classic
# /dev/pty* behavior, which has no such limit. This lets you open as many
# Git Bash terminals as you want.
#
# This script sets the env vars as USER-level environment variables so every
# new shell/terminal (Git Bash, Windows Terminal, VS Code terminal, etc.)
# inherits the setting. No admin required - it only touches your user env.
#
# Safe to run repeatedly. Idempotent.
# ----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

Write-Host "=== Fixing Git Bash / MSYS2 console limit ===" -ForegroundColor Cyan
Write-Host ""

function Set-UserEnvMerge {
    param(
        [string]$Name,
        [string]$Token
    )

    $existing = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ([string]::IsNullOrWhiteSpace($existing)) {
        $newValue = $Token
    }
    else {
        # Split on whitespace, dedupe, re-join
        $parts = $existing -split '\s+' | Where-Object { $_ -ne '' }
        if ($parts -notcontains $Token) {
            $parts += $Token
        }
        $newValue = ($parts -join ' ').Trim()
    }

    if ($existing -eq $newValue) {
        Write-Host "  $Name already set to '$existing' (no change)" -ForegroundColor DarkGray
    }
    else {
        [Environment]::SetEnvironmentVariable($Name, $newValue, 'User')
        if ([string]::IsNullOrWhiteSpace($existing)) {
            Write-Host "  $Name = '$newValue'  (new)" -ForegroundColor Green
        }
        else {
            Write-Host "  $Name = '$newValue'  (was: '$existing')" -ForegroundColor Yellow
        }
    }
}

Set-UserEnvMerge -Name 'MSYS'   -Token 'disable_pcon'
Set-UserEnvMerge -Name 'CYGWIN' -Token 'disable_pcon'

Write-Host ""
Write-Host "Done. Close and reopen any bash/terminal windows for the change" -ForegroundColor Cyan
Write-Host "to take effect. Already-running shells are not affected." -ForegroundColor Cyan
Write-Host ""
Write-Host "Verify with (in a NEW shell):" -ForegroundColor Gray
Write-Host "  bash -c 'echo MSYS=\$MSYS CYGWIN=\$CYGWIN'" -ForegroundColor Gray
