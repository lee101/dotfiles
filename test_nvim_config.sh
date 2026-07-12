#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$ROOT_DIR/nvim/init.lua"
DOC="$ROOT_DIR/docs/nvim-navigation.md"
TUTORIAL="$ROOT_DIR/nvim-tutorial.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

[[ -f "$CONFIG" ]] || fail "missing active Neovim config: $CONFIG"
[[ -f "$DOC" ]] || fail "missing navigation doc: $DOC"
[[ -f "$TUTORIAL" ]] || fail "missing tutorial: $TUTORIAL"

rg -q '"ibhagwan/fzf-lua"' "$CONFIG" || fail "active config must use fzf-lua"
rg -q 'vim.keymap.set\("n", "<leader>fg", fzf.live_grep' "$CONFIG" || fail "Space fg must map to fzf-lua live_grep"
rg -q 'vim.fn.executable\("fzf"\)' "$CONFIG" || fail "config should warn clearly when fzf is missing"
rg -q 'vim.keymap.set\("n", "<C-p>", fzf.files' "$CONFIG" || fail "Ctrl-p must map to fzf-lua files"
rg -q '"text-generator-nvim"' "$CONFIG" || fail "text-generator-nvim plugin spec missing"
rg -q 'require\("text-generator"\).setup' "$CONFIG" || fail "text-generator-nvim setup missing"
pass "key plugin specs and mappings exist"

for tool in nvim git fzf rg; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool missing from PATH: $tool"
done
pass "required tools are installed"

for tool in fd bat; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "WARN: optional tool missing from PATH: $tool"
  fi
done

rg -q 'fzf-lua' "$DOC" || fail "navigation doc should name fzf-lua"
rg -q 'Space fg' "$DOC" || fail "navigation doc should document Space fg"
rg -q 'sudo apt install .*fzf.*ripgrep' "$DOC" || fail "navigation doc should include Linux fzf/rg install command"
rg -q 'text-generator-nvim' "$TUTORIAL" || fail "tutorial should document text-generator-nvim setup"
rg -q '/nvme0n1-disk/code/text-generator-nvim' "$TUTORIAL" || fail "tutorial should document the configured text-generator-nvim path"
pass "docs cover fzf-lua and text-generator-nvim"

nvim --headless -u "$CONFIG" +'lua assert(vim.fn.maparg("<leader>fg", "n") ~= "", "missing <leader>fg map")' +qa
pass "headless Neovim loads config and exposes Space fg"
