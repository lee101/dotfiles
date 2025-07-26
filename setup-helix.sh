#!/bin/bash

# Helix Setup Script
# Sets up Helix editor with your custom configuration migrated from Vim/Neovim

set -e

echo "🌟 Setting up Helix editor with your Vim/Neovim preferences..."

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Install Helix based on OS
install_helix() {
    echo "📦 Installing Helix..."

    case $OS in
        "linux")
            if command -v apt &> /dev/null; then
                # Ubuntu/Debian
                sudo add-apt-repository ppa:maveonair/helix-editor
                sudo apt update
                sudo apt install helix
            elif command -v pacman &> /dev/null; then
                # Arch Linux
                sudo pacman -S helix
            elif command -v dnf &> /dev/null; then
                # Fedora
                sudo dnf install helix
            elif command -v zypper &> /dev/null; then
                # openSUSE
                sudo zypper install helix
            else
                echo "❌ Unsupported Linux distribution. Please install Helix manually."
                echo "Visit: https://helix-editor.com/install/"
                exit 1
            fi
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install helix
            else
                echo "❌ Homebrew not found. Please install Homebrew first or install Helix manually."
                echo "Visit: https://helix-editor.com/install/"
                exit 1
            fi
            ;;
        *)
            echo "❌ Automatic installation not supported for your OS."
            echo "Please install Helix manually from: https://helix-editor.com/install/"
            exit 1
            ;;
    esac
}

# Set up config directories
setup_config() {
    echo "⚙️  Setting up configuration..."

    # Determine config directory based on OS
    case $OS in
        "linux"|"unknown")
            CONFIG_DIR="$HOME/.config/helix"
            ;;
        "macos")
            CONFIG_DIR="$HOME/.config/helix"
            ;;
        "windows")
            CONFIG_DIR="$APPDATA/helix"
            ;;
    esac

    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"

    # Copy configuration files
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

    echo "📂 Copying configuration files..."
    cp "$DOTFILES_DIR/.helix/config.toml" "$CONFIG_DIR/"
    cp "$DOTFILES_DIR/.helix/languages.toml" "$CONFIG_DIR/"

    echo "✅ Configuration files copied to: $CONFIG_DIR"
}

# Install clipboard tools if needed
setup_clipboard() {
    echo "📋 Setting up clipboard integration..."

    case $OS in
        "linux")
            if ! command -v xclip &> /dev/null; then
                echo "Installing xclip for clipboard support..."
                if command -v apt &> /dev/null; then
                    sudo apt install xclip
                elif command -v pacman &> /dev/null; then
                    sudo pacman -S xclip
                elif command -v dnf &> /dev/null; then
                    sudo dnf install xclip
                fi
            fi
            ;;
        "macos")
            # macOS has built-in clipboard support
            echo "✅ macOS clipboard support is built-in"
            ;;
    esac
}

# Install language servers (optional)
install_language_servers() {
    echo "🔧 Would you like to install common language servers? (y/n)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing language servers..."

        # Install Node.js-based language servers
        if command -v npm &> /dev/null; then
            echo "Installing TypeScript/JavaScript language server..."
            npm install -g typescript-language-server typescript

            echo "Installing HTML/CSS language servers..."
            npm install -g vscode-langservers-extracted

            echo "Installing JSON language server..."
            npm install -g vscode-json-languageserver
        fi

        # Install Python language server
        if command -v pip3 &> /dev/null; then
            echo "Installing Python language server..."
            pip3 install --user pylsp
        fi

        # Install Rust language server
        if command -v rustup &> /dev/null; then
            echo "Installing Rust language server..."
            rustup component add rust-analyzer
        fi

        echo "✅ Language servers installed"
    fi
}

# Main installation flow
main() {
    echo "🚀 Starting Helix setup..."

    # Check if Helix is already installed
    if command -v hx &> /dev/null; then
        echo "✅ Helix is already installed"
    else
        install_helix
    fi

    setup_config
    setup_clipboard
    install_language_servers

    echo ""
    echo "🎉 Helix setup complete!"
    echo ""
    echo "📖 Key differences from Vim/Neovim to remember:"
    echo "   • Selection comes first, then action (vs Vim's action then motion)"
    echo "   • Space is used for the main command palette"
    echo "   • 'jj' in insert mode still takes you to normal mode"
    echo "   • ';' opens command mode (like ':' in Vim)"
    echo "   • 'C-t' opens file picker (like your new tab mapping)"
    echo "   • 'za' toggles folds (similar to your space mapping)"
    echo ""
    echo "🔧 Useful commands to get started:"
    echo "   • hx                    - start Helix"
    echo "   • hx file.txt          - open a file"
    echo "   • :help                - show help"
    echo "   • :tutor               - interactive tutorial"
    echo ""
    echo "📁 Configuration files are located at: $CONFIG_DIR"
    echo ""
    echo "Happy editing! 🎨"
}

# Run the main function
main "$@"
