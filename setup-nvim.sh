#!/bin/bash

# Neovim setup script for dotfiles
# This script creates symlinks from ~/.config/nvim to the dotfiles nvim configuration

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

echo "🚀 Setting up Neovim configuration..."

install_hint() {
    echo "⚠️  Missing $1. Install it with one of:"
    echo "   Ubuntu/Debian: sudo apt install $2"
    echo "   macOS: brew install $3"
}

if ! command -v fzf >/dev/null 2>&1; then
    install_hint "fzf" "fzf" "fzf"
fi

if ! command -v rg >/dev/null 2>&1; then
    install_hint "ripgrep (rg)" "ripgrep" "ripgrep"
fi

if ! command -v fd >/dev/null 2>&1; then
    install_hint "fd" "fd-find" "fd"
fi

if ! command -v bat >/dev/null 2>&1; then
    install_hint "bat" "bat" "bat"
fi

# Remove existing nvim config if it exists
if [ -L "$NVIM_CONFIG_DIR" ] || [ -d "$NVIM_CONFIG_DIR" ]; then
    echo "📁 Removing existing Neovim configuration..."
    rm -rf "$NVIM_CONFIG_DIR"
fi

# Create .config directory if it doesn't exist
mkdir -p "$HOME/.config"

# Create symlink to dotfiles nvim directory
echo "🔗 Creating symlink from $NVIM_CONFIG_DIR to $DOTFILES_DIR/nvim"
ln -sf "$DOTFILES_DIR/nvim" "$NVIM_CONFIG_DIR"

# Create symlink for lua user modules
echo "🔗 Creating symlink for lua user modules..."
ln -sf "$DOTFILES_DIR/lua/user" "$DOTFILES_DIR/nvim/lua/user"

echo "✅ Neovim setup complete!"
echo ""
echo "📋 What was set up:"
echo "  - Symlinked ~/.config/nvim to $DOTFILES_DIR/nvim"
echo "  - Symlinked user lua modules from $DOTFILES_DIR/lua"
echo "  - Lazy.nvim package manager configured"
echo "  - Essential plugins configured (LSP, Treesitter, Telescope, etc.)"
echo ""
echo "🎯 Next steps:"
echo "  1. Run 'nvim' to automatically install Lazy.nvim and plugins"
echo "  2. Use ':Lazy' to manage plugins"
echo "  3. Use ':Mason' to manage LSP servers"
echo "  4. Run './test_nvim_config.sh' to verify key mappings and dependencies"
echo ""
echo "🔍 Finding lua files in dotfiles:"
find "$DOTFILES_DIR" -name "*.lua" -type f | sort
