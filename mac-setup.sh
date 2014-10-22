
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

brew install postgresql
##initdb /usr/local/var/postgres
# cp /usr/local/Cellar/postgresql/9.1.4/homebrew.mxcl.postgresql.plist ~/Library/LaunchAgents/
# launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist
# pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start
psql postgres -c 'CREATE EXTENSION "adminpack";'


brew install libyaml
sudo pip install fabric==1.8.1
sudo pip install pyyaml

brew install node
npm install -g grunt-cli
npm install -g less
npm install -g bower


brew install links
brew install coreutils

ln -s /Applications/PyCharm.app/bin/inspect.sh /usr/bin/charm

# nokogiri

sudo port install libxml2 libxslt
sudo gem install nokogiri

#install xcode
sudo xcodebuild -license
xcode-select --install

defaults write com.apple.finder AppleShowAllFiles TRUE

brew install ack

npm install -g phantomjs

sudo pip install nose

sudo pip install nltk
sudo pip install gensim
sudo pip install textblob

brew install imagemagick
