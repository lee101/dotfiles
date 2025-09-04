#!/bin/bash

set -e

echo "🚀 Starting Mac Setup..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "This script is intended for macOS only"
    exit 1
fi

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ -d "/opt/homebrew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew already installed"
fi

# Update Homebrew
echo "📦 Updating Homebrew..."
brew update

# Install core tools
echo "🛠️ Installing core tools..."
brew install \
    git \
    git-lfs \
    gh \
    hub \
    wget \
    curl \
    htop \
    tree \
    jq \
    ripgrep \
    fd \
    bat \
    eza \
    fzf \
    direnv \
    tmux \
    neovim \
    starship \
    tig \
    imagemagick \
    nasm \
    cmake \
    httpie \
    dnsmasq \
    ack \
    links \
    coreutils

# Install modern CLI tools
echo "🚀 Installing modern CLI tools..."
brew install \
    lazygit \
    git-delta \
    difftastic \
    dust \
    bottom \
    zoxide \
    atuin \
    tealdeer \
    procs \
    tokei \
    hyperfine \
    bandwhich \
    grex \
    xh \
    dog \
    gping \
    choose \
    sd

# Install development tools
echo "💻 Installing development tools..."
brew install \
    node \
    python@3.12 \
    pyenv \
    rbenv \
    rust \
    go \
    docker \
    docker-compose \
    postgresql@14 \
    redis \
    kubectl \
    kubectx \
    k9s \
    helm \
    terraform \
    nvm \
    bun

# Install Python 3.12.7 via pyenv
echo "🐍 Installing Python 3.12.7 via pyenv..."
if command -v pyenv &> /dev/null; then
    pyenv install 3.12.7 || true
    pyenv global 3.12.7 || true
    
    # Rehash pyenv shims
    pyenv rehash
fi

# Install useful casks
echo "🖥️ Installing applications..."
brew install --cask \
    visual-studio-code \
    iterm2 \
    ghostty \
    rectangle \
    stats \
    alt-tab \
    raycast \
    docker

# Install global Python packages
echo "📦 Installing Python packages..."
pip3 install --user \
    ipython \
    virtualenv \
    pipx \
    black \
    ruff \
    mypy \
    httpie \
    fabric \
    django \
    pyyaml \
    nose \
    nltk \
    gensim \
    textblob

# Download NLTK data
echo "📚 Downloading NLTK data..."
python3 -c "import nltk; nltk.download('popular')" || true

# Install Ruby gems
echo "💎 Installing Ruby gems..."
if command -v gem &> /dev/null; then
    # For nokogiri
    brew install libxml2 libxslt || true
    gem install nokogiri -- --use-system-libraries
fi

# Install Node packages
echo "📦 Installing Node packages..."
npm install -g \
    typescript \
    prettier \
    eslint \
    yarn \
    pnpm \
    diff-so-fancy \
    grunt-cli \
    gulp-cli \
    bower \
    less \
    phantomjs \
    bump-tag \
    typescript-language-server \
    vscode-langservers-extracted \
    vscode-json-languageserver

# Setup Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "🎨 Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "✅ Oh My Zsh already installed"
fi

# Install Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "🎨 Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Install zsh plugins
echo "🔌 Installing zsh plugins..."
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

# fast-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting
fi

# zsh-completions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions
fi

# SSH Key Setup
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "🔑 Generating SSH key..."
    read -p "Enter your email for SSH key: " email
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N ""
    
    echo "🔑 Adding SSH key to ssh-agent..."
    eval "$(ssh-agent -s)"
    
    # Create SSH config if it doesn't exist
    if [ ! -f "$HOME/.ssh/config" ]; then
        cat > "$HOME/.ssh/config" <<EOF
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    fi
    
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    
    echo "📋 SSH public key copied to clipboard. Add it to GitHub/GitLab:"
    pbcopy < ~/.ssh/id_ed25519.pub
    cat ~/.ssh/id_ed25519.pub
else
    echo "✅ SSH key already exists"
fi

# Create common directories
echo "📁 Creating common directories..."
mkdir -p ~/code
mkdir -p ~/scripts
mkdir -p ~/.config
mkdir -p ~/.config/lazygit

# Setup lazygit config
echo "⚙️ Configuring lazygit..."
cat > ~/.config/lazygit/config.yml <<EOF
gui:
  skipDiscardChangeWarning: true
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
EOF

# Configure git to use delta
echo "🎨 Configuring git with delta..."
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.light false
git config --global delta.side-by-side true
git config --global merge.conflictstyle diff3
git config --global diff.colorMoved default

# Setup dotfiles
if [ -d ~/code/dotfiles ]; then
    echo "🔗 Setting up dotfiles..."
    cd ~/code/dotfiles
    
    # Link dotfiles (if linkdotfiles script exists)
    if [ -f "linkdotfiles.py" ]; then
        python3 linkdotfiles.py
    elif [ -f "linkdotfiles" ]; then
        python3 linkdotfiles
    else
        echo "⚠️  Dotfiles linking script not found"
    fi
fi

# Install Rust tools via cargo
echo "🦀 Installing Rust tools..."
if command -v cargo &> /dev/null; then
    cargo install \
        zoxide \
        starship \
        bat \
        eza \
        fd-find \
        ripgrep \
        sd \
        dust \
        bottom \
        tealdeer \
        procs \
        tokei \
        hyperfine \
        grex \
        gitui \
        cargo-update \
        cargo-edit \
        cargo-watch
fi

# macOS System Preferences
echo "⚙️ Configuring macOS preferences..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show file extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Save screenshots to a specific folder
mkdir -p ~/Pictures/Screenshots
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Enable subpixel font rendering on non-Apple LCDs
defaults write NSGlobalDomain AppleFontSmoothing -int 2

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't automatically rearrange Spaces
defaults write com.apple.dock mru-spaces -bool false

# Disable Chrome swipe navigation
defaults write com.google.Chrome.plist AppleEnableSwipeNavigateWithScrolls -bool FALSE

# Restart affected applications
echo "🔄 Restarting affected applications..."
killall Finder || true
killall Dock || true

echo "✨ Mac setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Configure your Git identity:"
echo "   git config --global user.name 'Your Name'"
echo "   git config --global user.email 'your.email@example.com'"
echo "3. Add your SSH key to GitHub/GitLab (already copied to clipboard)"
echo "4. Install any additional applications from the App Store"
echo "5. Configure your development environment preferences"
echo "6. Run 'p10k configure' to customize your Powerlevel10k theme"
echo "7. Consider installing Helix editor with: ./setup-helix.sh"