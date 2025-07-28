@echo off
echo Installing PowerShell profile...

set "PROFILE_DIR=%USERPROFILE%\OneDrive - Microsoft\Documents\WindowsPowerShell"
set "PROFILE_PATH=%PROFILE_DIR%\Microsoft.PowerShell_profile.ps1"

if not exist "%PROFILE_DIR%" mkdir "%PROFILE_DIR%"

copy minimal.ps1 "%PROFILE_PATH%"

echo Profile installed successfully!
echo Location: %PROFILE_PATH%
echo.
echo Test it by opening PowerShell and running: usager 