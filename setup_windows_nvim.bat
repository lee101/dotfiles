@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-nvim.ps1" %*
exit /b %errorlevel%
