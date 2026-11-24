#!/usr/bin/env bash
# linux-setup.sh - idempotent Ubuntu/Debian dev box bootstrap (x86_64 + arm64).
# Safe to re-run: every step checks whether it's already done first.
#
# Optional steps (off by default, enable with env vars):
#   WITH_FFMPEG_BUILD=1   build ffmpeg from source with NVENC/CUDA (needs NVIDIA GPU)
#   WITH_CUDA=1           install cuda-toolkit from NVIDIA's apt repo
#   WITH_KUBEADM=1        install kubelet + kubeadm (kubectl is always installed)
#   WITH_TORRENT=1        aria2/qbittorrent/calibre/pandoc archive tooling + flaresolverr
#   WITH_AUDIO=1          DeepFilterNet virtual mic (also auto when a desktop audio server is up)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; FAILED+=("$*"); }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(uname -s)" = Linux ] || { echo "Linux only (use mac-setup.sh on macOS)" >&2; exit 1; }
have apt-get || { echo "apt-based distro required" >&2; exit 1; }

case "$(uname -m)" in
    x86_64)  ARCH=x86_64; DEB_ARCH=amd64; GO_ARCH=amd64 ;;
    aarch64|arm64) ARCH=aarch64; DEB_ARCH=arm64; GO_ARCH=arm64 ;;
    *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
. /etc/os-release
CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-jammy}}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
APT_UPDATED=0
apt_update() { [ "$APT_UPDATED" = 1 ] || { sudo apt-get update -qq && APT_UPDATED=1; }; }
# apt_install pkg... : installs only packages not already installed
apt_install() {
    local missing=() p
    for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
    [ ${#missing[@]} -eq 0 ] && return 0
    apt_update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}" \
        && ok "apt: ${missing[*]}" || warn "apt install failed: ${missing[*]}"
}
gh_latest() { # gh_latest owner/repo -> tag without leading v
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1
}
add_apt_repo() { # add_apt_repo name keyurl "deb line"
    local key="/etc/apt/keyrings/$1.gpg" list="/etc/apt/sources.list.d/$1.list"
    [ -f "$list" ] && return 0
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL "$2" | { if [[ "$2" == *.asc || "$2" == *Release.key ]]; then sudo gpg --dearmor --yes -o "$key"; else sudo tee "$key" >/dev/null; fi; }
    sudo chmod go+r "$key"
    echo "${3/KEY/$key}" | sudo tee "$list" >/dev/null
    APT_UPDATED=0
}

sudo -v || { echo "sudo required" >&2; exit 1; }

# ── Base packages ────────────────────────────────────────────────────
step "Base packages"
apt_install build-essential git curl wget unzip zip ca-certificates gnupg software-properties-common \
    zsh tmux vim tig fzf ripgrep fd-find bat jq imagemagick luarocks nasm yasm cmake ninja-build meson pkg-config \
    autoconf automake libtool texinfo zile plocate hstr strace htop btop tree direnv lynx xdotool xclip \
    tk-dev libreadline-dev libbz2-dev libssl-dev zlib1g-dev libsqlite3-dev libffi-dev liblzma-dev libncurses-dev \
    libxml2-dev libxslt1-dev mold python3-venv python3-pip pipx shellcheck universal-ctags
# Debian names fd/bat differently; expose the usual names
mkdir -p ~/.local/bin
have fd  || { have fdfind && ln -sf "$(command -v fdfind)" ~/.local/bin/fd; }
have bat || { have batcat && ln -sf "$(command -v batcat)" ~/.local/bin/bat; }

# Newer git
if ! grep -rqs git-core /etc/apt/sources.list.d/; then
    sudo add-apt-repository -y ppa:git-core/ppa >/dev/null 2>&1 && APT_UPDATED=0 && apt_update && sudo apt-get install -y -qq git && ok "git from git-core PPA"
fi

# ── Terminfo ─────────────────────────────────────────────────────────
if have tic; then
    tic -x -o "$HOME/.terminfo" "$SCRIPT_DIR/terminfo/xterm-ghostty.ti" 2>/dev/null
    tic -x -o "$HOME/.terminfo" "$SCRIPT_DIR/terminfo/kitty.terminfo" 2>/dev/null
    ok "ghostty/kitty terminfo"
fi

# ── Binary CLI tools from GitHub releases ────────────────────────────
step "CLI tools"
install_bin() { sudo install -m 755 "$1" /usr/local/bin/ && ok "installed $(basename "$1")"; }

if ! have eza; then
    v=$(gh_latest eza-community/eza)
    curl -fsSL "https://github.com/eza-community/eza/releases/download/v$v/eza_${ARCH}-unknown-linux-gnu.tar.gz" | tar -xz -C "$TMP" && install_bin "$TMP/eza" || warn "eza"
else ok "eza present"; fi

if ! have jj; then
    v=$(gh_latest jj-vcs/jj)
    curl -fsSL "https://github.com/jj-vcs/jj/releases/download/v$v/jj-v$v-${ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C "$TMP" && install_bin "$TMP/jj" || warn "jj"
else ok "jj present"; fi

if ! have delta; then
    v=$(gh_latest dandavison/delta)
    curl -fsSL "https://github.com/dandavison/delta/releases/download/$v/delta-$v-${ARCH}-unknown-linux-gnu.tar.gz" | tar -xz -C "$TMP" && install_bin "$TMP/delta-$v-${ARCH}-unknown-linux-gnu/delta" || warn "delta"
else ok "delta present"; fi

if ! have difft; then
    curl -fsSL "https://github.com/Wilfred/difftastic/releases/latest/download/difft-${ARCH}-unknown-linux-gnu.tar.gz" | tar -xz -C "$TMP" && install_bin "$TMP/difft" || warn "difft"
else ok "difft present"; fi

if ! have lazygit; then
    v=$(gh_latest jesseduffield/lazygit); la=$([ "$ARCH" = x86_64 ] && echo x86_64 || echo arm64)
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v$v/lazygit_${v}_Linux_${la}.tar.gz" | tar -xz -C "$TMP" lazygit && install_bin "$TMP/lazygit" || warn "lazygit"
else ok "lazygit present"; fi

if ! have zellij; then
    curl -fsSL "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C "$TMP" && install_bin "$TMP/zellij" || warn "zellij"
else ok "zellij present"; fi

if ! have zoxide; then curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null && ok "zoxide" || warn "zoxide"
else ok "zoxide present"; fi

if ! have uv; then curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null && ok "uv" || warn "uv"
else ok "uv present"; fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

if ! have logcli; then
    la=$([ "$ARCH" = x86_64 ] && echo amd64 || echo arm64); v=$(gh_latest grafana/loki)
    curl -fsSL -o "$TMP/logcli.zip" "https://github.com/grafana/loki/releases/download/v$v/logcli-linux-$la.zip" \
        && unzip -q -o "$TMP/logcli.zip" -d "$TMP" && sudo install -m 755 "$TMP/logcli-linux-$la" /usr/local/bin/logcli && ok "logcli" || warn "logcli"
else ok "logcli present"; fi

have helm || { curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null && ok "helm" || warn "helm"; }
have flux || { curl -fsSL https://fluxcd.io/install.sh | sudo bash >/dev/null && ok "flux" || warn "flux"; }

# ── Apt repos: gh, kubectl, cloudflared, helix ───────────────────────
step "Apt repo packages"
add_apt_repo githubcli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    "deb [arch=$DEB_ARCH signed-by=KEY] https://cli.github.com/packages stable main"
K8S_MINOR=v1.34
add_apt_repo kubernetes "https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/Release.key" \
    "deb [signed-by=KEY] https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/ /"
add_apt_repo cloudflared https://pkg.cloudflare.com/cloudflare-main.gpg \
    "deb [signed-by=KEY] https://pkg.cloudflare.com/cloudflared $CODENAME main"
apt_install gh kubectl cloudflared
[ "${WITH_KUBEADM:-0}" = 1 ] && apt_install kubelet kubeadm
if ! have hx; then
    sudo add-apt-repository -y ppa:maveonair/helix-editor >/dev/null 2>&1 && APT_UPDATED=0; apt_install helix
else ok "helix present"; fi

# Neovim: latest stable tarball (apt is old; snap is slow to start)
if ! have nvim || ! nvim --version | head -1 | grep -qE 'v0\.(1[1-9]|[2-9][0-9])'; then
    na=$([ "$ARCH" = x86_64 ] && echo x86_64 || echo arm64)
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$na.tar.gz" | sudo tar -xz -C /opt \
        && sudo ln -sf "/opt/nvim-linux-$na/bin/nvim" /usr/local/bin/nvim && ok "neovim $(nvim --version | head -1)" || warn "neovim"
else ok "neovim present: $(nvim --version | head -1)"; fi

# ── Languages ────────────────────────────────────────────────────────
step "Languages"
# Go: latest stable
GO_LATEST=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
if [ -x /usr/local/go/bin/go ] && [ "$(/usr/local/go/bin/go env GOVERSION)" = "$GO_LATEST" ]; then ok "go $GO_LATEST present"
elif [ -n "$GO_LATEST" ]; then
    curl -fsSL "https://go.dev/dl/$GO_LATEST.linux-$GO_ARCH.tar.gz" -o "$TMP/go.tgz" \
        && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$TMP/go.tgz" && ok "installed $GO_LATEST" || warn "go"
fi

# Rust
if [ -x ~/.cargo/bin/rustc ] || have rustc; then ok "rust present"
else curl --proto '=https' -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null && ok "rust" || warn "rust"; fi
have sccache || { have cargo && cargo install --locked sccache >/dev/null 2>&1 && ok "sccache" || warn "sccache"; }

# Rust build acceleration: mold + sccache, caches on the fastest disk
if [ -d /nvme0n1-disk ]; then FAST_DISK=/nvme0n1-disk
elif [ -d /scratch ]; then FAST_DISK=/scratch
else FAST_DISK="$HOME"; fi
if [ ! -f ~/.cargo/config.toml ]; then
    mkdir -p ~/.cargo "$FAST_DISK/sccache" "$FAST_DISK/cargo-target"
    cat > ~/.cargo/config.toml <<EOF
[build]
jobs = $(nproc)
rustc-wrapper = "sccache"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
target-dir = "$FAST_DISK/cargo-target"
EOF
    ok "cargo config (mold + sccache)"
else ok "cargo config present"; fi
# sccache env goes in ~/.secretbashrc (untracked, sourced by lib/common_shell) so tracked zshrc/bashrc stay clean
if ! grep -qs SCCACHE_DIR ~/.secretbashrc; then
    printf '\n# Rust sccache\nexport SCCACHE_DIR=%s/sccache\nexport SCCACHE_CACHE_SIZE=50G\n' "$FAST_DISK" >> ~/.secretbashrc
fi

# Node via nvm (latest nvm, LTS node)
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    v=$(gh_latest nvm-sh/nvm)
    PROFILE=/dev/null bash -c "$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v$v/install.sh")" >/dev/null && ok "nvm $v" || warn "nvm"
fi
if ! ls -d "$NVM_DIR"/versions/node/v* >/dev/null 2>&1; then
    ( set +u; . "$NVM_DIR/nvm.sh"; nvm install --lts >/dev/null && nvm alias default 'lts/*' >/dev/null ) && ok "node LTS" || warn "node"
else ok "node present: $(ls "$NVM_DIR/versions/node" | tail -1)"; fi
for _nv in "$NVM_DIR"/versions/node/v*; do :; done; export PATH="$_nv/bin:$PATH"
NPM_GLOBALS=(typescript typescript-language-server vscode-langservers-extracted prettier eslint diff-so-fancy yarn pyright bash-language-server)
if have npm; then
    installed="$(npm ls -g --depth=0 --parseable 2>/dev/null)"; missing=()
    for p in "${NPM_GLOBALS[@]}"; do grep -q "/node_modules/$p\$" <<<"$installed" || missing+=("$p"); done
    [ ${#missing[@]} -eq 0 ] && ok "npm globals present" || { npm install -g "${missing[@]}" >/dev/null 2>&1 && ok "npm -g ${missing[*]}" || warn "npm globals"; }
fi

# Python: pyenv + uv tools
if [ ! -d ~/.pyenv ]; then curl -fsSL https://pyenv.run | bash >/dev/null 2>&1 && ok "pyenv" || warn "pyenv"; else ok "pyenv present"; fi
PY_VER=3.12
if [ -x ~/.pyenv/bin/pyenv ] && ! ~/.pyenv/bin/pyenv versions --bare | grep -q "^$PY_VER"; then
    ~/.pyenv/bin/pyenv install -s "$PY_VER" && ok "python $PY_VER via pyenv" || warn "pyenv install $PY_VER"
fi
if have uv; then
    for t in ruff black mypy ipython httpie pre-commit; do uv tool list 2>/dev/null | grep -q "^$t " || uv tool install -q "$t" >/dev/null 2>&1 || warn "uv tool $t"; done
    ok "uv tools"
    if [ ! -x "$SCRIPT_DIR/tools/.venv/bin/python" ]; then
        uv venv -q "$SCRIPT_DIR/tools/.venv" && uv pip install -q --python "$SCRIPT_DIR/tools/.venv/bin/python" memray rich psutil && ok "tools/.venv (memray)" || warn "tools/.venv"
    fi
fi

# ── Shell ────────────────────────────────────────────────────────────
step "Zsh"
if [ ! -f ~/.oh-my-zsh/oh-my-zsh.sh ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null && ok "oh-my-zsh" || warn "oh-my-zsh"
else ok "oh-my-zsh present"; fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting zsh-users/zsh-completions; do
    d="$ZSH_CUSTOM/plugins/${repo#*/}"; [ -d "$d" ] || git clone -q --depth=1 "https://github.com/$repo" "$d" || warn "clone $repo"
done
mkdir -p ~/.git-templates ~/.zsh/cache ~/.yarn/bin   # ~/.yarn/bin stops the omz yarn plugin running `yarn global bin` (~130ms) each shell
[ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || { sudo chsh -s "$(command -v zsh)" "$USER" && ok "login shell -> zsh"; }

# ── Dotfiles ─────────────────────────────────────────────────────────
step "Link dotfiles"
python3 "$SCRIPT_DIR/linkdotfiles.py" -f -q && ok "dotfiles linked" || warn "linkdotfiles"
git -C "$SCRIPT_DIR" config core.hooksPath .githooks
have nvim && [ ! -d ~/.local/share/nvim/lazy/lazy.nvim ] && { nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 && ok "nvim plugins" || warn "nvim plugins"; }

# lynx config
if [ ! -f ~/.lynxrc ]; then
    mkdir -p ~/.lynx
    cat > ~/.lynxrc <<'EOF'
SET_COOKIES:TRUE
ACCEPT_ALL_COOKIES:TRUE
PERSISTENT_COOKIES:TRUE
COOKIE_FILE:~/.lynx/cookies
COOKIE_ACCEPT_DOMAINS:ALL
FORCE_COOKIE_PROMPT:FALSE
SHOW_COLOR:TRUE
VI_KEYS_ALWAYS_ON:TRUE
USE_MOUSE:TRUE
DEFAULT_EDITOR:vim
CHARACTER_SET:utf-8
ASSUME_CHARSET:utf-8
SSL_CERT_FILE:/etc/ssl/certs/ca-certificates.crt
USERAGENT:Lynx/2.9.0 (compatible; text browser)
NUMBER_LINKS:TRUE
DEFAULT_BOOKMARK_FILE:~/.lynx/bookmarks.html
MAXHIST:200
VERBOSE_IMAGES:TRUE
MAKE_LINKS_FOR_ALL_IMAGES:TRUE
JUSTIFY:TRUE
SHOW_KB_RATE:TRUE
EOF
    ok "lynx config"
fi

# ── GitHub CLI auth + extensions (interactive only) ──────────────────
if have gh && [ -t 0 ]; then
    gh auth status >/dev/null 2>&1 || gh auth login
fi

# ── Optional: CUDA + ffmpeg with NVENC ───────────────────────────────
if [ "${WITH_CUDA:-0}" = 1 ] || [ "${WITH_FFMPEG_BUILD:-0}" = 1 ]; then
    step "CUDA toolkit"
    if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
        rel="ubuntu${VERSION_ID//./}"; ca=$([ "$ARCH" = x86_64 ] && echo x86_64 || echo sbsa)
        curl -fsSL -o "$TMP/cuda-keyring.deb" "https://developer.download.nvidia.com/compute/cuda/repos/$rel/$ca/cuda-keyring_1.1-1_all.deb" \
            && sudo dpkg -i "$TMP/cuda-keyring.deb" >/dev/null && APT_UPDATED=0 || warn "cuda keyring"
    fi
    apt_install cuda-toolkit
fi
if [ "${WITH_FFMPEG_BUILD:-0}" = 1 ]; then
    step "ffmpeg (source build with NVENC)"
    if [ -x ~/bin/ffmpeg ] && ~/bin/ffmpeg -hide_banner -encoders 2>/dev/null | grep -q nvenc; then ok "ffmpeg with nvenc present"
    else
        apt_install libass-dev libfreetype6-dev libgnutls28-dev libmp3lame-dev libsdl2-dev libva-dev libvdpau-dev \
            libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev libx264-dev libx265-dev libnuma-dev libvpx-dev \
            libfdk-aac-dev libopus-dev libaom-dev libdav1d-dev libsvtav1-dev libvmaf-dev nv-codec-headers 2>/dev/null
        mkdir -p ~/ffmpeg_sources ~/bin
        ( cd ~/ffmpeg_sources && rm -rf ffmpeg && wget -qO ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 \
          && tar xjf ffmpeg-snapshot.tar.bz2 && cd ffmpeg \
          && PATH="$HOME/bin:/usr/local/cuda/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
              --prefix="$HOME/ffmpeg_build" --pkg-config-flags=--static --extra-cflags="-I$HOME/ffmpeg_build/include -I/usr/local/cuda/include" \
              --extra-ldflags="-L$HOME/ffmpeg_build/lib -L/usr/local/cuda/lib64" --extra-libs="-lpthread -lm" --ld=g++ --bindir="$HOME/bin" \
              --enable-gpl --enable-gnutls --enable-libaom --enable-libass --enable-libfdk-aac --enable-libfreetype --enable-libmp3lame \
              --enable-libopus --enable-libsvtav1 --enable-libdav1d --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 \
              --enable-nonfree --enable-cuda-nvcc --enable-libnpp --enable-nvenc --enable-cuvid --enable-cuda --enable-version3 \
          && make -j"$(nproc)" && make install ) && sudo cp ~/bin/ffmpeg ~/bin/ffprobe /usr/local/bin/ && ok "ffmpeg built" || warn "ffmpeg build"
    fi
else
    apt_install ffmpeg
fi

# ── Optional: torrent/archive tooling ────────────────────────────────
if [ "${WITH_TORRENT:-0}" = 1 ]; then
    step "Torrent/archive tooling"
    apt_install aria2 qbittorrent-nox p7zip-full libarchive-tools poppler-utils pandoc calibre djvulibre-bin
    if have docker && ! docker inspect flaresolverr >/dev/null 2>&1; then
        docker run -d --name flaresolverr --restart unless-stopped -p 127.0.0.1:8191:8191 ghcr.io/flaresolverr/flaresolverr:latest >/dev/null && ok "flaresolverr"
    fi
fi

# ── Optional: neural voice enhancement ───────────────────────────────
if [ "${WITH_AUDIO:-0}" = 1 ] || { have pactl && pactl info >/dev/null 2>&1; }; then
    "$SCRIPT_DIR/audio/neural-voice-enhance/install.sh" || warn "neural voice enhance"
fi

step "Done"
[ ${#FAILED[@]} -gt 0 ] && { printf '\033[33mNeeds attention:\033[0m\n'; printf '  - %s\n' "${FAILED[@]}"; }
echo "Run: exec zsh"
