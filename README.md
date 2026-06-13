# Dotfiles Collection

A comprehensive collection of dotfiles for Linux, macOS, and Windows development environments. This repository provides shell configurations, editor settings, and development tools with cross-platform compatibility.

## 📁 Structure

```
dotfiles/
├── windows/           # Windows PowerShell profiles with bash feature parity
├── nvim/             # Neovim configuration
├── lua/              # Lua configurations
├── scripts/          # Utility scripts
├── tools/            # Development tools
├── bashrc            # Bash configuration
├── zshrc             # Zsh configuration
├── gitconfig         # Git configuration
├── vimrc             # Vim configuration
└── ...               # Other dotfiles
```

## 🪟 Windows PowerShell Setup

### Quick Start (Windows)
1. **Download**: `git clone https://github.com/lee101/dotfiles.git`
2. **Navigate**: `cd dotfiles/windows`
3. **Install**: Double-click `setup.bat` or run `.\setup.ps1`

### Available Profiles
- **Full Profile**: Complete bash feature parity with all aliases and functions
- **Simple Profile**: Common development tools and aliases
- **Minimal Profile**: Just the essentials for basic usage

### Command Line Installation
```powershell
# Install full profile (recommended)
.\setup.ps1

# Install specific profile
.\setup.ps1 -ProfileType simple
.\setup.ps1 -ProfileType minimal

# Show available profiles
.\setup.ps1 -Info
```

## 🐧 Linux/macOS Setup

### Quick Start (Unix-like systems)
1. **Clone**: `git clone https://github.com/lee101/dotfiles.git ~/.dotfiles`
2. **Navigate**: `cd ~/.dotfiles`
3. **Bootstrap packages/tools**: `./setup-linux.sh`
4. **Install**: `python linkdotfiles.py`
5. **Force overwrite**: `python linkdotfiles.py -f`

### Manual Setup
```bash
# Link individual files
ln -sf ~/.dotfiles/bashrc ~/.bashrc
ln -sf ~/.dotfiles/zshrc ~/.zshrc
ln -sf ~/.dotfiles/gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/vimrc ~/.vimrc

# Source the configuration
source ~/.bashrc  # or source ~/.zshrc
```

## 🚀 Key Features

### Git Aliases (All Platforms)
```bash
gst          # git status
gco <branch> # git checkout
gcm <msg>    # git commit -m
gph          # git push (with tags)
gpl          # git pull
gaa          # git add -A
gcmep <msg>  # git add -A, commit, and push
```

### Docker Management
```bash
dps          # docker ps
dim          # docker images
dklall       # stop and remove all containers
drmiunused   # remove unused images
```

### Development Tools
```bash
usage        # show directory sizes
extract      # smart archive extraction
compress     # create archives
findn        # find files by name
webserver    # start simple HTTP server
```

### Navigation & Utilities
```bash
u            # cd ..
c            # cd ~/code
o            # open current directory
refresh      # reload shell configuration
```

## 📋 What's Included

### Core Configurations
- **Bash**: Comprehensive bash configuration with aliases and functions
- **Zsh**: Oh-My-Zsh compatible configuration
- **PowerShell**: Windows profiles with bash feature parity
- **Git**: Global git configuration and aliases
- **Vim/Neovim**: Editor configuration with plugins

### Development Tools
- **Docker**: Complete container management aliases
- **Python**: pip/uv integration with shortcuts
- **Node.js**: npm/yarn/pnpm aliases and utilities
- **Kubernetes**: kubectl shortcuts and utilities
- **Terraform**: Common terraform aliases

### Platform-Specific Features
- **Windows**: WSL integration, clipboard utilities, Windows-specific paths
- **macOS**: Homebrew integration, macOS-specific utilities
- **Linux**: Package manager integration, desktop environment utilities

## 🔧 Customization

### Adding Your Own Aliases
```bash
# Add to your ~/.bashrc or ~/.zshrc
alias myalias='echo "Hello World"'

# Or use the built-in function
ali myalias='echo "Hello World"'
```

### PowerShell Customization
```powershell
# Add to your profile
function MyFunction { Write-Host "Custom function" }

# Or use the built-in function
ali myalias=Write-Host "Custom function"
```

## 🛠️ Installation Options

### Option 1: Full Installation
Installs all dotfiles and configurations:
```bash
git clone https://github.com/lee101/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
python linkdotfiles.py -f
```

### Option 2: Selective Installation
Choose specific configurations:
```bash
# Just git configuration
ln -sf ~/.dotfiles/gitconfig ~/.gitconfig

# Just shell configuration
ln -sf ~/.dotfiles/bashrc ~/.bashrc

# Just vim configuration
ln -sf ~/.dotfiles/vimrc ~/.vimrc
```

### Option 3: Windows PowerShell Only
```powershell
git clone https://github.com/lee101/dotfiles.git
cd dotfiles/windows
.\setup.ps1
```

## 📚 Documentation

- **Windows PowerShell**: See `windows/README.md` for detailed PowerShell documentation
- **Neovim**: See `nvim/` directory for editor configuration
- **Scripts**: See `scripts/` directory for utility scripts

## 🔍 Troubleshooting

### PowerShell Execution Policy
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Missing Dependencies
```bash
# Check what tools are available
check-tools

# Install missing tools via package manager
# Ubuntu/Debian: apt install git vim curl
# macOS: brew install git vim curl
# Windows: choco install git vim curl
```

### Profile Not Loading
```bash
# Bash/Zsh
source ~/.bashrc
# or
source ~/.zshrc

# PowerShell
. $PROFILE
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on your target platform(s)
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- Inspired by the Unix philosophy of small, composable tools
- Built for developers who work across multiple platforms
- Designed for both beginners and power users

---

**Note**: These dotfiles are actively maintained and used across Windows, macOS, and Linux development environments. Feel free to customize them to match your workflow!

extra tools
 # Headless mode (default, no window)
  jscheck https://example.com

  # With visible window (if needed for debugging)
  jscheck --show-window https://example.com
