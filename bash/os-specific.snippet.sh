##- 𝖃𝕆𝕊 𝔪𝔞𝔭𝔭𝔦𝔫𝔤𝔰
if [[ "$OSTYPE" == "linux-gnu" ]]; then
##- Both Linux and WSL
UNAMECHECK=$(uname -a);

##- Windows Subystem Layer
if [[ $UNAMECHECK == *"Microsoft"* ]] then

##- Linux
else

fi
##- macOS
elif [[ "$OSTYPE" == "darwin"* ]]; then

##- cygwin
elif [[ "$OSTYPE" == "cygwin" ]]; then

##- msys: Mingw32 and git bash
elif [[ "$OSTYPE" == "msys" ]]; then

##- bsd
elif [[ "$OSTYPE" == "freebsd"* ]]; then

else
    echo "Operating system is unknown";
fi
