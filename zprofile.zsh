# ~/.zprofile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# All my real stuff is kept in .zshrc but login only runs on first terminal open so this is a good place to put things that I only want to run on a new terminal, such as moving WSL to my custom home folder, running exa


##- import .zshrc

    # include .bashrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
    fi



##- 𝖃𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
##- Windows Subystem Layer
if [[ $UNAMECHECK == *"Microsoft"* ]] then
cd home;
exa;
##- Normal Linux
else
exa;
fi
##- macOS
elif [[ "$OSTYPE" == "darwin"* ]]; then
#prevents error of % popping up in terminal on login
setopt PROMPT_CR
setopt PROMPT_SP
export PROMPT_EOL_MARK=""
# run exa on start up to get context
exa;

else
   echo "current operating system is not accounted for in zsh config";
fi
