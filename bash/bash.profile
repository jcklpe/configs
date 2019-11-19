# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# Everything useful is put in .bashrc but this allows me to selectively trigger scripts only at shell start up


##- import .bashrc
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
    fi
fi

##- Launch Zsh on bash startup

# not sure the difference between these two
# if [ -t 1 ]; then
# exec zsh
# fi

if [[ $- == *i* ]]; then
   export SHELL=zsh
   exec zsh -l
fi

exa;
