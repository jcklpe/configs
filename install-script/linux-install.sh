#!/bin/bash
# set variables
CONFIGS="${HOME}/configs";

#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;

# install brew
source ./functions/linux-install-brew.sh;

# install apps using brew
source ./functions/brew-installs.sh;

# symlink stuff
source ./functions/linux-symlinks.sh;