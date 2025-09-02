#!/bin/bash

set -e

echo "🚀 Setting up fast, minimal zsh configuration..."

# Create zsh config directory
mkdir -p ~/.zsh/cache

# Install essential plugins (minimal set)
echo "📦 Installing minimal zsh plugins..."

# zsh-autosuggestions (very useful, minimal overhead)
if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
  echo "Installing zsh-autosuggestions..."
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
fi

# fast-syntax-highlighting (faster than zsh-syntax-highlighting)
if [ ! -d ~/.zsh/fast-syntax-highlighting ]; then
  echo "Installing fast-syntax-highlighting..."
  git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git ~/.zsh/fast-syntax-highlighting
fi

# Optional: Pure prompt (if not using starship)
if [ ! -d ~/.zsh/pure ] && ! command -v starship >/dev/null 2>&1; then
  echo "Installing pure prompt..."
  git clone --depth=1 https://github.com/sindresorhus/pure.git ~/.zsh/pure
fi

# Backup existing .zshrc
if [ -f ~/.zshrc ]; then
  echo "Backing up existing .zshrc to .zshrc.backup-omz"
  cp ~/.zshrc ~/.zshrc.backup-omz
fi

# Link the fast zshrc
echo "🔗 Linking fast zshrc..."
ln -sf ~/code/dotfiles/zshrc-fast ~/.zshrc

# Install starship if not already installed (recommended for speed)
if ! command -v starship >/dev/null 2>&1; then
  echo "🌟 Installing Starship prompt (recommended)..."
  if command -v brew >/dev/null 2>&1; then
    brew install starship
  else
    curl -sS https://starship.rs/install.sh | sh
  fi
fi

# Create a minimal starship config for speed
if [ ! -f ~/.config/starship.toml ]; then
  echo "Creating minimal Starship config..."
  mkdir -p ~/.config
  cat > ~/.config/starship.toml <<'EOF'
# Minimal, fast Starship config
add_newline = false
command_timeout = 100

[line_break]
disabled = true

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[directory]
truncation_length = 3
truncate_to_repo = true
style = "bold cyan"

[git_branch]
format = "[$symbol$branch]($style) "
style = "bold purple"

[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'
style = "bold red"
disabled = false

[cmd_duration]
min_time = 500
format = "[$duration](bold yellow) "

[python]
symbol = "🐍 "
format = '[$symbol$version]($style) '
disabled = false

[nodejs]
symbol = "⬢ "
format = '[$symbol$version]($style) '
disabled = false

[package]
disabled = true

[rust]
disabled = true

[golang]
disabled = true

[java]
disabled = true

[kubernetes]
disabled = true

[aws]
disabled = true

[gcloud]
disabled = true

[azure]
disabled = true
EOF
fi

echo ""
echo "✅ Fast zsh setup complete!"
echo ""
echo "📊 Performance tips:"
echo "1. The new config starts MUCH faster than Oh My Zsh"
echo "2. Completions are cached for speed"
echo "3. Heavy tools (nvm, pyenv) are lazy-loaded"
echo "4. Using Starship (Rust) or Pure prompt for speed"
echo ""
echo "🎯 To use the new config:"
echo "   source ~/.zshrc"
echo ""
echo "🔄 To switch back to Oh My Zsh:"
echo "   cp ~/.zshrc.backup-omz ~/.zshrc && source ~/.zshrc"
echo ""
echo "⚡ Benchmark your shell startup:"
echo "   time zsh -i -c exit"