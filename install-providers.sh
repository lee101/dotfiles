#!/usr/bin/env bash
# Install TensorDock, RunPod, and Vast.ai command-line tools into ~/.local/bin.
# Set INSTALL_DIR to override the default install location.

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PIP_FLAGS="${PIP_FLAGS:---user}"

log() {
  printf '[%s] %s\n' "$1" "${*:2}"
}

fail() {
  log "error" "$@"
  exit 1
}

ensure_python() {
  command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "python executable '$PYTHON_BIN' not found. Set PYTHON_BIN."
}

ensure_curl() {
  command -v curl >/dev/null 2>&1 || fail "curl is required to download runpodctl."
}

parse_pip_flags() {
  # shellcheck disable=SC2206 # intentional to split user-provided flags
  PIP_ARGS=(${PIP_FLAGS})
  if [[ ${#PIP_ARGS[@]} -eq 0 ]]; then
    PIP_ARGS=(--user)
  fi
}

install_tensordock_cli() {
  log "info" "Installing TensorDock Python CLI via pip..."
  "$PYTHON_BIN" -m pip install --upgrade "${PIP_ARGS[@]}" tensordock
  log "info" "TensorDock CLI installed."
}

install_vast_cli() {
  log "info" "Installing Vast.ai CLI via pip..."
  "$PYTHON_BIN" -m pip install --upgrade "${PIP_ARGS[@]}" vastai
  log "info" "Vast.ai CLI installed."
}

runpod_asset_name() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$os" in
    linux) os="linux" ;;
    darwin) os="darwin" ;;
    *) fail "Unsupported OS '$os' for runpodctl. Manual install required." ;;
  esac
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) fail "Unsupported architecture '$arch' for runpodctl. Manual install required." ;;
  esac
  printf 'runpodctl-%s-%s' "$os" "$arch"
}

install_runpod_cli() {
  ensure_curl
  mkdir -p "$INSTALL_DIR"

  local asset name url dest
  asset="$(runpod_asset_name)"
  url="https://github.com/runpod/runpodctl/releases/latest/download/${asset}"
  dest="${INSTALL_DIR}/runpodctl"

  log "info" "Downloading runpodctl from ${url}..."
  curl -fsSL "$url" -o "$dest"
  chmod +x "$dest"
  log "info" "runpodctl installed to ${dest}."
}

main() {
  mkdir -p "$INSTALL_DIR"
  ensure_python
  parse_pip_flags

  install_tensordock_cli
  install_runpod_cli
  install_vast_cli

  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log "warn" "Add ${INSTALL_DIR} to your PATH, e.g. export PATH=\"${INSTALL_DIR}:\$PATH\""
  fi

  log "info" "Installation complete."
}

main "$@"

