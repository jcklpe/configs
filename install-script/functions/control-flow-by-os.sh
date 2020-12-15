if [[ "$OSTYPE" == "linux-gnu" ]]; then
    # run linux stuff here

    elif [[ "$OSTYPE" == "darwin"* ]]; then
    # run mac stuff here
else
    echo "os not supported by this install script"
fi

#-- sudo linux installs
if [ -d "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv);

fi
#-- sudo mac installs
if [ -d "/usr/local/Homebrew/bin/brew" ]; then
    eval $(/usr/local/Homebrew/bin/brew shellenv);
fi
#-- non sudo mac/linux installs
if [ -d "${HOME}/.linuxbrew" ]; then
    eval $(${HOME}/.linuxbrew/bin/brew shellenv);
fi