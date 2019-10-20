#!/bin/bash
##- INSTALL SCRIPT FOR CONFIGS
#git clone configs gitrepo

#init all submodules recursively
git submodule update --recursive ;


##- If has sudo
if test -w | /usr/bin/sudo -p "Do you have sudo? Enter password to proceed:"; then
    ##- Check operating systems
    #-- If linux or WSL
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
    ## Install stuff
    install stuff via apt
    install brew
    install stuff via brew that cant be install via apt

        #-- Windows Subystem Layer
        if [[ $UNAMECHECK == *"Microsoft"* ]] then
        # variables
        export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
        export WINHOME=${WINHOME//$'\015'};
        CONFIGS="${WINHOME}/home/Documents/configs";

        symlink normal linux configs to $HOME
        symlink Windows configs to $WINHOME

    #-- Normal Linux
    else
        CONFIGS="$HOME/configs";
        symlink configs to $HOME
    fi #end of checking linux or WSL

    fi #end of linux-gnu

    #-- else if macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "this is a mac";
    install brew
    CONFIGS="$HOME/configs";
    symlink configs to $HOME
    else
    echo "this install script doesn't support this OS";
    fi

##- else does not have sudo
else
	echo "you don't have sudo"
     ## Install stuff
    install brew to ~/.brew
    install using brew
    install using gitclone/wget to ~/.bin
    symlink or alias gitclone/wget to ~/.bin
    symlink configs to $HOME
fi
