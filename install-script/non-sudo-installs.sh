#!/bin/bash
##- Install list for manual installation of binaries without sudo
#init all submodules recursively
cd ..;
git submodule update --recursive ;

#settings variables
CONFIGS="$HOME/configs";
MYBIN="$HOME/.bin";

#set up personal home bin folder to old manual installs
mkdir -p ${MYBIN};
alias go-bin="cd ${MYBIN}";

##- symlink config files
#symlink configs to $HOME

##- Check operating systems
    ##- LINUX AND WSL
    if [[ "$OSTYPE" == "linux-gnu" ]]; then

        ##- brew installs
        #install brew

        # brew installs

        ##- manual installations
        #install stuff by wget etc that cant be installed via brew
        go-bin;

        # zsh
        wget -O zsh.tar.xz https://sourceforge.net/projects/zsh/files/latest/download
        mkdir zsh &&
        unxz zsh.tar.xz &&
        tar -xvf zsh.tar -C zsh --strip-components 1
        cd zsh;
        go-bin;

        # exa
        mkdir -p exa;
        cd exa;
        wget https://github.com/ogham/exa/releases/download/v0.9.0/exa-linux-x86_64-0.9.0.zip;
        unzip exa-linux-x86_64-0.9.0.zip;
        mv exa-linux-x86_64-0.9.0 exa;
        go-bin;

        # Ranger
        wget https://ranger.github.io/ranger-stable.tar.gz;
        tar xvf ranger-stable.tar.gz
        go-bin;

        # midnight commander

        go-bin;

    fi #end of linux-gnu

    ##- else if macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then

        ##- brew installs
        #install brew

        # brew installs

        ##- manual installations
        #install stuff by wget etc that cant be installed via brew
        go-bin;

    else
    echo "this install script doesn't support this OS";
    exit;
    fi

    ##- ADD symlink or alias for bin files
        # aliases for the bin files. This might need to be a separate file that then gets sourced based upon some kind of env variable which gets set here by the install script.
