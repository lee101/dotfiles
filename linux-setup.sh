#!/bin/bash
sudo snap install eza

# Essential Git tools setup
echo "Installing Git and essential Git tools..."

# Install delta (better than diff-so-fancy)
curl -Lo git-delta.deb "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb"
sudo dpkg -i git-delta.deb
rm git-delta.deb

# Install lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit

# Install difftastic
curl -Lo difft.tar.gz "https://github.com/Wilfred/difftastic/releases/download/0.61.0/difft-x86_64-unknown-linux-gnu.tar.gz"
tar xf difft.tar.gz
sudo install difft /usr/local/bin
rm difft.tar.gz difft
# Install diff tools for git
echo "Installing delta and difft diff tools..."

# Install delta (syntax-highlighting pager for git and diff output)
curl -L https://github.com/dandavison/delta/releases/latest/download/delta-0.18.2-x86_64-unknown-linux-gnu.tar.gz | tar -xz
sudo mv delta-0.18.2-x86_64-unknown-linux-gnu/delta /usr/local/bin/
rm -rf delta-0.18.2-x86_64-unknown-linux-gnu

# Install difft (structural diff tool)
curl -L https://github.com/Wilfred/difftastic/releases/latest/download/difft-x86_64-unknown-linux-gnu.tar.gz | tar -xz
sudo mv difft /usr/local/bin/

echo "Delta and difft installed successfully"

# Install tig
sudo apt install tig -y

# Setup lazygit config
mkdir -p ~/.config/lazygit
echo "gui:
  skipDiscardChangeWarning: true" > ~/.config/lazygit/config.yml

# Install GitHub CLI (already in script but let's make sure it's here)
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

sudo apt install fzf
sudo apt-get install tk-dev
sudo apt-get install libreadline-dev
sudo apt-get install -y cmake
sudo apt-get install -y libarrow-dev libparquet-dev

sudo apt install nasm

sudo apt install zile plocate hstr
sudo snap install nvim

# Install Helix editor
sudo add-apt-repository ppa:maveonair/helix-editor -y
sudo apt update
sudo apt install helix -y


# ffmpeg
# First remove any existing FFmpeg installation
sudo apt remove ffmpeg
sudo apt-get update && sudo apt-get -y install \
  autoconf \
  automake \
  build-essential \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libgnutls28-dev \
  libmp3lame-dev \
  libsdl2-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  meson \
  ninja-build \
  pkg-config \
  texinfo \
  wget \
  yasm \
  zlib1g-dev

# Install NVIDIA SDK for hardware acceleration
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit

# Install additional codec dependencies
sudo apt-get -y install \
  nasm \
  libx264-dev \
  libx265-dev \
  libnuma-dev \
  libvpx-dev \
  libfdk-aac-dev \
  libopus-dev \
  libaom-dev \
  libdav1d-dev \
  libsvtav1-dev \
  libvmaf-dev

sudo apt-get update
sudo apt-get install libgnutls28-dev

# Create a working directory
mkdir -p ~/ffmpeg_sources ~/bin

# Compile FFmpeg
cd ~/ffmpeg_sources && \
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
tar xjvf ffmpeg-snapshot.tar.bz2 && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --ld="g++" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-gnutls \
  --enable-libaom \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libsvtav1 \
  --enable-libdav1d \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree \
  --enable-cuda-nvcc \
  --enable-libnpp \
  --enable-nvenc \
  --enable-cuvid \
  --enable-cuda \
  --enable-version3 && \
PATH="$HOME/bin:$PATH" make -j$(nproc) && \
make install && \
hash -r

# Make FFmpeg available system-wide
sudo cp ~/bin/ffmpeg /usr/local/bin/
sudo cp ~/bin/ffprobe /usr/local/bin/

# Verify installation
ffmpeg -version


## GIT

sudo npm install -g diff-so-fancy
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-get update
sudo apt-get install git -y
git --version

sudo snap install hub --classic


sudo apt install jq imagemagick luarocks -y

sudo apt install hub vim build-essential -y

# Install xdotool for window management (used by js_checker)
sudo apt install xdotool -y

sudo apt-get install libbz2-dev -y
sudo npm install -g yarn grunt gulp


curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.35.2/install.sh | bash

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

nvm install 14

curl https://pyenv.run | bash
pyenv install 3.12.2
pyenv shell 3.12.2

curl -s https://fluxcd.io/install.sh | sudo bash


# install go
wget https://go.dev/dl/go1.18.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version

# isntall logcli
wget https://github.com/grafana/loki/releases/download/v2.4.2/logcli-linux-amd64.zip
unzip logcli-linux-amd64.zip
sudo mv logcli-linux-amd64 /usr/local/bin/logcli

# setup kubernetes
sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
#sudo apt-mark hold kubelet kubeadm kubectl
# configure kubectl
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
sudo apt-get update && sudo apt-get install cloudflared

# setup nvim
sudo apt-get install neovim

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc

cp ~/.vimrc ~/.config/nvim/init.vim

(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

gh auth login
gh extension install github/gh-copilot

sudo apt install -y ripgrep

# Install lynx text-based web browser
echo "Installing lynx browser..."
sudo apt-get update
sudo apt-get install -y lynx

# Create lynx configuration directory
mkdir -p ~/.lynx

# Setup lynx configuration for better browsing experience
cat > ~/.lynxrc << 'EOF'
# Lynx configuration file

# Accept cookies automatically without prompting
SET_COOKIES:TRUE
ACCEPT_ALL_COOKIES:TRUE
PERSISTENT_COOKIES:TRUE
COOKIE_FILE:~/.lynx/cookies
COOKIE_ACCEPT_DOMAINS:ALL
COOKIE_REJECT_DOMAINS:
COOKIE_QUERY_INVALID_DOMAINS:FALSE
COOKIE_LOOSE_INVALID_DOMAINS:TRUE
FORCE_COOKIE_PROMPT:FALSE

# Enable color
SHOW_COLOR:TRUE

# Set vi-like key bindings
VI_KEYS_ALWAYS_ON:TRUE

# Enable mouse support
USE_MOUSE:TRUE

# Set default editor
DEFAULT_EDITOR:vim

# Character set
CHARACTER_SET:utf-8
ASSUME_CHARSET:utf-8

# Enable SSL/TLS
SSL_CERT_FILE:/etc/ssl/certs/ca-certificates.crt

# User agent string (some sites work better with a standard browser UA)
USERAGENT:Lynx/2.9.0 (compatible; text browser)

# Number links for easy navigation
NUMBER_LINKS:TRUE

# Save bookmarks file
DEFAULT_BOOKMARK_FILE:~/.lynx/bookmarks.html

# History settings
MAXHIST:200

# Display settings
VERBOSE_IMAGES:TRUE
MAKE_LINKS_FOR_ALL_IMAGES:TRUE

# Enable justified text
JUSTIFY:TRUE

# Show transfer rate
SHOW_KB_RATE:TRUE
EOF

echo "Lynx browser installed and configured successfully"
