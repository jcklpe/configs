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
        #install brew
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)";

        #install brew deps
        sudo apt install build-essential;

        # add brew to path
        eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);

        #install brew version of gcc for easier building
        brew install gcc

        #install stuff via brew that cant be install via apt
         brew install exa;
         brew install jump;
         brew install micro;

         # the following can be installed in other ways than brew and will install in non standard locations but maybe that's okay?
         #brew install visual-studio-code;

        ##- manual installations
        install stuff by wget etc that cant be installed via apt/brew

        ##- symlink stuff to $HOME
        .bashrc
        .profile
        .gitconfig
        .hyper.js
        .zshrc
        .zprofile

        vscode settings
        micro which is under .config



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


        ##- brew installs
        #install brew
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

        # need to include the after install message here but can't until I run this on a sudo-able mac again.

        # symlink configs to $HOME
        .bashrc
        .profile
        .gitconfig
        .hyper.js
        .zprofile
        .zshrc
    else
    echo "this install script doesn't support this OS";
    exit;
    fi
