##- Movement
alias exa=exa --grid --sort=ext --group-directories-first

#  add exa auto to cd command
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



# Add  color to ls
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls -F --color=auto 2>/dev/null -I "*NTUSER*" -I "*ntuser*"'
    alias grep='grep --color=auto'

fi

#List everything including hidden stuff
lh() {
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

alias exa-lo='exa --long --grid --sort=ext --header --git --color-scale';

# get rid of command not found
alias cd..='cd ..'

# a quick way to get out of current directory
 alias ..='cd ..'
 alias ...='cd ../../../'
 alias ....='cd ../../../../'
 alias .....='cd ../../../../'
 alias .4='cd ../../../../'
 alias .5='cd ../../../../..'

 alias cd2="cd ../.."
 alias cd3='cd ../../../'
 alias cd4='cd ../../../../'
 alias cd5='cd ../../../../..'
 alias cd6='cd ../../../../../..'
 alias cd7='cd ../../../../../../..'