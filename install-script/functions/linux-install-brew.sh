#!/bin/bash

# install brew
 sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)";

#-- add to path for root linux installs
if [ -d "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
    #export PATH=/home/linuxbrew/.linuxbrew/Homebrew/bin:$PATH
fi

#-- add to path for peasant mac/linux installs
if [ -d "${HOME}/.linuxbrew" ]; then
    eval $(${HOME}/.linuxbrew/bin/brew shellenv);
fi