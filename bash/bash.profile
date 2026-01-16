# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# Everything useful is put in .bashrc but this allows me to selectively trigger scripts only at shell start up

##- Variables and MISC Settings
#set this to prevent percent sign showing due to partial line
#ref: https://unix.stackexchange.com/questions/167582/why-zsh-ends-a-line-with-a-highlighted-percent-symbol/167600#167600
PROMPT_EOL_MARK=''


##- import .bashrc
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
fi

##- login startup scripts
source ${CONFIGS}/bash/x-OS-startup.sh;

##- Launch Zsh on bash startup
#not sure the difference between these two
# if [ -t 1 ]; then
#     exec zsh
# fi
if [ -d "${HOME}/.zshrc" ]; then
if ! [[ $OSis == *"Microsoft"* ]]; then
    eza --grid --sort=ext --group-directories-first --icons --color-scale;
fi
fi

#this is the one I generally use
if [[ $- == *i* ]]; then
    export SHELL=zsh
    exec zsh -l
fi
