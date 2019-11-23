# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# Everything useful is put in .bashrc but this allows me to selectively trigger scripts only at shell start up

#variables
UNAMECHECK=$(uname -a);


##- import .bashrc
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
    fi
fi

##- 𝔠𝔯𝔬𝔰𝔰𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then


# make homebrew available in non-sudo installs
if [ -d "${HOME}/.linuxbrew" ]; then
eval $(${HOME}/.linuxbrew/bin/brew shellenv);
exa;
fi


##- Windows Subystem Layer
if [[ $UNAMECHECK == *"Microsoft"* ]]; then
# make homebrew available in sudo linux install
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
    if [ -d "./home" ]; then
        cd home;

    fi
fi

##- Normal Linux
else
# make homebrew available in sudo linux install
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
exa;
fi

fi #end of linux-gnu stuff
##- macOS
elif [[ "$OSTYPE" == "darwin"* ]]; then
#prevents error of % popping up in terminal on login
setopt PROMPT_CR
setopt PROMPT_SP
export PROMPT_EOL_MARK=""
# make homebrew available in sudo mac install
if [ -d "/usr/local/Cellar" ]; then
eval $(/usr/local/bin/brew shellenv);
# run exa on start up to get context
exa;
fi

##- Error State
else
   echo "current operating system is not accounted for in zsh config";
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
