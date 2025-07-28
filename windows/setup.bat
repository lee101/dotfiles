@echo off
REM Windows PowerShell Profile Setup Batch File
REM This allows Windows users to double-click and run the setup

echo.
echo Windows PowerShell Profile Setup
echo =================================
echo.
echo This will install a PowerShell profile with bash-like aliases and functions.
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause >nul

REM Check if PowerShell is available
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell not found. Please install PowerShell first.
    pause
    exit /b 1
)

REM Run the PowerShell setup script
echo.
echo Starting PowerShell setup...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo Setup complete! Press any key to exit...
pause >nul 