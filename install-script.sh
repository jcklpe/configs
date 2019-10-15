#!/bin/bash
##- INSTALL SCRIPT FOR CONFIGS

##- 𝖃𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
# set the package manager
export INSTALLER="apt";


if [[ $UNAMECHECK == *"Microsoft"* ]] then
##- Windows Subystem Layer
# set home variable with clean CR, and set configs location
export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
export WINHOME=${WINHOME//$'\015'};
CONFIGS="${WINHOME}/home/Documents/configs";

else
##- Normal Linux
#set configs location
CONFIGS="$HOME/configs";

fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
##- macOS
# set configs location
CONFIGS="$HOME/configs"
export INSTALLER="brew";
elif [[ "$OSTYPE" == "cygwin" ]]; then
# POSIX compatibility layer and Linux environment emulation for Windows

elif [[ "$OSTYPE" == "msys" ]]; then
# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)

elif [[ "$OSTYPE" == "win32" ]]; then
# lol

elif [[ "$OSTYPE" == "freebsd"* ]]; then
# Maybe a Nintendo Switch?

else
# Unknown.
fi

# Install Binaries
${INSTALLER} install zsh;
${INSTALLER} install mc;

# update git submodules
git submodule update --init --recursive;