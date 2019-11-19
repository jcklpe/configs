##- apt related
# install with sudo apt all the time
    alias apt="sudo apt"
    alias apt-get="apt"
    alias apt-y="apt --yes"

# update on one command
 alias apt-refresh='apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean -y'