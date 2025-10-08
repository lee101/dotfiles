#!/bin/bash

# Formatter installation script for Neovim
# This script installs all necessary formatters for various languages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "🔧 Installing code formatters..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1 installed successfully"
    else
        echo -e "${RED}✗${NC} Failed to install $1"
    fi
}

# Install uv if not present (for Python packages)
if ! command_exists uv; then
    echo "Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
    print_status "uv"
else
    echo -e "${GREEN}✓${NC} uv is already installed"
fi

# Create and setup Python venv in tools directory
echo "Setting up Python virtual environment in tools/.venv..."
cd "$SCRIPT_DIR"

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    uv venv .venv
    echo -e "${GREEN}✓${NC} Created Python virtual environment"
else
    echo -e "${GREEN}✓${NC} Virtual environment already exists"
fi

# Compile and install Python requirements
echo "Installing Python formatters (ruff, black, etc.)..."
if [ -f "$SCRIPT_DIR/requirements.in" ]; then
    # Use uv pip-compile to generate requirements.txt
    uv pip compile requirements.in -o requirements.txt
    # Install in the venv
    uv pip install -r requirements.txt --python .venv/bin/python
    print_status "Python formatters (ruff, black, pip-tools)"
    
    # Create symlinks in ~/.local/bin for global access
    mkdir -p ~/.local/bin
    for tool in ruff black isort autopep8 flake8 pylint mypy; do
        if [ -f "$VENV_DIR/bin/$tool" ]; then
            ln -sf "$VENV_DIR/bin/$tool" ~/.local/bin/$tool
            echo -e "${GREEN}✓${NC} Linked $tool to ~/.local/bin"
        fi
    done
else
    echo -e "${RED}✗${NC} requirements.in not found"
fi

# Install prettier using bun if available, otherwise npm
echo "Installing prettier (JS/TS/HTML/CSS/JSON/Markdown formatter)..."
if command_exists bun; then
    bun install -g prettier prettierd
    print_status "prettier and prettierd (via bun)"
elif command_exists npm; then
    npm install -g prettier prettierd
    print_status "prettier and prettierd (via npm)"
else
    echo -e "${RED}✗${NC} Neither bun nor npm found. Please install bun or Node.js first."
fi

# Install Go formatters (gofmt comes with Go, but we'll add goimports and gofumpt)
if command_exists go; then
    echo "Installing Go formatters..."
    go install golang.org/x/tools/cmd/goimports@latest
    print_status "goimports"
    go install mvdan.cc/gofumpt@latest
    print_status "gofumpt"
else
    echo -e "${YELLOW}⚠${NC} Go not found, skipping Go formatters"
fi

# Install shfmt for shell script formatting
echo "Installing shfmt (Shell formatter)..."
if command_exists go; then
    go install mvdan.cc/sh/v3/cmd/shfmt@latest
    print_status "shfmt"
else
    # Try to install binary directly
    curl -sS https://webinstall.dev/shfmt | bash
    print_status "shfmt (via webinstall)"
fi

# Install stylua for Lua formatting
echo "Installing stylua (Lua formatter)..."
if command_exists cargo; then
    cargo install stylua
    print_status "stylua"
else
    # Download binary directly
    STYLUA_VERSION="0.20.0"
    wget -q https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip
    unzip -q stylua-linux-x86_64.zip
    chmod +x stylua
    sudo mv stylua /usr/local/bin/ 2>/dev/null || mv stylua ~/.local/bin/
    rm stylua-linux-x86_64.zip
    print_status "stylua (binary)"
fi

# Install taplo for TOML formatting
echo "Installing taplo (TOML formatter)..."
if command_exists cargo; then
    cargo install taplo-cli --locked
    print_status "taplo"
else
    # Download binary
    curl -fsSL https://github.com/tamasfe/taplo/releases/latest/download/taplo-linux-x86_64.gz | gunzip > taplo
    chmod +x taplo
    sudo mv taplo /usr/local/bin/ 2>/dev/null || mv taplo ~/.local/bin/
    print_status "taplo (binary)"
fi

# Install rustfmt if Rust is installed
if command_exists rustc; then
    echo "Installing rustfmt (Rust formatter)..."
    rustup component add rustfmt
    print_status "rustfmt"
else
    echo -e "${YELLOW}⚠${NC} Rust not found, skipping rustfmt"
fi

# Add ~/.local/bin to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo -e "${YELLOW}⚠${NC} Added ~/.local/bin to PATH. Please run 'source ~/.bashrc' or restart your terminal."
fi

# Add Go bin to PATH if not already there
if command_exists go && [[ ":$PATH:" != *":$(go env GOPATH)/bin:"* ]]; then
    echo 'export PATH="$(go env GOPATH)/bin:$PATH"' >> ~/.bashrc
    echo -e "${YELLOW}⚠${NC} Added Go bin to PATH. Please run 'source ~/.bashrc' or restart your terminal."
fi

echo ""
echo "📋 Summary of installed formatters:"
echo "=================================="
command_exists ruff && echo -e "${GREEN}✓${NC} ruff (Python)"
command_exists black && echo -e "${GREEN}✓${NC} black (Python)"
command_exists prettier && echo -e "${GREEN}✓${NC} prettier (JS/TS/HTML/CSS/JSON/Markdown)"
command_exists prettierd && echo -e "${GREEN}✓${NC} prettierd (faster prettier daemon)"
command_exists gofmt && echo -e "${GREEN}✓${NC} gofmt (Go)"
command_exists goimports && echo -e "${GREEN}✓${NC} goimports (Go)"
command_exists gofumpt && echo -e "${GREEN}✓${NC} gofumpt (Go)"
command_exists shfmt && echo -e "${GREEN}✓${NC} shfmt (Shell)"
command_exists stylua && echo -e "${GREEN}✓${NC} stylua (Lua)"
command_exists taplo && echo -e "${GREEN}✓${NC} taplo (TOML)"
command_exists rustfmt && echo -e "${GREEN}✓${NC} rustfmt (Rust)"

echo ""
echo "✅ Formatter installation complete!"
echo ""
echo "Python formatters are installed in: $VENV_DIR"
echo "To update Python packages later, run from tools directory:"
echo "  pc  (alias for: uv pip compile requirements.in -o requirements.txt && uv pip install -r requirements.txt)"
echo ""
echo "In Neovim, you can format with:"
echo "  • <leader>F (Space + F)"
echo "  • <leader>cf (Space + cf)"
echo "  • <C-S-f> (Ctrl+Shift+F)"
echo ""
echo "If any formatters failed to install, please check the error messages above."