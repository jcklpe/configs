# ~/.zprofile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.


##- import .zshrc

    # include .bashrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
    fi



##- 𝖃𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    UNAMECHECK=$(uname -a);
    if [[ $UNAMECHECK == *"Microsoft"* ]] then
##- Windows Subystem Layer
cd home;


else
##- Normal Linux
exa
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
##- macOS
exa

elif [[ "$OSTYPE" == "cygwin" ]]; then
    # POSIX compatibility layer and Linux environment emulation for Windows

elif [[ "$OSTYPE" == "msys" ]]; then
    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)

elif [[ "$OSTYPE" == "win32" ]]; then
    # lol

elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # Maybe a Nintendo Switch?

else
    # Unknown.
fi
