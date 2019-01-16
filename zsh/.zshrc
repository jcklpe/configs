# 𝖅𝖘𝖍 𝕾𝖕𝖊𝖑𝖑𝖇𝖔𝖔𝖐

# CMD binding
alias cmd='/mnt/c/Windows/System32/cmd.exe'

alias vscode="/mnt/c/'Program Files'/'Microsoft VS Code'/Code.exe"

# Run nano with softwrapping always

alias nano='nano -\$cwS'

# add jump integration to ranger
source /mnt/c/Users/David/Home/Documents/Configs/zsh/zsh-plugins/jump-ranger.zsh

## PER OS SETTINGS
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
    if [[ $UNAMECHECK == *"Microsoft"* ]]
        then
        # WSL
        # add X server to WSL to open Linux GUI apps
export DISPLAY=localhost:0.0

    else
        # Normal Linux
        . /home/david/torch/install/bin/torch-activate
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
    # fucking fancy-ass Mac OSX

elif [[ "$OSTYPE" == "cygwin" ]]; then
    # POSIX compatibility layer and Linux environment emulation for Windows

elif [[ "$OSTYPE" == "msys" ]]; then
    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)

elif [[ "$OSTYPE" == "win32" ]]; then
    # lol

elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # Maybe a Nintendo Switch?

else
    # Unknown.
fi






POWERLEVEL9K_MODE="nerdfont-complete"
ZSH_DISABLE_COMPFIX=true




#𝗔𝗟𝗜𝗔𝗦𝗘𝗦
#Movement

#add directory history function to cd
source ~/shell-scripts/acd_func.sh;

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


## can't seem to get it to work
## https://unix.stackexchange.com/questions/157763/do-we-have-more-history-for-cd
# add the ability to cd to previously visited directories
#setopt AUTO_PUSHD                  # pushes the old directory onto the stack
#setopt PUSHD_MINUS                 # exchange the meanings of '+' and '-'
#setopt CDABLE_VARS                 # expand the expression (allows 'cd -2/tmp')
#autoload -U compinit && compinit   # load + start completion
# zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12

removeLAMP() {
    /etc/init.d/mysql stop ||
    service mysql stop ||
    killall -KILL mysql mysqld_safe mysqld ||
    sudo apt-get remove --purge apache2-bin -y &&
    sudo apt-get remove --purge apache2-data -y &&
    sudo apt-get remove --purge apache2-utils -y &&
    sudo apt-get purge apache2 -y &&
    sudo apt-get purge apache2-mpm-prefork -y ||
    sudo apt-get purge apache2-utils -y ||
    sudo apt-get purge apache2.2-common -y ||
    sudo apt-get purge libapache2-mod-php5 -y ||
    sudo apt-get purge libapr1 -y ||
    sudo apt-get purge libaprutil1 -y &&
    sudo apt-get purge libdbd-mysql-perl -y &&
    sudo apt-get purge libdbi-perl -y &&
    sudo apt-get purge libmysqlclient15off -y &&
    sudo apt-get purge libnet-daemon-perl -y &&
    sudo apt-get purge libplrpc-perl -y &&
    sudo apt-get purge libpq5 -y &&
    sudo apt-get purge php-common &&
    sudo apt-get purge php-mysql &&
    sudo apt-get purge php7.2-cli &&
    sudo apt-get purge php7.2-common &&
    sudo apt-get purge php7.2-json &&
    sudo apt-get purge php7.2-mysql &&
    sudo apt-get purge php7.2-opcache &&
    sudo apt-get purge php7.2-readline &&
    sudo apt-get purge mysql-client-core-5.7 -y &&
        apt-get purge mysql-server-core-5.7 -y &&
    sudo apt-get purge mysql-server-5.7 -y &&
    sudo apt-get purge mysql-client-5.0 -y &&
    sudo apt-get purge mysql-common -y &&
    sudo apt-get purge mysql-server -y &&
    sudo apt-get purge mysql-server-5.0 -y &&
    sudo apt-get purge php5-common -y &&
    sudo apt-get purge php5-mysql -y &&
    sudo apt-get purge mysql-client -y &&
    sudo apt-get purge dbconfig-mysql -y &&
    # sudo apt-get purge php5-mysql -y &&
    # sudo apt-get purge php5-mysql -y &&
    sudo rm -rf /var/lib/mysql/mysql -y &&
    sudo apt-get autoremove -y &&
    sudo apt-get autoclean -y &&
    sudo apt update -y &&
    sudo apt upgrade -y
}

#make mount look prettier
alias mount='mount |column -t'

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
 alias configure-zsh="nano ~/.zshrc"

 # update bash and zsh settings
 alias reload-bash='source ~/.bashrc'
 alias reload-zsh='source ~/.zshrc'
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

#//- nMap stuff
source ~/shell-scripts/nmap


##//-Tests
 alias testbold='bold=$(tput bold) && normal=$(tput sgr0) && echo "this is ${bold}bold${normal} but this aint"'

 alias color-check='./shell-scripts/Color-Scripts/color-scripts/colorview'



 ##//- THEMES
 source  ~/Documents/Configs/zsh/powerlevel9k/powerlevel9k.zsh-theme



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
source ~/Documents/Configs/zsh/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#//- jump directories
eval "$(jump shell zsh)"

#//-  fasd directories (like j but weighted towards recent history)
eval "$(fasd --init auto)"



#//- Zsh Auto-suggestions

source ~/Documents/Configs/zsh/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh


# show menu when starting up
#ls

#//- warp door

wd() {
  . /home/david/bin/wd/wd.sh
}

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"


#source ~/.xsh
# xsh is fun but it don't work right!
