##- 𝔠𝔯𝔬𝔰𝔰𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
# settings/variables
# variable to check uname so that can add if conditionals for WSL
UNAMECHECK=$(uname -a);


##- Windows Subystem Layer
if [[ $UNAMECHECK == *"Microsoft"* ]]; then
    # make homebrew available in sudo linux install
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
        if [ -d "./home" ]; then
            cd home;
        fi
    fi
fi #end of WSL

##- Normal Linux
if [[ "$OSTYPE" == *"linux-gnu"* ]]; then
    
    # make homebrew available in sudo linux install
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);
        
        # check if zsh is there before firing off exa
        if ! [ -f "${HOME}/.zshrc" ]; then
            ls;
        fi
        #end of sudo linux install
        
        #make available in non sudo linux install
        elif [ -d "${HOME}/.linuxbrew" ]; then
        eval $(${HOME}/.linuxbrew/bin/brew shellenv);
        # check if zsh is there before firing off exa
        if ! [ -f "${HOME}/.zshrc" ]; then
            ls;
        fi
        #end of nonsudo linux install
    else
        echo "homebrew not installed";
    fi
    
    #end of linux-gnu stuff
    
    ##- macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
    #prevents error of % popping up in terminal on login
    setopt PROMPT_CR
    setopt PROMPT_SP
    export PROMPT_EOL_MARK=""
    # make homebrew available in sudo mac install
    if [ -d "/usr/local/Cellar" ]; then
        eval $(/usr/local/bin/brew shellenv);
        # run exa on start up to get context
        ls;
    fi
    # end of mac elif
    
    ##- Error State
else
    echo "homebrew not installed";
fi
