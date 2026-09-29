@echo off
setlocal
set "DOTFILES_ROOT=%~dp0.."

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    py -3 "%DOTFILES_ROOT%\profiling\profile_md.py" %*
    exit /b
)

where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    python "%DOTFILES_ROOT%\profiling\profile_md.py" %*
    exit /b
)

echo profile-md: Python 3 was not found in PATH. 1>&2
exit /b 2
