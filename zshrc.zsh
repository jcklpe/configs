
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

# function to run vscode as admin
function sudocode () {
  sudo code --user-data-dir="~/.vscode-root"
}




##- Scripts

source ${CONFIGS}/movement/movement.zsh;
alias .='cd ..'; # this is here because it messes up bash

source ${CONFIGS}/apt/apt.zsh;
source ${CONFIGS}/image-utilities/image-utilities.zsh
source ${CONFIGS}/list/list.zsh;
source ${CONFIGS}/npm/npm.zsh;
source ${CONFIGS}/nextcloud/nextcloud.zsh;
source ${CONFIGS}/git/git.zsh;






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
# eval "$(jump shell)"

# add jump integration to ranger
source ${PLUGINS}/jump-ranger/jump-ranger.zsh

##- warp door
wd() {
    source ${PLUGINS}/wd/wd.sh;
    }


##- you should use
source ${PLUGINS}/zsh-you-should-use/you-should-use.plugin.zsh


##### this is the end of the file. anything beyond here has been auto appended by some trash scripts
#######################

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
