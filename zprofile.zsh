# ~/.zprofile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# All my real stuff is kept in .zshrc but login only runs on first terminal open so this is a good place to put things that I only want to run on a new terminal, such as moving WSL to my custom home folder, running eza

# fix trailing white space % error
# setopt PROMPT_CR
# setopt PROMPT_SP
 export PROMPT_EOL_MARK=""


##- import .zshrc
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
fi
##- login startup scripts
source ${CONFIGS}/bash/x-OS-startup.sh;
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# Created by `pipx` on 2025-05-30 18:40:22
export PATH="$PATH:/Users/aslan/.local/bin"
