#!/bin/bash

echo "Removing all Copilot references from Neovim..."

# Remove Copilot plugin directory
rm -rf ~/.local/share/nvim/lazy/copilot.vim

# Clear Lazy cache
rm -rf ~/.cache/nvim/lazy

# Remove Copilot state files
rm -rf ~/.local/state/nvim/lazy/state.json

echo "Copilot has been removed. Please restart Neovim."
echo "When you open Neovim, if you see any errors, run :Lazy sync to clean up."