
##- 𝒛𝖘𝖍 𝖘𝖕𝖊𝖑𝖑𝖇𝖔𝖔𝖐

#varaible for configs folder
CONFIGS="$HOME/configs";

##- set up cross os mappings
source ${CONFIGS}/bash/x-OS-mapping.sh;

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

#replace rm with trash
if [ -x "$(command -v trash)" ]; then
  alias rm='trash';
fi

# Run nano cursor always visible, smooth scrolling on, use the mouse, and disable hard wrapping.
alias nano='nano --const --smooth --mouse';

# replace nano with micro
# if [ -x "$(command -v micro)" ]; then
#     alias nano='micro';
# fi

# fix python2 to run python3
#alias python=python3


##- Scripts

source ${CONFIGS}/movement/movement.zsh;
alias .='cd ..'; # this is here because it messes up bash

source ${CONFIGS}/apt/apt.zsh;
source ${CONFIGS}/image-utilities/image-utilities.zsh
source ${CONFIGS}/hue/hue.zsh
source ${CONFIGS}/list/list.zsh;
source ${CONFIGS}/npm/npm.zsh;
source ${CONFIGS}/nextcloud/nextcloud.zsh;
source ${CONFIGS}/git/git.zsh;
source ${CONFIGS}/neural-art-scripts/load-neural-art-scripts.zsh



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
#source ${PLUGINS}/zsh-bd/bd.zsh

##- you should use
source ${PLUGINS}/zsh-you-should-use/you-should-use.plugin.zsh
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/bit bit
