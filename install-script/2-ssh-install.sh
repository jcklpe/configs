##- Install all brew stuff and symlink to home folders
CONFIGS="${HOME}/configs";

##- add to environment based on OS/sudo-status
#-- sudo linux installs
if [ -d "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
    #export PATH=/home/linuxbrew/.linuxbrew/Homebrew/bin:$PATH
fi
#-- sudo mac installs
if [ -d "/usr/local/Homebrew/bin/brew" ]; then
    eval $(/usr/local/Homebrew/bin/brew shellenv);
fi
#-- non sudo mac/linux installs
if [ -d "${HOME}/.linuxbrew" ]; then
    eval $(${HOME}/.linuxbrew/bin/brew shellenv);
fi


##- Install stuff through brew
#install brew version of gcc for easier building
brew install gcc;

#install stuff
brew install zsh;
brew install exa;
brew install jump;
brew install micro;
brew install mc;
brew install ranger;

##- symlink stuff to $HOME
ln -sf  ${CONFIGS}/bash/bashrc.sh ${HOME}/.bashrc;
ln -sf  ${CONFIGS}/bash/bash.profile ${HOME}/.profile;
git config --global core.excludesfile ~/.gitignore_global;
ln -sf ${CONFIGS}/git/git.gitignore_global ${HOME}/.gitignore_global;
ln -sf ${CONFIGS}/zshrc.zsh ${HOME}/.zshrc;
ln -sf ${CONFIGS}/zprofile.zsh ${HOME}/.zprofile;
mkdir  ${HOME}/.config/micro/
ln -sf ${CONFIGS}/micro/settings.json ${HOME}/.config/micro/settings.json;
mkdir  ${HOME}/.config/micro/colorschemes
ln -sf ${CONFIGS}/micro/colorschemes/* ${HOME}/config/micro/colorschemes/*;
