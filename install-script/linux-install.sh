#!/bin/bash
##- Linux installation script
# Note: CONFIGS is set by sourcing init.sh
source ~/configs/init.sh

# Init all submodules recursively
echo "Initializing git submodules..."
git submodule init
git submodule update --recursive

# Install Homebrew
echo "Setting up Homebrew..."
source ${CONFIGS}/install-script/functions/linux-install-brew.sh

# Install apps using brew
source ${CONFIGS}/install-script/functions/brew-installs.sh

# Symlink stuff
source ${CONFIGS}/install-script/functions/symlinks.sh

# Configure git
source ${CONFIGS}/install-script/functions/git-config.sh

echo "✓ Linux installation complete!"