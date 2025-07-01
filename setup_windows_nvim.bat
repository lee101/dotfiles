@echo off
echo Setting up Windows nvim configuration...

REM Check if nvim is installed
where nvim >nul 2>&1
if %errorlevel% neq 0 (
    echo nvim not found in PATH. Installing via winget...
    winget install Neovim.Neovim
    echo Please restart your terminal after installation.
    pause
    exit /b 1
)

echo nvim found: 
where nvim

REM Create config directory
if not exist "%USERPROFILE%\.config\nvim" (
    mkdir "%USERPROFILE%\.config\nvim"
    echo Created nvim config directory
)

REM Create symlink to dotfiles (run as admin if needed)
echo Creating symlink to dotfiles...
mklink /D "%USERPROFILE%\.config\nvim" "C:\Users\%USERNAME%\code\dotfiles\.config\nvim" >nul 2>&1
if %errorlevel% neq 0 (
    echo Failed to create symlink. Trying alternative method...
    xcopy "C:\Users\%USERNAME%\code\dotfiles\.config\nvim\*" "%USERPROFILE%\.config\nvim\" /E /I /Y
    echo Copied config files instead of symlink
)

echo.
echo Windows nvim setup complete!
echo.
echo To test:
echo 1. Open Git Bash
echo 2. Run: nvim --version
echo 3. Run: nvim test.lua
echo.
pause 