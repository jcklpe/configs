#!/bin/bash
##- Install list for manual installation of binaries without sudo
#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;

#settings variables
CONFIGS="$HOME/configs";


##- brew installs
# install homebrew
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)";

# make homebrew available in sudo installs
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    #install brew deps
    sudo apt install build-essential;
    sudo eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
    #export PATH=/home/linuxbrew/.linuxbrew/Homebrew/bin:$PATH
fi

# make homebrew available in non-sudo installs
if [ -d "${HOME}/.linuxbrew" ]; then
eval $(${HOME}/.linuxbrew/bin/brew shellenv);
fi



#install brew version of gcc for easier building
brew install gcc;

#install stuff
brew install zsh;
brew install exa;
brew install jump;
brew install micro;
brew install mc;

##- symlink stuff to $HOME
ln -sf  ${CONFIGS}/bash/bashrc.sh ${HOME}/.bashrc;
ln -sf  ${CONFIGS}/bash/bash.profile ${HOME}/.profile;
git config --global core.excludesfile ~/.gitignore_global;
ln -sf  ${CONFIGS}/git/git.gitignore_global ${HOME}/.gitignore_global;
ln -sf  ${CONFIGS}/zshrc.zsh ${HOME}/.zshrc;
ln -sf  ${CONFIGS}/zprofile.zsh ${HOME}/.zprofile;
ln -sf ${CONFIGS}/micro/settings.json ${HOME}/.config/micro/settings.json;
ln -sf ${CONFIGS}/micro/colorschemes ${HOME}/.config/micro/colorschemes;
