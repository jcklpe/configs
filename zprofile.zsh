# ~/.zprofile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# All my real stuff is kept in .zshrc but login only runs on first terminal open so this is a good place to put things that I only want to run on a new terminal, such as moving WSL to my custom home folder, running exa


##- import .zshrc

    # include .bashrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
    fi


##- 𝔠𝔯𝔬𝔰𝔰𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);

# make homebrew available in non-sudo installs
if [ -d "${HOME}/.linuxbrew" ]; then
eval $(${HOME}/.linuxbrew/bin/brew shellenv);
exa;
fi


##- Windows Subystem Layer
if [[ $UNAMECHECK == *"Microsoft"* ]] then
# make homebrew available in sudo linux install
# make homebrew available in sudo linux install
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
    if [ -d "./home" ]; then
        cd home;
    else
        exa;
    fi
fi

##- Normal Linux
else
# make homebrew available in sudo linux install
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
exa;
fi

fi
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
