@echo off
echo Setting up Windows nvim configuration (AppData + .config for Git Bash)...

where nvim >nul 2>&1
if %errorlevel% neq 0 (
    echo nvim not found. winget install Neovim.Neovim first.
    pause
    exit /b 1
)

set "DOTFILES=%~dp0"
set "TARGET1=%USERPROFILE%\AppData\Local\nvim"
set "TARGET2=%USERPROFILE%\.config\nvim"

for %%T in ("%TARGET1%" "%TARGET2%") do (
    if not exist "%%~T" mkdir "%%~T" >nul 2>&1
    echo Linking into %%~T ...
    mklink "%%~T\init.lua" "%DOTFILES%init.lua" >nul 2>&1
    mklink /D "%%~T\lua" "%DOTFILES%lua" >nul 2>&1
    if exist "%DOTFILES%nvim" (
        for %%F in ("%DOTFILES%nvim\*") do (
            if /I not "%%~nxF"=="init.lua" if /I not "%%~nxF"=="lua" (
                mklink "%%~T\%%~nxF" "%%~F" >nul 2>&1
            )
        )
    )
)

echo.
echo Neovim setup done for both PowerShell and Git Bash.
echo Open a new terminal and run "vi" or "nvim".
pause