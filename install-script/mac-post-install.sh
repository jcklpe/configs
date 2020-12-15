##- Symlink GUI apps configs to mac home

# This is for full desktop installs on mac machines
brew cask install hyper;
brew cask install visual-studio-code;

ln -sf  ${CONFIGS}/hyper-js/hyper.js ${HOME}/.hyper.js;
ln -sf  ${CONFIGS}/vscode/settings.json ${HOME}/Library/Application Support/Code/User/settings.json
