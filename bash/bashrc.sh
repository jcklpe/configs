## ██████╗  █████╗ ███████╗██╗  ██╗
## ██╔══██╗██╔══██╗██╔════╝██║  ██║
## ██████╔╝███████║███████╗███████║
## ██╔══██╗██╔══██║╚════██║██╔══██║
## ██████╔╝██║  ██║███████║██║  ██║
## ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
#varaible for configs folder
CONFIGS="$HOME/configs";

##- set up cross os mappings
source ${CONFIGS}/bash/x-OS-mapping.sh;

source ${CONFIGS}/movement/movement.zsh;


##- MISC Settings
# Hist file length and size
HISTSIZE=1000
HISTFILESIZE=2000

# append to the history file, don't overwrite it
shopt -s histappend

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# check the window size after each command and, if necessary,
shopt -s checkwinsize

# enable globstar (/**/) (Doesn't work properly on mac)
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# enable programmable completion features (you don't need to enable
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
        elif [ -f /etc/bash_completion ]; then
        source /etc/bash_completion
    fi
fi

##- Prompt/Theme
source ${CONFIGS}/bash/prompt.sh;

##-PLUGINS
source ${CONFIGS}/apt/apt.zsh;
source ${CONFIGS}/image-utilities/image-utilities.zsh;
source ${CONFIGS}/hue/hue.zsh;
source ${CONFIGS}/list/list.zsh;
source ${CONFIGS}/npm/npm.zsh;
source ${CONFIGS}/nextcloud/nextcloud.zsh;
source ${CONFIGS}/git/git.zsh;


alias reload="source ~/.bashrc";
complete -C /usr/local/bin/bit bit

# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
