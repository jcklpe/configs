# VS Code terminal integration - must load first
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

##- 𝒛𝖘𝖍 𝖘𝖕𝖊𝖑𝖑𝖇𝖔𝖔𝖐

#varaible for configs folder
CONFIGS="$HOME/configs";

##- set up cross os mappings
source ${CONFIGS}/bash/x-OS-mapping.sh;

##- VARIABLES
PLUGINS="${CONFIGS}/plugins";

##- zsh related
alias config="nano ~/.zshrc";
alias reload='source ~/.zshrc';

# Run nano with better defaults
alias nano='nano --const --mouse';

##- Theme Settings
export TERM="xterm-256color"

# Use Powerlevel10k only outside VS Code (it breaks terminal integration)
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    POWERLEVEL9K_MODE="nerdfont-complete"
    ZSH_DISABLE_COMPFIX=true
    source ${CONFIGS}/prompt.zsh
else
    # Simple prompt for VS Code
    PROMPT='%F{green}%~%f %# '
fi

##- Additional aliases
alias testbold='bold=$(tput bold) && normal=$(tput sgr0) && echo "this is ${bold}bold${normal} but this aint"'
alias testcolor='${PLUGINS}/Color-Scripts/color-scripts/colorview'
alias test256color='${PLUGINS}/Color-Scripts/test-color-support/color-support2'
alias mount='mount |column -t'

# Replace rm with trash if available
if [ -x "$(command -v trash)" ]; then
  alias rm='trash'
fi

# function to run vscode as admin
function sudocode () {
  sudo code --user-data-dir="~/.vscode-root"
}

##- Scripts

source ${CONFIGS}/movement/movement.zsh;

source ${CONFIGS}/apt/apt.zsh;
source ${CONFIGS}/image-utilities/image-utilities.zsh;
source ${CONFIGS}/list/list.zsh;
source ${CONFIGS}/npm/npm.zsh;
source ${CONFIGS}/nextcloud/nextcloud.zsh;
source ${CONFIGS}/git/git.zsh;

##- PLUGINS
##- syntax highlighting
source ${PLUGINS}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

##- Zsh Auto-suggestions
source ${PLUGINS}/zsh-autosuggestions/zsh-autosuggestions.zsh

##- jump directories
# add jump integration to ranger
source ${PLUGINS}/jump-ranger/jump-ranger.zsh

##- warp door
wd() {
    source ${PLUGINS}/wd/wd.sh
}

##- you should use
source ${PLUGINS}/zsh-you-should-use/you-should-use.plugin.zsh

##### this is the end of the file. anything beyond here has been auto appended by some trash scripts
#######################

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Created by `pipx` on 2025-05-30 18:40:22
export PATH="$PATH:/Users/aslan/.local/bin"
export PATH="/Users/aslan/.pixi/bin:$PATH"

# stuff for enzo lang development
alias run='poetry run';

alias python='python3';
