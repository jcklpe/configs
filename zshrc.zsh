
##   ______ _____  _   _   _____               _  _ ______                _
##  |___  //  ___|| | | | /  ___|             | || || ___ \              | |
##     / / \ `--. | |_| | \ `--.  _ __    ___ | || || |_/ /  ___    ___  | | __
##    / /   `--. \|  _  |  `--. \| '_ \  / _ \| || || ___ \ / _ \  / _ \ | |/ /
##  ./ /___/\__/ /| | | | /\__/ /| |_) ||  __/| || || |_/ /| (_) || (_) ||   <
##  \_____/\____/ \_| |_/ \____/ | .__/  \___||_||_|\____/  \___/  \___/ |_|\_\
##                               | |
##                               |_|



##- 𝖃𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
    if [[ $UNAMECHECK == *"Microsoft"* ]] then
##- Windows Subystem Layer
# variables
export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
# clean up winhome carriage return error
export WINHOME=${WINHOME//$'\015'};
# set home level config paths.
CONFIGS="${WINHOME}/home/Documents/configs";

# background jobs run at lower priority
#unsetopt BG_NICE

# add X server to WSL to open Linux GUI apps
# export DISPLAY=localhost:0.0

# CMD binding
alias cmd='/mnt/c/Windows/System32/cmd.exe';
alias vscode="/mnt/c/'Program Files'/'Microsoft VS Code'/Code.exe";

else
##- Normal Linux
#variables
CONFIGS="$HOME/configs";

# add torch to commands available
source $HOME/torch/install/bin/torch-activate
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
##- macOS
# variables
CONFIGS="$HOME/configs"
# fix ngrok issue for work mac
alias ngrok-8080='/Applications/ngrok http --host-header=rewrite 8080';
alias ngrok-3000='/Applications/ngrok http --host-header=rewrite 3000'

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

##- VARIABLES
PLUGINS="${CONFIGS}/plugins";



##- zsh related
 alias config="nano ~/.zshrc";

 # update zsh settings
 alias reload='source ~/.zshrc';

 #tests
 alias testbold='bold=$(tput bold) && normal=$(tput sgr0) && echo "this is ${bold}bold${normal} but this aint"';

 alias testcolor='${PLUGINS}/Color-Scripts/color-scripts/colorview';
 alias test256color='${PLUGINS}/Color-Scripts/test-color-support/color-support2';

 ##- small fixes
#make mount look prettier
alias mount='mount |column -t';

#alias rm='trash';

# Run nano cursor always visible, smooth scrolling on, use the mouse, and disable hard wrapping.
alias nano='nano --const --smooth --mouse';

if [ -x "$(command -v micro)" ]; then
    alias nano='micro';
fi

# fix python2 to run python3
#alias python=python3


##- Scripts

source ${CONFIGS}/movement/movement.zsh;
source ${CONFIGS}/apt/apt.zsh;
source ${CONFIGS}/image-utilities/image-utilities.zsh
source ${CONFIGS}/hue/hue.zsh
source ${CONFIGS}/list/list.zsh;
source ${CONFIGS}/npm/npm.zsh;
source ${CONFIGS}/nextcloud/nextcloud.zsh;
source ${CONFIGS}/git/git.zsh;
source ${CONFIGS}/secrets/ssh.zsh


##- Theme Settings
#- Necessary to enable 256 colors in terminal
 export TERM="xterm-256color"

POWERLEVEL9K_MODE="nerdfont-complete"
ZSH_DISABLE_COMPFIX=true

source ${CONFIGS}/prompt.zsh




##- PLUGINS
##- syntax highlighting
source ${PLUGINS}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

##- Zsh Auto-suggestions
source ${PLUGINS}/zsh-autosuggestions/zsh-autosuggestions.zsh

##- jump directories
eval "$(jump shell zsh)"

# add jump integration to ranger
source ${PLUGINS}/jump-ranger/jump-ranger.zsh

##- warp door
wd() {
    source ${PLUGINS}/wd/wd.sh;
    }

##- bd (cd for parent directories)
source ${PLUGINS}/zsh-bd/bd.zsh

##- you should use
source ${PLUGINS}/zsh-you-should-use/you-should-use.plugin.zsh
