## ██████╗  █████╗ ███████╗██╗  ██╗
## ██╔══██╗██╔══██╗██╔════╝██║  ██║
## ██████╔╝███████║███████╗███████║
## ██╔══██╗██╔══██║╚════██║██╔══██║
##██████╔╝██║  ██║███████║██║  ██║
## ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

##- Movement
function cd {
    builtin cd "$@" && exa
    }

# make a directory and then go inside it
function mkcdir ()
{
    mkdir -p -- "$1" &&
      cd -P -- "$1"
      exa
}
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

##- Set Path
# include ~/bin
 if [ -d "$HOME/bin" ] ; then
     PATH="$HOME/bin:$PATH"
 fi

# inlude ~/.local/bin
 if [ -d "$HOME/.local/bin" ] ; then
     PATH="$HOME/.local/bin:$PATH"
fi

# include Wordpress
 if [ -d "$HOME/bin/wp" ] ; then
    PATH="$HOME/bin/wp:$PATH"
fi

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
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
fi
fi

##- 𝗕𝗔𝗦𝗛 𝗣𝗥𝗢𝗠𝗣𝗧
# check if SSH
if [ -n "$SSH_CLIENT" ]; then
export SSHstatus="\e[30;103m ♆"
else
export SSHstatus="\e[30;103m ⚡";
fi


# not sure what this does
# set a fancy prompt (non-color, unless we know we "want" color)
# case "$TERM" in
#     xterm-color) color_prompt=yes;;
# esac
force_color_prompt=yes
TERM=xterm-256color

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
    else
    color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1="\n ${SSHstatus} \e[30;44m \w \[\033[00m\]\n    \e[96m⭄>> \e[0m \[\033[00m\]";

    # export PS1=$'   \e[0;34m \u2692\e[m\e[0;31m \u26A1  [\w] \e[m\e[0;36m >>>'
else
    PS1='\n \w>>> '
fi
# unset color_prompt force_color_prompt

alias reload="source ~/.bashrc";
