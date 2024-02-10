#!/bin/bash
# set variables
CONFIGS="${HOME}/configs";

#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;

# install brew
source ./install-script/functions/linux-install-brew.sh;

# install apps using brew
source ./install-script/functions/brew-installs.sh;

# symlink stuff
source ./install-script/functions/linux-symlinks.sh;