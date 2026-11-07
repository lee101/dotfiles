# install-ssh-unlock-task.ps1 - register a per-user logon task that unlocks
# SSH keys into the Windows OpenSSH agent before any terminal or IDE starts.
#
# Run once:  powershell -NoProfile -ExecutionPolicy Bypass -File windows\install-ssh-unlock-task.ps1
# Remove:    Unregister-ScheduledTask -TaskName DotfilesSshUnlock -Confirm:$false

$taskName = 'DotfilesSshUnlock'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$unlock = Join-Path $PSScriptRoot 'ssh-unlock-once.ps1'

$action = New-ScheduledTaskAction `
    -Execute $powershell `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$unlock`"" `
    -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Unlock dotfiles SSH keys into the Windows OpenSSH agent at logon.' `
    -Force | Out-Null

Write-Host "Registered scheduled task: $taskName"
