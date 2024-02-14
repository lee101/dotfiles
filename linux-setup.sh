
## GIT

sudo npm install -g diff-so-fancy
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-get update
sudo apt-get install git -y
git --version

sudo snap install hub --classic


sudo apt  install jq

sudo apt install hub vim build-essential -y

sudo apt-get install libbz2-dev -y
sudo npm install -g yarn grunt gulp


curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.35.2/install.sh | bash

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

nvm install 14

curl https://pyenv.run | bash
pyenv install 3.9.2
pyenv shell 3.9.2

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
