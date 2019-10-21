##- Install list for manual installation of binaries without sudo

mkdir -p ~/.bin;
cd ~/.bin;

# Jump
mkdir -p jump;
cd jump;
wget https://github.com/gsamokovarov/jump/releases/download/v0.23.0/jump_0.23.0_amd64.deb;

dpkg -x jump_0.23.0_amd64.deb .

cd ..;

# exa
mkdir -p exa;
cd exa;
wget https://github.com/ogham/exa/releases/download/v0.9.0/exa-linux-x86_64-0.9.0.zip;

unzip exa-linux-x86_64-0.9.0.zip;

mv exa-linux-x86_64 exa;

cd .. ;

# Ranger
wget https://ranger.github.io/ranger-stable.tar.gz;
tar xvf ranger-stable.tar.gz
ADD symlink or alias
