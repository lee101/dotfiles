#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/linkdotfiles.py" ]]; then
  echo "This script must be run from the dotfiles repository root (linkdotfiles.py missing)." >&2
  exit 1
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Unable to detect operating system (missing /etc/os-release)." >&2
  exit 1
fi

SUPPORTED=false
case "${ID:-}" in
  ubuntu|debian|pop|elementary|neon|linuxmint)
    SUPPORTED=true
    ;;
esac

if [[ "${SUPPORTED}" != true && "${ID_LIKE:-}" != *debian* ]]; then
  echo "Unsupported distribution ${ID:-unknown}. This script currently targets Debian/Ubuntu derivatives." >&2
  exit 1
fi

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "This script requires sudo privileges; install sudo or re-run as root." >&2
    exit 1
  fi
fi

run_root() {
  if [[ -n "${SUDO}" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

log_info() {
  printf '==> %s\n' "$*"
}

log_warn() {
  printf '==> [WARN] %s\n' "$*" >&2
}

log_error() {
  printf '==> [ERROR] %s\n' "$*" >&2
}

TMP_DIR="$(mktemp -d)"
POST_INSTALL_NOTES=()

cleanup() {
  local exit_code=$?
  rm -rf "${TMP_DIR}"
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Setup interrupted (exit code ${exit_code})."
  fi
}

trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive
APT_UPDATED=0

reset_apt_cache() {
  APT_UPDATED=0
}

apt_update() {
  if [[ ${APT_UPDATED} -eq 0 ]]; then
    log_info "Updating apt package index..."
    run_root apt-get update
    APT_UPDATED=1
  fi
}

ensure_apt_packages() {
  local missing=()
  local pkg
  for pkg in "$@"; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
      missing+=("${pkg}")
    fi
  done

  if (( ${#missing[@]} )); then
    apt_update
    log_info "Installing apt packages: ${missing[*]}"
    run_root apt-get install -y --no-install-recommends "${missing[@]}"
  else
    log_info "All requested apt packages are already installed."
  fi
}

install_github_cli() {
  if command -v gh >/dev/null 2>&1; then
    log_info "GitHub CLI already installed."
    return
  fi

  log_info "Installing GitHub CLI..."
  local keyring="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local sources="/etc/apt/sources.list.d/github-cli.list"

  if [[ ! -f "${keyring}" ]]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "${TMP_DIR}/githubcli.gpg"
    run_root install -o root -g root -m 644 "${TMP_DIR}/githubcli.gpg" "${keyring}"
  fi

  if [[ ! -f "${sources}" ]]; then
    printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' \
      "$(dpkg --print-architecture)" "${keyring}" | run_root tee "${sources}" >/dev/null
    reset_apt_cache
  fi

  apt_update
  run_root apt-get install -y gh
}

install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    log_info "cloudflared already installed."
    return
  fi

  log_info "Installing cloudflared..."
  local keyring="/usr/share/keyrings/cloudflare-main.gpg"
  local sources="/etc/apt/sources.list.d/cloudflare-client.list"
  local codename="${VERSION_CODENAME:-}"

  if [[ -z "${codename}" ]]; then
    if command -v lsb_release >/dev/null 2>&1; then
      codename="$(lsb_release -cs)"
    else
      log_error "Unable to determine distribution codename for cloudflared repository."
      return 1
    fi
  fi

  if [[ ! -f "${keyring}" ]]; then
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg -o "${TMP_DIR}/cloudflare.gpg"
    run_root gpg --dearmor --output "${keyring}" "${TMP_DIR}/cloudflare.gpg"
  fi

  if [[ ! -f "${sources}" ]]; then
    printf 'deb [signed-by=%s] https://pkg.cloudflareclient.com/ %s main\n' \
      "${keyring}" "${codename}" | run_root tee "${sources}" >/dev/null
    reset_apt_cache
  fi

  apt_update
  run_root apt-get install -y cloudflared
  POST_INSTALL_NOTES+=("Run 'cloudflared login' to authenticate with Cloudflare and configure tunnels.")
}

install_nodejs() {
  if command -v node >/dev/null 2>&1; then
    log_info "Node.js already installed ($(node --version))."
    return
  fi

  log_info "Installing Node.js LTS..."
  local script="${TMP_DIR}/nodesource.sh"
  curl -fsSL https://deb.nodesource.com/setup_lts.x -o "${script}"
  run_root bash "${script}"
  reset_apt_cache
  apt_update
  run_root apt-get install -y nodejs
}

install_go() {
  if command -v go >/dev/null 2>&1; then
    log_info "Go already installed ($(go version))."
    return
  fi

  log_info "Installing latest Go toolchain..."
  local version
  version="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"
  if [[ -z "${version}" ]]; then
    log_error "Failed to determine latest Go version."
    return 1
  fi

  local arch
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv6l) arch="armv6l" ;;
    armv7l|armhf) arch="armv6l" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for Go binary release; skipping Go install."
      return 0
      ;;
  esac

  local tarball="${version}.linux-${arch}.tar.gz"
  curl -fsSL "https://go.dev/dl/${tarball}" -o "${TMP_DIR}/go.tgz"
  run_root rm -rf /usr/local/go
  run_root tar -C /usr/local -xzf "${TMP_DIR}/go.tgz"

  local profile="${HOME}/.profile"
  if ! grep -Fq '/usr/local/go/bin' "${profile}" 2>/dev/null; then
    {
      echo ''
      echo '# Added by setup-developer.sh'
    } >> "${profile}"
    echo 'export PATH="${PATH}:/usr/local/go/bin:${HOME}/go/bin"' >> "${profile}"
  fi

  POST_INSTALL_NOTES+=("Go installed. Restart your shell or run 'source ~/.profile' to refresh PATH.")
}

install_rust() {
  if command -v rustc >/dev/null 2>&1; then
    log_info "Rust toolchain already installed ($(rustc --version))."
    return
  fi

  log_info "Installing Rust toolchain via rustup..."
  local script="${TMP_DIR}/rustup-init.sh"
  curl -fsSL https://sh.rustup.rs -o "${script}"
  sh "${script}" -y --profile default
  POST_INSTALL_NOTES+=("Rust installed. Run 'source ~/.cargo/env' or restart your shell to use cargo and rustc.")
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log_info "Docker already installed ($(docker --version | head -n1))."
  else
    log_info "Installing Docker (engine, CLI, compose)..."
    local script="${TMP_DIR}/get-docker.sh"
    curl -fsSL https://get.docker.com -o "${script}"
    run_root sh "${script}"
  fi

  local current_user
  current_user="$(logname 2>/dev/null || id -un)"
  if id -nG "${current_user}" 2>/dev/null | grep -qw docker; then
    log_info "User ${current_user} already in docker group."
  else
    log_info "Adding ${current_user} to docker group..."
    run_root usermod -aG docker "${current_user}"
    POST_INSTALL_NOTES+=("Docker installed. Log out and back in (or run 'newgrp docker') for group changes to apply.")
  fi
}

install_eza() {
  if command -v eza >/dev/null 2>&1; then
    log_info "eza already installed."
    return
  fi

  log_info "Installing eza (modern ls)..."
  apt_update
  if run_root apt-get install -y eza >/dev/null 2>&1; then
    log_info "Installed eza via apt."
    return
  fi

  log_warn "apt package for eza unavailable; falling back to GitHub release."
  local target
  case "$(uname -m)" in
    x86_64) target="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) target="aarch64-unknown-linux-gnu" ;;
    armv7l|armhf) target="armv7-unknown-linux-gnueabihf" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for eza release; skipping."
      return 0
      ;;
  esac

  curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_${target}.tar.gz" -o "${TMP_DIR}/eza.tar.gz"
  tar -xzf "${TMP_DIR}/eza.tar.gz" -C "${TMP_DIR}"
  if [[ -f "${TMP_DIR}/eza" ]]; then
    run_root install -m 0755 "${TMP_DIR}/eza" /usr/local/bin/eza
  else
    log_warn "Failed to locate eza binary in release archive."
  fi
}

install_lazygit() {
  if command -v lazygit >/dev/null 2>&1; then
    log_info "lazygit already installed."
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not installed; skipping lazygit installation."
    return
  fi

  log_info "Installing lazygit..."
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name')"
  if [[ -z "${tag}" ]]; then
    log_warn "Unable to determine latest lazygit release."
    return
  fi

  tag="${tag#v}"
  local asset_arch
  case "$(uname -m)" in
    x86_64) asset_arch="Linux_x86_64" ;;
    aarch64|arm64) asset_arch="Linux_arm64" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for lazygit release; skipping."
      return
      ;;
  esac

  local archive="lazygit_${tag}_${asset_arch}.tar.gz"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${tag}/${archive}" -o "${TMP_DIR}/lazygit.tar.gz"
  tar -xzf "${TMP_DIR}/lazygit.tar.gz" -C "${TMP_DIR}" lazygit
  run_root install -m 0755 "${TMP_DIR}/lazygit" /usr/local/bin/lazygit
}

install_difftastic() {
  if command -v difft >/dev/null 2>&1; then
    log_info "difftastic already installed."
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not installed; skipping difftastic installation."
    return
  fi

  log_info "Installing difftastic..."
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/Wilfred/difftastic/releases/latest | jq -r '.tag_name')"
  if [[ -z "${tag}" ]]; then
    log_warn "Unable to determine latest difftastic release."
    return
  fi

  tag="${tag#v}"
  local target
  case "$(uname -m)" in
    x86_64) target="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) target="aarch64-unknown-linux-gnu" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for difftastic release; skipping."
      return
      ;;
  esac

  local archive="difft-${tag}-${target}.tar.gz"
  curl -fsSL "https://github.com/Wilfred/difftastic/releases/download/${tag}/${archive}" -o "${TMP_DIR}/difft.tar.gz"
  tar -xzf "${TMP_DIR}/difft.tar.gz" -C "${TMP_DIR}" difft
  run_root install -m 0755 "${TMP_DIR}/difft" /usr/local/bin/difft
}

install_git_delta() {
  if command -v delta >/dev/null 2>&1; then
    log_info "git-delta already installed."
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not installed; skipping git-delta installation."
    return
  fi

  log_info "Installing git-delta..."
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name')"
  if [[ -z "${tag}" ]]; then
    log_warn "Unable to determine latest git-delta release."
    return
  fi

  tag="${tag#v}"
  local target
  case "$(uname -m)" in
    x86_64) target="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) target="aarch64-unknown-linux-gnu" ;;
    *)
      log_warn "Unsupported architecture $(uname -m) for git-delta release; skipping."
      return
      ;;
  esac

  local archive="delta-${tag}-${target}.tar.gz"
  curl -fsSL "https://github.com/dandavison/delta/releases/download/${tag}/${archive}" -o "${TMP_DIR}/delta.tar.gz"
  tar -xzf "${TMP_DIR}/delta.tar.gz" -C "${TMP_DIR}"
  local bin_path="${TMP_DIR}/delta-${tag}-${target}/delta"
  if [[ -f "${bin_path}" ]]; then
    run_root install -m 0755 "${bin_path}" /usr/local/bin/delta
  else
    log_warn "Failed to locate delta binary."
  fi
}

link_dotfiles() {
  if ! command -v python3 >/dev/null 2>&1; then
    log_warn "python3 not installed; skipping dotfile symlinks."
    return
  fi

  log_info "Linking dotfiles into the home directory..."
  (cd "${SCRIPT_DIR}" && python3 ./linkdotfiles.py -f)
}

run_optional_script() {
  local script_name="$1"
  local script_path="${SCRIPT_DIR}/${script_name}"
  if [[ -x "${script_path}" ]]; then
    log_info "Running ${script_name}..."
    "${script_path}"
  else
    log_warn "Optional helper ${script_name} not found or not executable; skipping."
  fi
}

main() {
  log_info "Starting developer machine setup for ${PRETTY_NAME:-Linux}..."

  ensure_apt_packages \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config \
    curl \
    wget \
    git \
    git-lfs \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    pipx \
    neovim \
    tmux \
    htop \
    tree \
    jq \
    ripgrep \
    fd-find \
    fzf \
    bat \
    direnv \
    zsh \
    fonts-powerline \
    gdebi-core \
    ca-certificates

  install_github_cli
  install_cloudflared
  install_nodejs
  install_eza
  install_lazygit
  install_git_delta
  install_difftastic
  install_go
  install_rust
  install_docker
  link_dotfiles

  # Optional helper scripts if present
  [[ -x "${SCRIPT_DIR}/setup-nvim.sh" ]] && run_optional_script "setup-nvim.sh"
  [[ -x "${SCRIPT_DIR}/setup-helix.sh" ]] && run_optional_script "setup-helix.sh"

  if command -v pipx >/dev/null 2>&1; then
    log_info "Ensuring pipx path setup..."
    pipx ensurepath >/dev/null 2>&1 || true
  fi

  log_info "Developer setup completed successfully."

  if (( ${#POST_INSTALL_NOTES[@]} )); then
    printf '\nPost-install notes:\n'
    local note
    for note in "${POST_INSTALL_NOTES[@]}"; do
      printf '  - %s\n' "${note}"
    done
  fi
}

main "$@"
