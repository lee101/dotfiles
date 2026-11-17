#!/bin/bash
# ============================================================
# Windows Git Bash Developer Setup
# ============================================================
# Run this from Git Bash to install dev tools via winget/choco
# and configure them to work in Git Bash.
#
# Prerequisites: Git for Windows (Git Bash), winget, choco
# Usage: bash setup-windows-gitbash.sh

set -e

echo "=== Windows Git Bash Developer Setup ==="

# Verify we're on Windows Git Bash
if [[ "$(uname -s)" != MINGW* ]] && [[ "$(uname -s)" != MSYS* ]]; then
    echo "ERROR: This script is for Windows Git Bash only"
    exit 1
fi

# ============================================================
# Install tools via winget (runs as current user, no admin)
# ============================================================
install_winget() {
    local id="$1"
    local name="$2"
    echo "Installing $name..."
    winget.exe install --id "$id" --accept-source-agreements --accept-package-agreements 2>/dev/null || true
}

echo ""
echo "--- Installing via winget ---"
install_winget "GitHub.cli" "GitHub CLI (gh)"
install_winget "OpenJS.NodeJS.LTS" "Node.js LTS"
install_winget "astral-sh.uv" "uv (Python)"
install_winget "junegunn.fzf" "fzf"
install_winget "sharkdp.bat" "bat"
install_winget "sharkdp.fd" "fd"
install_winget "BurntSushi.ripgrep.MSVC" "ripgrep"
install_winget "dandavison.delta" "delta"
install_winget "eza-community.eza" "eza"
install_winget "jqlang.jq" "jq"
install_winget "JesseDuffield.Lazygit" "lazygit"

# ============================================================
# Link dotfiles
# ============================================================
echo ""
echo "--- Linking dotfiles ---"

DOTFILES="$HOME/code/dotfiles"

# Symlink bashrc if not already linked
if [ ! -L "$HOME/.bashrc" ] || [ "$(readlink -f "$HOME/.bashrc" 2>/dev/null)" != "$(readlink -f "$DOTFILES/bashrc" 2>/dev/null)" ]; then
    [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%s)"
    cp "$DOTFILES/bashrc" "$HOME/.bashrc"
    echo "Copied bashrc to ~/.bashrc"
else
    echo "bashrc already linked"
fi

if [ ! -L "$HOME/.bash_profile" ] || [ "$(readlink -f "$HOME/.bash_profile" 2>/dev/null)" != "$(readlink -f "$DOTFILES/bash_profile" 2>/dev/null)" ]; then
    [ -f "$HOME/.bash_profile" ] && cp "$HOME/.bash_profile" "$HOME/.bash_profile.bak.$(date +%s)"
    cp "$DOTFILES/bash_profile" "$HOME/.bash_profile"
    echo "Copied bash_profile to ~/.bash_profile"
else
    echo "bash_profile already linked"
fi

# Gitconfig
if [ ! -f "$HOME/.gitconfig" ] || ! grep -q "dotfiles" "$HOME/.gitconfig" 2>/dev/null; then
    [ -f "$HOME/.gitconfig" ] && cp "$HOME/.gitconfig" "$HOME/.gitconfig.bak.$(date +%s)"
    cp "$DOTFILES/gitconfig" "$HOME/.gitconfig"
    echo "Copied gitconfig to ~/.gitconfig"
else
    echo "gitconfig already in place"
fi

# Global gitignore
cp "$DOTFILES/gitignore_global" "$HOME/.gitignore_global" 2>/dev/null && echo "Copied gitignore_global"

# ============================================================
# gh auth setup
# ============================================================
echo ""
echo "--- GitHub CLI setup ---"

# Refresh PATH so gh is found
export PATH="/c/Program Files/GitHub CLI:$HOME/AppData/Local/Microsoft/WinGet/Packages/GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
export PATH="/c/Program Files/nodejs:$HOME/AppData/Local/Microsoft/WinGet/Links:$HOME/.bun/bin:$PATH"

if command -v gh.exe >/dev/null 2>&1 || command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        echo "gh: already authenticated"
    else
        echo "Run 'gh auth login' to authenticate with GitHub"
    fi
else
    echo "gh not found on PATH yet - restart your terminal and run 'gh auth login'"
fi

# ============================================================
# Verify installations
# ============================================================
echo ""
echo "--- Verifying tools ---"
for tool in gh delta lazygit fzf eza rg fd jq bat; do
    if command -v "$tool" >/dev/null 2>&1 || command -v "${tool}.exe" >/dev/null 2>&1; then
        echo "  OK: $tool"
    else
        echo "  MISSING: $tool (restart terminal to refresh PATH)"
    fi
done

echo ""
echo "--- Installing OpenCode CLI ---"
if command -v bun >/dev/null 2>&1; then
    bun add -g opencode-ai || true
elif command -v npm >/dev/null 2>&1; then
    npm install -g opencode-ai || true
else
    echo "bun/npm not found yet - install Node.js or Bun, then run: npm install -g opencode-ai"
fi

echo ""
echo "=== Setup complete ==="
echo "Restart your terminal for PATH changes to take effect."
echo "Then run: gh auth login"
