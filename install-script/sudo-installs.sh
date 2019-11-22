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

        #install brew deps
        apt install build-essential;

        ##- brew installs
        #install brew
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)";

        # add brew to path
        eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);

        #install brew version of gcc for easier building
        brew install gcc

        #install stuff via brew that cant be install via apt
         brew install exa;
         brew install jump;
         brew install micro;



        ##- symlink stuff to $HOME
        .bashrc
        .profile
        .gitconfig
        .zshrc
        .zprofile

    ##- Windows Subystem Layer Only
        if [[ $UNAMECHECK == *"Microsoft"* ]] then
        #set variables
        export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
        export WINHOME=${WINHOME//$'\015'};
        CONFIGS="${WINHOME}/home/Documents/configs";



        ##- symlink stuff to $WINHOME
        ${WINHOME}/AppData/Roaming/Hyper -> ${CONFIGS}/hyper-js/.hyper.js
        ${WINHOME}/AppData/Roaming/Nextcloud -> ${CONFIGS}/nextcloud/sync-exlude.lst
        ${WINHOME}/AppData/Roaming/ueli/config.json -> ${CONFIGS}/ueli/config.json
        ${WINHOME}/AppData/Roaming/Code/User/settings.json -> ${CONFIGS}/vscodesettings.json

 #/AppData/Roaming/Blender/user-pref.blend

    ##- Linux ONLY
    else
        #set variables
        CONFIGS="$HOME/configs";

        #install preferred Linux programs
        brew install visual-studio-code;

        ##- symlink config files
        .hyper.js
        $HOME/.config/Code/User/settings.json
        .config/micro
        .config/nextcloud/sync-exclude.lst

    fi #end of checking linux or WSL

    fi #end of linux-gnu

    ##- else if macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        #settings variables
        CONFIGS="$HOME/configs";


        ##- brew installs
        #install brew
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

         # add brew to path
        eval $(/usr/local/Homebrew/bin/brew shellenv);

        #install brew version of gcc for easier building
        brew install gcc

        #install stuff via brew that cant be install via apt
         brew install exa;
         brew install jump;
         brew install micro;

        # symlink configs to $HOME
        $HOME/.bashrc
        ${CONFIGS}/bash/bashrc.sh

        $HOME/.profile
        ${CONFIGS}/bash/profile.sh

        $HOME/.gitconfig
        ${CONFIGS}/git/gitconfig.gitconfig

        $HOME/.hyper.js
        ${CONFIGS}/hyper/hyper.js

        $HOME/.zprofile
        ${CONFIGS}/zsh/zprofile.zsh

        $HOME/.zshrc
        ${CONFIGS}/zsh/zshrc.zsh

        $HOME/Library/Application Support/Code/User/settings.json
        ${CONFIGS}/vscode/settings.json

    else
    echo "this install script doesn't support this OS";
    exit;
    fi
