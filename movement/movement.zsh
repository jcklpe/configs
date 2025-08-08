##- Movement


##- ls baselines

# Add  color to ls
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls -F --color=auto 2>/dev/null -I "*NTUSER*" -I "*ntuser*"'
    alias grep='grep --color=auto'

fi

#List everything including hidden stuff in long view with neat columns
function lx() {
    ls -AlF --color=always | awk '
        BEGIN {
            FPAT = "([[:space:]]*[^[:space:]]+)";
            OFS = "";
        }
        {
            $2 = "\033[31m" $2 "\033[0m";
            $3 = "\033[36m" $3 "\033[0m";
            $4 = "\033[36m" $4 "\033[0m";
            $5 = "\033[31m" $5 "\033[0m";
            $6 = "\033[36m" $6 "\033[0m";
            $7 = "\033[36m" $7 "\033[0m";
            $8 = "\033[31m" $8 "\033[0m";
            #$9 = "\033[7;44;1;33m" $9 "\033[0m";

            print
        }
    '
}

#  add exa auto to cd command
function go {
    builtin cd "$@" && ls;
}

# make a directory and then go inside it
function mkcdir ()
{
    mkdir -p -- "$1" &&
    cd -P -- "$1"
}

function peek() {
    ls -a
}


##- exa improvement overrides
# check to see if exa is installed
if [[ $(type exa) = *bin/exa* ]]; then

    #set default exa to ls for better compatibility between scripts
    function ls() {
        command exa --grid --sort=ext --group-directories-first --icons --color-scale;
    }

    function lx() {
        exa --long  --header --git --color-scale -a;
    }

    function tree() {
        exa --tree --level=2  --header --git --color-scale;
    }

    function peek() {
    exa --grid --sort=ext --group-directories-first --icons --color-scale -a
}

fi

# get rid of command not found
alias cd..='cd ..';

# a quick way to get out of current directory

alias ..='cd ../../';
alias ...='cd ../../../';
alias ....='cd ../../../../';
alias .....='cd ../../../../';
alias .4='cd ../../../../';
alias .5='cd ../../../../..';

alias cd2="cd ../..";
alias cd3='cd ../../../';
alias cd4='cd ../../../../';
alias cd5='cd ../../../../..';
alias cd6='cd ../../../../../..';
alias cd7='cd ../../../../../../..';