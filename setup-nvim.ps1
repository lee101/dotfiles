param(
  [switch]$SkipPluginSync,
  [switch]$SkipLanguageServers,
  [switch]$SkipTextGenerator
)
$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path $PSScriptRoot).Path
$Source = Join-Path $Repo 'nvim'
if (-not (Test-Path (Join-Path $Source 'init.lua'))) { throw "Missing canonical Neovim config: $Source" }
function Info($m) { Write-Host "[nvim-setup] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[nvim-setup] $m" -ForegroundColor Yellow }
function Has($name) { return $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }
Info "Using $Source"
if (-not (Has nvim)) { throw 'Neovim is not on PATH. Install it with: winget install Neovim.Neovim' }
if (-not (Has git)) { throw 'Git is not on PATH. Install Git for Windows first.' }
if (-not (Has tree-sitter)) {
  if (Has cargo) {
    Info 'Installing tree-sitter CLI with Cargo'
    & cargo install tree-sitter-cli --locked
  } elseif (Has npm) {
    Warn 'Cargo is unavailable; installing tree-sitter CLI from npm as a fallback'
    & npm install --global tree-sitter-cli
  } else {
    Warn 'tree-sitter CLI is missing. Install Cargo or Node/npm before parser installation.'
  }
}
foreach ($tool in @('rg','fd','fzf','make','cmake','node','npm','python','go','rustc')) {
  if (-not (Has $tool)) { Warn "Optional tool missing: $tool" }
}
$Target = Join-Path $env:LOCALAPPDATA 'nvim'
if ((Test-Path $Target) -and ((Get-Item $Target).FullName -ne $Source)) {
  $backup = "$Target.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
  Info "Backing up existing config to $backup"
  Move-Item -LiteralPath $Target -Destination $backup
}
if (Test-Path $Target) { Remove-Item -LiteralPath $Target -Force }
New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
Info "Linked $Target -> $Source"
$Bin = Join-Path $env:USERPROFILE 'bin'
New-Item -ItemType Directory -Force -Path $Bin | Out-Null
$Vi = Join-Path $Bin 'vi.cmd'
if (-not (Test-Path $Vi)) { "@echo off`r`nnvim %*" | Set-Content -Path $Vi -Encoding ASCII }
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if (($userPath -split ';') -notcontains $Bin) {
  [Environment]::SetEnvironmentVariable('Path', (($userPath.TrimEnd(';') + ';' + $Bin).Trim(';')), 'User')
  Warn "Added $Bin to the user PATH; open a new terminal for vi."
}
if (-not $SkipTextGenerator) {
  $TextDir = if ($env:TEXT_GENERATOR_NVIM_DIR) { $env:TEXT_GENERATOR_NVIM_DIR } else { Join-Path $env:USERPROFILE 'code\text-generator-nvim' }
  if (-not (Test-Path $TextDir) -and $env:TEXT_GENERATOR_NVIM_REPO) {
    Info "Cloning text-generator-nvim from $env:TEXT_GENERATOR_NVIM_REPO"
    git clone $env:TEXT_GENERATOR_NVIM_REPO $TextDir
  } elseif (-not (Test-Path $TextDir)) {
    Warn 'text-generator-nvim not installed. Set TEXT_GENERATOR_NVIM_REPO and rerun to enable it.'
  }
}
if (-not $SkipPluginSync) {
  Info 'Installing/updating Lazy plugins'
  & nvim --headless '+Lazy! sync' '+qa'
  if ($LASTEXITCODE -ne 0) { throw "Lazy sync failed with exit code $LASTEXITCODE" }
  Info 'Installing Tree-sitter parsers'
  $ts = "require('nvim-treesitter').install({ 'bash', 'c', 'cpp', 'css', 'dockerfile', 'go', 'html', 'java', 'javascript', 'json', 'lua', 'markdown', 'php', 'python', 'query', 'regex', 'ruby', 'rust', 'sql', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml' }):wait(300000)"
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & nvim --headless '+Lazy! load nvim-treesitter' ("+lua $ts") '+qa'
  $tsExit = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  if ($tsExit -ne 0) { Warn "Tree-sitter parser installation returned $tsExit; run :TSInstall later." }
}

Info 'Running headless startup check'
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$out = @(& nvim --headless '+checkhealth' '+qa' 2>&1)
$checkExit = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
$out | Select-Object -Last 80
if ($checkExit -ne 0) { throw "Neovim startup check failed with exit code $checkExit" }
Info 'Neovim setup complete. Start with: vi (or nvim)'
