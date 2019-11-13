#!/bin/bash
##- Install list for manual installation of binaries with sudo
#init all submodules recursively
git submodule update --recursive ;
##- Check operating systems
    ##- LINUX AND WSL
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        UNAMECHECK=$(uname -a);
        ##- apt installs
        #zsh
        apt install zsh;

        #midnight commander
        apt install mc;

        #ranger
        apt install ranger;

        ##- brew installs
        install brew
        install stuff via brew that cant be install via apt

        ##- manual installations
        install stuff by wget etc that cant be installed via apt/brew

    ##- Windows Subystem Layer Only
        if [[ $UNAMECHECK == *"Microsoft"* ]] then
        #set variables
        export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
        export WINHOME=${WINHOME//$'\015'};
        CONFIGS="${WINHOME}/home/Documents/configs";

        ##- symlink config files
        #symlink normal linux configs to $HOME

        #symlink Windows configs to $WINHOME

    ##- Linux ONLY
    else
        #set variables
        CONFIGS="$HOME/configs";

        ##- symlink config files
        #symlink configs to $HOME

    fi #end of checking linux or WSL

    fi #end of linux-gnu

    ##- else if macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        #settings variables
        CONFIGS="$HOME/configs";

        #install brew

        ##- brew installs

        # symlink configs to $HOME
        symlink configs to $HOME
    else
    echo "this install script doesn't support this OS";
    exit;
    fi
