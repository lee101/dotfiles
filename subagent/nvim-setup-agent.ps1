param([switch]$SkipPluginSync, [switch]$SkipTextGenerator)
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $repo 'setup-nvim.ps1') -SkipPluginSync:$SkipPluginSync -SkipTextGenerator:$SkipTextGenerator
exit $LASTEXITCODE
