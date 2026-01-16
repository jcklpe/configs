#!/bin/bash
# set variables
CONFIGS="$HOME/configs";
export CONFIGS="$HOME/configs"

#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;

# install brew
source $CONFIGS/install-script/functions/linux-install-brew.sh;

# install apps using brew
source $CONFIGS/install-script/functions/brew-installs.sh;

# symlink stuff
source $CONFIGS/install-script/functions/linux-symlink.sh;