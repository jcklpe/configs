# ~/.zprofile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# All my real stuff is kept in .zshrc but login only runs on first terminal open so this is a good place to put things that I only want to run on a new terminal, such as moving WSL to my custom home folder, running exa

# fix trailing white space % error
# setopt PROMPT_CR
# setopt PROMPT_SP
 export PROMPT_EOL_MARK=""


##- import .zshrc
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
fi
##- login startup scripts
eval "$(jump shell)"
source ${CONFIGS}/bash/x-OS-startup.sh;
eval "$(/opt/homebrew/bin/brew shellenv)"
