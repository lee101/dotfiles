#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$repo_dir/nvim"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
skip_sync="${NVIM_SETUP_SKIP_SYNC:-0}"

info() { printf '[nvim-setup] %s\n' "$*"; }
warn() { printf '[nvim-setup] warning: %s\n' "$*" >&2; }
command -v nvim >/dev/null || { echo 'Install Neovim first (apt/pacman/brew).' >&2; exit 1; }
command -v git >/dev/null || { echo 'Install Git first.' >&2; exit 1; }
if ! command -v tree-sitter >/dev/null 2>&1; then
  if command -v cargo >/dev/null 2>&1; then
    info 'Installing tree-sitter CLI with Cargo'
    cargo install tree-sitter-cli --locked
  elif command -v npm >/dev/null 2>&1; then
    warn 'Cargo is unavailable; installing tree-sitter CLI from npm as a fallback'
    npm install --global tree-sitter-cli
  else
    warn 'tree-sitter CLI is missing. Install Cargo or Node/npm before parser installation.'
  fi
fi
[[ -f "$source_dir/init.lua" ]] || { echo "Missing canonical config: $source_dir" >&2; exit 1; }

for tool in rg fd fzf node npm python3 go rustc; do
  command -v "$tool" >/dev/null 2>&1 || warn "optional tool missing: $tool"
done

mkdir -p "$(dirname "$config_dir")"
if [[ -e "$config_dir" || -L "$config_dir" ]]; then
  backup="${config_dir}.backup-$(date +%Y%m%d-%H%M%S)"
  info "Backing up existing config to $backup"
  mv -- "$config_dir" "$backup"
fi
ln -s "$source_dir" "$config_dir"
info "Linked $config_dir -> $source_dir"

if [[ -n "${TEXT_GENERATOR_NVIM_REPO:-}" && ! -d "${TEXT_GENERATOR_NVIM_DIR:-$HOME/code/text-generator-nvim}" ]]; then
  text_dir="${TEXT_GENERATOR_NVIM_DIR:-$HOME/code/text-generator-nvim}"
  mkdir -p "$(dirname "$text_dir")"
  info "Cloning text-generator-nvim from $TEXT_GENERATOR_NVIM_REPO"
  git clone "$TEXT_GENERATOR_NVIM_REPO" "$text_dir"
fi

if [[ "$skip_sync" != 1 ]]; then
  info 'Installing/updating Lazy plugins'
  nvim --headless '+Lazy! sync' '+qa'
  info 'Installing Tree-sitter parsers'
  nvim --headless '+Lazy! load nvim-treesitter' '+lua require("nvim-treesitter").install({ "bash", "c", "cpp", "css", "dockerfile", "go", "html", "java", "javascript", "json", "lua", "markdown", "php", "python", "query", "regex", "ruby", "rust", "sql", "toml", "tsx", "typescript", "vim", "vimdoc", "yaml" }):wait(300000)' '+qa' || warn 'Tree-sitter parser installation failed; run :TSInstall later.'
fi

info 'Running headless startup check'
nvim --headless '+checkhealth' '+qa' 2>&1 | tail -80
info 'Neovim setup complete. Start with: vi (or nvim)'
