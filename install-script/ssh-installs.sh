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

echo "all done";
#continue second install script