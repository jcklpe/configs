##- Full Linux Installs

# This is for full desktop installs on linux machines
brew cask install hyper;
brew cask install visual-studio-code;

ln -sf  ${CONFIGS}/hyper-js/hyper.js ${HOME}/.hyper.js;
ln -sf  ${CONFIGS}/vscode/settings.json ${HOME}/.config/Code/User/settings.json