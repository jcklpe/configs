
##   ______ _____  _   _   _____               _  _ ______                _
##  |___  //  ___|| | | | /  ___|             | || || ___ \              | |
##     / / \ `--. | |_| | \ `--.  _ __    ___ | || || |_/ /  ___    ___  | | __
##    / /   `--. \|  _  |  `--. \| '_ \  / _ \| || || ___ \ / _ \  / _ \ | |/ /
##  ./ /___/\__/ /| | | | /\__/ /| |_) ||  __/| || || |_/ /| (_) || (_) ||   <
##  \_____/\____/ \_| |_/ \____/ | .__/  \___||_||_|\____/  \___/  \___/ |_|\_\
##                               | |
##                               |_|

##- VARIABLES
CONFIGS="$HOME/configs"
pluginz="${CONFIGS}/zsh/shell-scripts"

alias rm=trash



##- Imports

#pull in utility zsh scripts
source ${pluginz}/utilities.zsh

# pull in hue scripts
source ~/configs/hue/hue.zsh

# Run nano with softwrapping always
alias nano='nano -\$cwS'

# fix python2 to run python3

#alias python=python3

#- Necessary to enable 256 colors in terminal
 export TERM="xterm-256color"

POWERLEVEL9K_MODE="nerdfont-complete"
ZSH_DISABLE_COMPFIX=true




##- 𝗔𝗟𝗜𝗔𝗦𝗘𝗦
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



##- Add  color to ls
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


## apt related
# install with sudo apt all the time
    alias apt="sudo apt"
    alias apt-get="apt"
    alias apt-y="apt --yes"

# update on one command
 alias apt-refresh='apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean -y'

##- zsh related
 alias configz="nano ~/.zshrc"

 # update zsh settings
 alias reload='source ~/.zshrc'

##- List stuff
#List users
alias list-users='cut -d: -f1 /etc/passwd'

#What's installed?
 alias list-npm='npm list -g --depth=0'
 alias list-apt='sudo apt list --installed'

# human readable path check
alias list-path='tr ':' '\n' <<< "$PATH"';

# list deps for a program
list-deps () {
echo "enter Package"
read Package

apt-cache depends --no-pre-depends --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $Package | grep -E "(qt|gtk|kde)"

}


##- Node related
#NPM plain english aliases
alias builder='npm run build'
alias watcher='npm run watch'

##- Nextcloud related
# list all apps
alias nc-list='cd /var/www/nextcloud && sudo -u www-data php occ app:list'

#scan and clean up files
alias nc-scan='cd /var/www/nextcloud && sudo -u www-data php occ files:cleanup'

# turn off and on safe mode
alias nc-on='cd /var/www/nextcloud && sudo -u www-data php occ maintenance:mode --on'
alias nc-off='cd /var/www/nextcloud && sudo -u www-data php occ maintenance:mode --off'

alias nc-repair='cd /var/www/nextcloud && sudo -u www-data php occ maintenance:repair'






##- GIT related
# lazy git add commit push all in one
function gitall() {
    git add .
    git commit -a -m "$1"
    git push origin
}

# git submodule add
alias gsub='git submodule add'

# create a new branch of a git you are currently on
alias git-create='git checkout -b master'

# pull from master branch and discard old changes
alias git-pull-refresh='git stash && git pull'

alias git-uncommit=' git reset --soft HEAD^'


##-Tests
 alias testbold='bold=$(tput bold) && normal=$(tput sgr0) && echo "this is ${bold}bold${normal} but this aint"'

 alias test-color='~/configs/zsh/shell-scripts/Color-Scripts/color-scripts/colorview'


##- Theme Settings

source ~/configs/zsh/zsh-plugins/prompt.zsh


##- PLUGINS
##- syntax highlighting
source ~/configs/zsh/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

##- Zsh Auto-suggestions
source ~/configs/zsh/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

##- jump directories
eval "$(jump shell zsh)"

# add jump integration to ranger
source ~/configs/zsh/zsh-plugins/jump-ranger/jump-ranger.zsh

##- warp door
wd() {
  source ~/configs/zsh/zsh-plugins/wd/wd.sh;

}

##- you should use
source ~/configs/zsh/zsh-plugins/zsh-you-should-use/you-should-use.plugin.zsh


##- PER OS SETTINGS
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
    if [[ $UNAMECHECK == *"Microsoft"* ]]
        then
            # WSL
            # add X server to WSL to open Linux GUI apps
           # export DISPLAY=localhost:0.0

            # the below was in my config but I don't know why. It's left over from something. Seems to be unsetting the default zsh option that makes background stuff a lower priority
            unsetopt BG_NICE

            # CMD binding
            alias cmd='/mnt/c/Windows/System32/cmd.exe'
            alias vscode="/mnt/c/'Program Files'/'Microsoft VS Code'/Code.exe"

    else
        # Normal Linux
        . /home/david/torch/install/bin/torch-activate
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
    # fucking fancy-ass Mac OSX

    # fix ngrok issue for work mac
alias ngrok='/Applications/ngrok http --host-header=rewrite 8080'

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
