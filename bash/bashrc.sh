## ██████╗  █████╗ ███████╗██╗  ██╗
## ██╔══██╗██╔══██╗██╔════╝██║  ██║
## ██████╔╝███████║███████╗███████║
## ██╔══██╗██╔══██║╚════██║██╔══██║
## ██████╔╝██║  ██║███████║██║  ██║
## ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

# Silence macOS bash deprecation warning
# (Mac post-Catalina complains when bash is the login shell instead of zsh)
export BASH_SILENCE_DEPRECATION_WARNING=1

# Initialize CONFIGS and PLUGINS
# Follow the entrypoint symlink so a side-by-side checkout loads its own init.
if [ -n "${BASH_VERSION:-}" ]; then
    _configs_bootstrap() {
        local entry="$1" target root hops=0
        while [ -L "$entry" ]; do
            [ "$hops" -lt 40 ] || return 1
            hops=$((hops + 1))
            target="$(readlink "$entry")" || return 1
            case "$target" in
                /*) entry="$target" ;;
                *) entry="$(dirname "$entry")/$target" ;;
            esac
        done
        root="$(cd -P "$(dirname "$entry")/.." && pwd)" || return 1
        source "$root/init.sh"
    }
    _configs_bootstrap "${BASH_SOURCE[0]}" || return
    unset -f _configs_bootstrap
else
    source "$HOME/configs/init.sh" || return
fi

# Load PATH tools and environment managers
source ${CONFIGS}/path.sh

source ${CONFIGS}/movement/movement.sh;


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
source ${CONFIGS}/bash/prompt.bash;

##- Load shell modules
source ${CONFIGS}/load-shell-modules.sh

alias reload="source ~/.bashrc";
