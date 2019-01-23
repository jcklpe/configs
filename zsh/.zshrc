# 𝖅𝖘𝖍 𝕾𝖕𝖊𝖑𝖑𝖇𝖔𝖔𝖐

# change ranger default editor
VISUAL=nano; export VISUAL EDITOR=nano; export EDITOR

# CMD binding
alias cmd='/mnt/c/Windows/System32/cmd.exe'

alias vscode="/mnt/c/'Program Files'/'Microsoft VS Code'/Code.exe"

#change npm to be restricted to user folder
 export PATH=~/.npm-global/bin:$PATH

# allow exa to run on ssh with part not adding to pay properly

alias exa=~/bin/exa --sort=ext  --group-directories-first


# Run nano with softwrapping always
alias nano='nano -\$cwS'

# add jump integration to ranger
# source /mnt/c/Users/David/Home/Documents/Configs/zsh/zsh-plugins/jump-ranger/jump-ranger.zsh
wd() {
     . ~/bin/wd/wd.sh
 }


POWERLEVEL9K_MODE="nerdfont-complete"
ZSH_DISABLE_COMPFIX=true




#𝗔𝗟𝗜𝗔𝗦𝗘𝗦
#Movement

#  add exa auto to cd command
function cd {
    builtin cd "$@" && exa --grid --sort=ext
    }

# make a directory and then go inside it
function mkcdir ()
{
    mkdir -p -- "$1" &&
      cd -P -- "$1"
}



# Add  color to ll
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls -F --color=auto 2>/dev/null -I "*NTUSER*" -I "*ntuser*"'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

#List everything including hidden stuff
lo() {
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

# List but formatted and colored without hidden stuff
lf() {
    ls -lF --color=always | awk '
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



# install with sudo apt all the time
    alias apt="sudo apt"
    alias apt-get="apt"
    alias apt-y="apt --yes"

# update on one command
 alias refresh='apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean -y'

## //- zsh related
 alias config-z="nano ~/.zshrc"

 # update zsh settings
  alias reload='source ~/.zshrc'


#List users
alias list-users='cut -d: -f1 /etc/passwd'

#What's installed?
 alias list-npm='npm list -g --depth=0'
 alias list-apt='sudo apt list --installed'

#NPM plain english aliases
alias builder='npm run build'
alias watcher='npm run watch'



 case $(uname -a) in
*Microsoft*) unsetopt BG_NICE ;;
esac

#//- GIT related
# lazy git add commit push all in one
function gitall() {
    git add .
    git commit -a -m "$1"
    git push origin
}

##//-Tests
 alias testbold='bold=$(tput bold) && normal=$(tput sgr0) && echo "this is ${bold}bold${normal} but this aint"'

  ##//- THEMES
 source  ~/bin/powerlevel9k/powerlevel9k.zsh-theme

 #//- Theme Settings

 ZSH_THEME="powerlevel9k/powerlevel9k"

POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=1
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon root_indicator dir_writable dir)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status newline vcs)
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="%F{green}┌─%f"
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="%F{green}└─➤ %f"
POWERLEVEL9K_DIR_BOLD=true


POWERLEVEL9K_STATUS_VERBOSE=true
POWERLEVEL9K_STATUS_CROSS=true

DEFAULT_FOREGROUND=004 DEFAULT_BACKGROUND=235
DEFAULT_COLOR=$DEFAULT_FOREGROUND

POWERLEVEL9K_VCS_CLEAN_BACKGROUND="green"
POWERLEVEL9K_VCS_CLEAN_FOREGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND="yellow"
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND="red"
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND="$DEFAULT_BACKGROUND"

POWERLEVEL9K_DIR_HOME_BACKGROUND="$DEFAULT_FOREGROUND"
POWERLEVEL9K_DIR_HOME_FOREGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND="$DEFAULT_FOREGROUND"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_DIR_DEFAULT_BACKGROUND="$DEFAULT_FOREGROUND"
POWERLEVEL9K_DIR_DEFAULT_FOREGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_BACKGROUND="$DEFAULT_FOREGROUND"
POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_FOREGROUND="$DEFAULT_BACKGROUND"

POWERLEVEL9K_STATUS_OK_FOREGROUND="$DEFAULT_FOREGROUND"
POWERLEVEL9K_STATUS_OK_FOREGROUND="green"
POWERLEVEL9K_STATUS_OK_BACKGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_STATUS_OK_BACKGROUND="$(( $DEFAULT_BACKGROUND + 2 ))"

POWERLEVEL9K_STATUS_ERROR_FOREGROUND="$DEFAULT_FOREGROUND"
POWERLEVEL9K_STATUS_ERROR_FOREGROUND="red"
POWERLEVEL9K_STATUS_ERROR_BACKGROUND="$DEFAULT_BACKGROUND"
POWERLEVEL9K_STATUS_ERROR_BACKGROUND="$(( $DEFAULT_BACKGROUND + 2 ))"

POWERLEVEL9K_HISTORY_FOREGROUND="$DEFAULT_FOREGROUND"

#Icon config
POWERLEVEL9K_SUB_ICON='\UF07C'
POWERLEVEL9K_FOLDER_ICON='\UF07B'
#POWERLEVEL9K_STATUS_OK_ICON='\UF2B0'
POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='\UE0BC'
POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR="%F{$(( $DEFAULT_BACKGROUND - 2 ))}|%f"
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='\UE0BA'
POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR="%F{$(( $DEFAULT_BACKGROUND - 2 ))}|%f"

COMPLETION_WAITING_DOTS="true"

##//- PLUGINS

#//- syntax highlighting
source ~/bin/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#//- Zsh Auto-suggestions

source ~/bin/zsh-autosuggestions/zsh-autosuggestions.zsh


# ranger added to path
alias ranger=~/bin/ranger/ranger.py
