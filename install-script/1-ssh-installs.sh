#!/bin/bash
##- Install list for manual installation of binaries without sudo
#settings/variables
CONFIGS="${HOME}/configs";

#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;


if [[ "$OSTYPE" == "linux-gnu" ]]; then
    # run brew install script for linux
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)";
    
    elif [[ "$OSTYPE" == "darwin"* ]]; then
    # run brew install script for mac
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    echo "os not supported by this install script"
fi



echo "all done";
#continue second install script