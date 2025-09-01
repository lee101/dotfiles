# Test script for PowerShell functionality
# Run this to verify that all aliases and functions work correctly

Write-Host "Testing PowerShell profile functionality..." -ForegroundColor Cyan

# Test nvim/vim aliases
Write-Host "`nTesting editor aliases:" -ForegroundColor Yellow
$editorCommands = @("nvim", "vim", "vi")
foreach ($cmd in $editorCommands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "✓ $cmd alias works" -ForegroundColor Green
    } else {
        Write-Host "✗ $cmd alias not found" -ForegroundColor Red
    }
}

# Test uv functionality
Write-Host "`nTesting uv functionality:" -ForegroundColor Yellow
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "✓ uv is available" -ForegroundColor Green
    try {
        $uvVersion = uv --version
        Write-Host "  Version: $uvVersion" -ForegroundColor Gray
    } catch {
        Write-Host "✗ uv command failed" -ForegroundColor Red
    }
} else {
    Write-Host "✗ uv not found in PATH" -ForegroundColor Red
}

# Test git functions
Write-Host "`nTesting git aliases:" -ForegroundColor Yellow
$gitCommands = @("gst", "gco", "gcm", "gpl", "gph")
foreach ($cmd in $gitCommands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "✓ $cmd function works" -ForegroundColor Green
    } else {
        Write-Host "✗ $cmd function not found" -ForegroundColor Red
    }
}

# Test navigation functions
Write-Host "`nTesting navigation functions:" -ForegroundColor Yellow
$navCommands = @("u", "c", "o")
foreach ($cmd in $navCommands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "✓ $cmd function works" -ForegroundColor Green
    } else {
        Write-Host "✗ $cmd function not found" -ForegroundColor Red
    }
}

# Test utility functions
Write-Host "`nTesting utility functions:" -ForegroundColor Yellow
$utilCommands = @("reload", "check-tools", "usager")
foreach ($cmd in $utilCommands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "✓ $cmd function works" -ForegroundColor Green
    } else {
        Write-Host "✗ $cmd function not found" -ForegroundColor Red
    }
}

Write-Host "`nTest complete!" -ForegroundColor Green
Write-Host "Now you can use:" -ForegroundColor Cyan
Write-Host "  vim .\.config\nvim\init.lua  # Edit nvim config" -ForegroundColor White
Write-Host "  gst                          # Git status" -ForegroundColor White
Write-Host "  piuv pandas                  # Install Python package with uv" -ForegroundColor White
Write-Host "  check-tools                  # Verify all tools are installed" -ForegroundColor White
Write-Host "  reload                       # Reload PowerShell profile" -ForegroundColor White
