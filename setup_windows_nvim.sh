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

# Get the dotfiles path
DOTFILES_PATH="$(pwd)/.config/nvim"
if [ ! -d "$DOTFILES_PATH" ]; then
    echo "Error: dotfiles nvim config not found at $DOTFILES_PATH"
    echo "Make sure you're running this from your dotfiles directory"
    exit 1
fi

# Create symlink (or copy if symlink fails)
echo "Creating symlink to dotfiles..."
if ln -sf "$DOTFILES_PATH"/* "$NVIM_CONFIG/" 2>/dev/null; then
    echo "✅ Symlink created successfully"
else
    echo "⚠️  Symlink failed, copying files instead..."
    cp -r "$DOTFILES_PATH"/* "$NVIM_CONFIG/"
    echo "✅ Files copied successfully"
fi

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