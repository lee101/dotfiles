# gpu-recover.ps1 - Windows NVIDIA GPU auto-recovery, same ladder as gpu-recover.sh.
# Reboot only after failure persists $RebootAfterSecs, never within $MinUptimeSecs of boot,
# max one auto-reboot per $CooldownSecs. Run as admin (scheduled task, every 5 min):
#   schtasks /create /tn gpu-recover /sc minute /mo 5 /ru SYSTEM /tr "powershell -ExecutionPolicy Bypass -File C:\tools\gpu-recover.ps1"
param(
    [int]$RebootAfterSecs = 3600,
    [int]$MinUptimeSecs = 3600,
    [int]$CooldownSecs = 21600,
    [switch]$NoReboot
)
$StateDir = "$env:ProgramData\gpu-recover"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
function Log($m) { "$([DateTime]::Now.ToString('s')) $m" | Tee-Object -Append "$StateDir\log"; }
function GpuOk {
    try { $p = Start-Process nvidia-smi -NoNewWindow -PassThru -Wait -RedirectStandardOutput NUL -ErrorAction Stop
          return ($p.ExitCode -eq 0) } catch { return $false }
}

if (GpuOk) { Remove-Item "$StateDir\first_failure" -ErrorAction SilentlyContinue; exit 0 }

$now = [int][double]::Parse((Get-Date -UFormat %s))
if (-not (Test-Path "$StateDir\first_failure")) { $now | Set-Content "$StateDir\first_failure"; Log "nvidia-smi failed; starting recovery" }
$first = [int](Get-Content "$StateDir\first_failure")

# diagnostics
Get-WinEvent -LogName System -MaxEvents 200 | Where-Object { $_.Message -match 'nvlddmkm|Display driver' } |
    Format-List TimeCreated, Message | Out-File "$StateDir\diag-$(Get-Date -Format yyyyMMdd-HHmmss).log"

# stage 1: wait + retry
Start-Sleep 10
if (GpuOk) { Log "recovered after wait"; Remove-Item "$StateDir\first_failure"; exit 0 }

# stage 2: restart the display adapter device (equivalent of driver reload)
$gpus = Get-PnpDevice -Class Display -Status OK,Error,Degraded,Unknown -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'NVIDIA' }
foreach ($g in $gpus) {
    Log "disable/enable $($g.InstanceId)"
    Disable-PnpDevice -InstanceId $g.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep 5
    Enable-PnpDevice -InstanceId $g.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
}
Start-Sleep 10
if (GpuOk) { Log "recovered via device restart"; Remove-Item "$StateDir\first_failure"; exit 0 }

# stage 3: restart NVIDIA services
Get-Service | Where-Object { $_.Name -match 'NVDisplay|nvagent' } | Restart-Service -Force -ErrorAction SilentlyContinue
Start-Sleep 10
if (GpuOk) { Log "recovered via service restart"; Remove-Item "$StateDir\first_failure"; exit 0 }

# stage 4: guarded reboot
$uptime = [int]((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalSeconds
$lastReboot = if (Test-Path "$StateDir\last_auto_reboot") { [int](Get-Content "$StateDir\last_auto_reboot") } else { 0 }
$elapsed = $now - $first
if ($NoReboot) { Log "still dead; reboot disabled" }
elseif ($elapsed -lt $RebootAfterSecs) { Log "still dead ${elapsed}s; reboot only after ${RebootAfterSecs}s" }
elseif ($uptime -lt $MinUptimeSecs) { Log "uptime ${uptime}s too low; refusing reboot (anti-bootloop)" }
elseif (($now - $lastReboot) -lt $CooldownSecs) { Log "cooldown; refusing reboot" }
else {
    Log "all stages failed; REBOOTING in 60s"
    $now | Set-Content "$StateDir\last_auto_reboot"
    Remove-Item "$StateDir\first_failure" -ErrorAction SilentlyContinue
    Start-Sleep 60
    Restart-Computer -Force
}
exit 1
