#!/bin/bash
# set variables
CONFIGS="${HOME}/configs";

# install brew
 /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

 echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/aslan/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"

#-- root installs
if [ -d "/usr/local/Homebrew/bin/brew" ]; then
    eval $(/usr/local/Homebrew/bin/brew shellenv);
fi
#-- peasant installs
if [ -d "${HOME}/.linuxbrew" ]; then
    eval $(${HOME}/.linuxbrew/bin/brew shellenv);
fi

# install brew
# source ./functions/linux-install-brew.sh;

# install apps using brew
source ./functions/brew-installs.sh;

source ./functions/linux-symlinks.sh;