#!/bin/bash

echo "Setting up Windows nvim configuration..."

# Check if we're in Git Bash
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
    echo "This script should be run in Git Bash on Windows"
    exit 1
fi

# Check if nvim is installed
if ! command -v nvim &> /dev/null; then
    echo "nvim not found. Please install it first:"
    echo "winget install Neovim.Neovim"
    echo "or download from: https://neovim.io/"
    exit 1
fi

echo "nvim found: $(which nvim)"
echo "nvim version: $(nvim --version | head -1)"

# Create config directory
NVIM_CONFIG="$HOME/.config/nvim"
if [ ! -d "$NVIM_CONFIG" ]; then
    mkdir -p "$NVIM_CONFIG"
    echo "Created nvim config directory: $NVIM_CONFIG"
fi

# Get the dotfiles path (robust for being called from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_NVIM="$SCRIPT_DIR/nvim"
ROOT_INIT="$SCRIPT_DIR/init.lua"
ROOT_LUA="$SCRIPT_DIR/lua"

if [ ! -f "$ROOT_INIT" ] && [ ! -d "$DOTFILES_NVIM" ]; then
    echo "Error: could not find dotfiles nvim sources next to this script"
    exit 1
fi

echo "Creating links / copies for Git Bash friendly config at $NVIM_CONFIG ..."

# Link (or copy) the real active config (root init.lua + lua/user)
if [ -f "$ROOT_INIT" ]; then
    ln -sf "$ROOT_INIT" "$NVIM_CONFIG/init.lua" 2>/dev/null || cp "$ROOT_INIT" "$NVIM_CONFIG/init.lua"
fi
if [ -d "$ROOT_LUA" ]; then
    ln -sfn "$ROOT_LUA" "$NVIM_CONFIG/lua" 2>/dev/null || cp -r "$ROOT_LUA" "$NVIM_CONFIG/lua"
fi

# Also bring the nvim/ subdir extras if present
if [ -d "$DOTFILES_NVIM" ]; then
    for f in "$DOTFILES_NVIM"/*; do
        base=$(basename "$f")
        [ "$base" = "init.lua" ] || [ "$base" = "lua" ] && continue
        ln -sf "$f" "$NVIM_CONFIG/$base" 2>/dev/null || cp -r "$f" "$NVIM_CONFIG/$base"
    done
fi

echo "✅ Neovim config linked/copied for Git Bash"

# Verify the setup
echo ""
echo "Verifying setup..."
if [ -f "$NVIM_CONFIG/init.lua" ]; then
    echo "✅ init.lua found"
    echo "First few lines:"
    head -3 "$NVIM_CONFIG/init.lua"
else
    echo "❌ init.lua not found"
    exit 1
fi

echo ""
echo "🎉 Windows nvim setup complete!"
echo ""
echo "To test:"
echo "1. nvim --version"
echo "2. nvim test.lua"
echo "3. Try: jj to escape, ;w to save, ;q to quit"
echo ""
echo "If you have issues, try:"
echo "1. Restart Git Bash"
echo "2. Run: source ~/.bashrc"
echo "3. Test: ni test.lua" 