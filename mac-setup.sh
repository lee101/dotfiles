
# brew
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

brew doctor
brew install ctags
brew install fish
brew install tree
##You will need to add:
#   /usr/local/bin/fish
# to /etc/shells

ssh-keygen -t rsa -C "leepenkman@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
pbcopy < ~/.ssh/id_rsa.pub

# put on github

# test out ssh -T git@github.com


mkdir ~/code
cd ~/code

git clone git@github.com:lee101/dotfiles.git
cd dotfiles;
python linkdotfiles

sudo easy_install pip
sudo pip install ipython
sudo pip install django

# django admin
brew update
brew install bash-completion ssh-copy-id wget
sudo ln -s /Library/Python/2.7/site-packages/django/bin/django-admin.py /usr/bin/django-admin

sudo pip install virtualenv virtualenvwrapper

# rails
\curl -sSL https://get.rvm.io | bash -s stable --rails --ruby