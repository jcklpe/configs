#!/bin/bash
##- symlink stuff to $HOME
ln -sf  ${CONFIGS}/bash/bashrc.sh ${HOME}/.bashrc;
ln -sf  ${CONFIGS}/hyper-js/hyper.js ${HOME}/.hyper.js;
ln -sf  ${CONFIGS}/bash/bash.profile ${HOME}/.profile;
git config --global core.excludesfile ~/.gitignore_global;
ln -sf ${CONFIGS}/git/git.gitignore_global ${HOME}/.gitignore_global;
ln -sf ${CONFIGS}/zshrc.zsh ${HOME}/.zshrc;
ln -sf ${CONFIGS}/zprofile.zsh ${HOME}/.zprofile;
mkdir  ${HOME}/.config/
mkdir  ${HOME}/.config/micro/
mkdir  ${HOME}/.config/micro/colorschemes
ln -sf ${CONFIGS}/micro/settings.json ${HOME}/.config/micro/settings.json;
mkdir  ${HOME}/.config/micro/colorschemes
ln -sf ${CONFIGS}/micro/colorschemes/gameboy.micro ${HOME}/.config/micro/colorschemes/gameboy.micro;