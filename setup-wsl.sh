#!/bin/bash
# WSL Ubuntu Development Setup Script
# Run this after WSL2 is installed: bash setup-wsl.sh

set -e

echo "======================================="
echo "WSL Ubuntu Development Setup"
echo "======================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Update system
echo -e "${GREEN}Step 1: Updating system packages${NC}"
sudo apt update && sudo apt upgrade -y

# Essential build tools
echo -e "${GREEN}Step 2: Installing essential build tools${NC}"
sudo apt install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Development tools
echo -e "${GREEN}Step 3: Installing development tools${NC}"
sudo apt install -y \
    vim \
    neovim \
    tmux \
    htop \
    tree \
    jq \
    ripgrep \
    fd-find \
    bat \
    fzf \
    zsh \
    fish \
    httpie \
    ncdu \
    neofetch \
    tldr

# Install exa (better ls)
if ! command -v exa &> /dev/null; then
    wget -c https://github.com/ogham/exa/releases/download/v0.10.0/exa-linux-x86_64-v0.10.0.zip
    unzip exa-linux-x86_64-v0.10.0.zip
    sudo mv bin/exa /usr/local/bin/
    rm -rf bin exa-linux-x86_64-v0.10.0.zip
fi

# Python setup
echo -e "${GREEN}Step 4: Setting up Python environment${NC}"
sudo apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python-is-python3

pip3 install --user \
    pipx \
    virtualenv \
    poetry \
    black \
    flake8 \
    mypy \
    pytest \
    ipython \
    jupyter \
    notebook

# Node.js via NodeSource
echo -e "${GREEN}Step 5: Installing Node.js LTS${NC}"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Install global npm packages
npm install -g \
    yarn \
    pnpm \
    typescript \
    ts-node \
    nodemon \
    pm2 \
    eslint \
    prettier

# Go
echo -e "${GREEN}Step 6: Installing Go${NC}"
GO_VERSION="1.21.5"
wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc

# Rust
echo -e "${GREEN}Step 7: Installing Rust${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Docker
echo -e "${GREEN}Step 8: Installing Docker${NC}"
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# GitHub CLI
echo -e "${GREEN}Step 9: Installing GitHub CLI${NC}"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

# AWS CLI
echo -e "${GREEN}Step 10: Installing AWS CLI${NC}"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# kubectl
echo -e "${GREEN}Step 11: Installing kubectl${NC}"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Terraform
echo -e "${GREEN}Step 12: Installing Terraform${NC}"
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Oh My Zsh
echo -e "${GREEN}Step 13: Installing Oh My Zsh${NC}"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions 2>/dev/null || true

# Starship prompt
echo -e "${GREEN}Step 14: Installing Starship prompt${NC}"
curl -sS https://starship.rs/install.sh | sh -s -- -y

# Setup zoxide (better cd)
echo -e "${GREEN}Step 15: Installing zoxide${NC}"
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# Databases
echo -e "${GREEN}Step 16: Installing database clients${NC}"
sudo apt install -y \
    postgresql-client \
    mysql-client \
    redis-tools \
    sqlite3

# Lazygit
echo -e "${GREEN}Step 17: Installing lazygit${NC}"
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit

# Create useful directories
echo -e "${GREEN}Step 18: Creating development directories${NC}"
mkdir -p ~/dev
mkdir -p ~/scripts
mkdir -p ~/.config

# Configure Git
echo -e "${GREEN}Step 19: Basic Git configuration${NC}"
git config --global init.defaultBranch main
git config --global core.editor vim
git config --global pull.rebase false

# Setup dotfiles
echo -e "${GREEN}Step 20: Setting up shell configuration${NC}"

# Add to .bashrc
cat >> ~/.bashrc << 'EOF'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias d='docker'
alias dc='docker-compose'
alias k='kubectl'
alias tf='terraform'
alias py='python3'
alias v='nvim'

# Use bat instead of cat if available
if command -v batcat &> /dev/null; then
    alias cat='batcat'
elif command -v bat &> /dev/null; then
    alias cat='bat'
fi

# Use exa instead of ls if available
if command -v exa &> /dev/null; then
    alias ls='exa'
    alias ll='exa -la'
    alias tree='exa --tree'
fi

# Initialize starship if installed
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Initialize zoxide if installed
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Better history
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Set default editor
export EDITOR=vim
export VISUAL=vim

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

# Add to .zshrc
cat >> ~/.zshrc << 'EOF'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias d='docker'
alias dc='docker-compose'
alias k='kubectl'
alias tf='terraform'
alias py='python3'
alias v='nvim'

# Use bat instead of cat if available
if command -v batcat &> /dev/null; then
    alias cat='batcat'
elif command -v bat &> /dev/null; then
    alias cat='bat'
fi

# Use exa instead of ls if available
if command -v exa &> /dev/null; then
    alias ls='exa'
    alias ll='exa -la'
    alias tree='exa --tree'
fi

# Initialize starship if installed
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Initialize zoxide if installed
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Better history
export HISTSIZE=10000
export SAVEHIST=10000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# Set default editor
export EDITOR=vim
export VISUAL=vim

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Load Rust environment
source "$HOME/.cargo/env" 2>/dev/null || true
EOF

echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}WSL Setup Complete!${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Set up your Git identity:"
echo "   git config --global user.name 'Your Name'"
echo "   git config --global user.email 'your.email@example.com'"
echo "2. Generate SSH key for GitHub:"
echo "   ssh-keygen -t ed25519 -C 'your.email@example.com'"
echo "3. Switch to Zsh if desired:"
echo "   chsh -s \$(which zsh)"
echo "4. Restart your terminal or run:"
echo "   source ~/.bashrc"
echo ""
echo -e "${YELLOW}Note: You may need to log out and back in for Docker group changes to take effect.${NC}"