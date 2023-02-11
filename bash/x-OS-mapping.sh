##- CROSS-𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
# settings/variables
# variables
CONFIGS="$HOME/configs";
OSis=$(uname -a);

##- Windows Subystem Layer
if [[ $OSis == *"Microsoft"* ]]; then
    #windows specific variables
    export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
    export WINHOME=${WINHOME//$'\015'};
    CONFIGS="${WINHOME}/home/Documents/configs";

    #extra windows specific commands
    alias cmd='/mnt/c/Windows/System32/cmd.exe';
    alias vscode="/mnt/c/'Program Files'/'Microsoft VS Code'/Code.exe";

    # make homebrew available in sudo linux install
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);

    fi
fi #end of WSL





##- Normal Linux
if [[ "$OSTYPE" == *"linux-gnu"* ]]; then

    # add torch to commands available
    if [[ -d "${HOME}/torch" ]]; then
    source ${HOME}/torch/install/bin/torch-activate
    fi

    # make homebrew available in sudo linux install
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);

        #end of sudo linux install

        #make available in non sudo linux install
        elif [ -d "${HOME}/.linuxbrew" ]; then
        eval $(${HOME}/.linuxbrew/bin/brew shellenv);

        #end of nonsudo linux install
    else
        echo "homebrew not installed";
    fi

    #end of linux-gnu stuff

    ##- macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
    # make homebrew available in sudo mac install
    if [ -d "/usr/local/Cellar" ]; then
        eval $(/usr/local/bin/brew shellenv);
    fi
    # fix ngrok issue for work mac
    alias ngrok-8080='/Applications/ngrok http --host-header=rewrite 8080';
    alias ngrok-3000='/Applications/ngrok http --host-header=rewrite 3000';
    # end of mac elif

    ##- Error State
else
    echo "homebrew not installed";
fi