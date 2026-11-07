# ssh-unlock-once.ps1 - load SSH keys into the Windows OpenSSH agent.
# Used by the DotfilesSshUnlock logon task, so keys are ready before the first
# terminal (or IDE) starts.
. (Join-Path $PSScriptRoot 'ssh-unlock.ps1')
Initialize-SshKeys
