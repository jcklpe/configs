#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;

# install brew
source ./linux-install-brew.sh;

# install apps using brew
source ./brew-installs.sh;

# symlink stuff
source ./linux-symlinks.sh;