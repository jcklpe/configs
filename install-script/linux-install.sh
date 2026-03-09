#!/bin/bash
##- Linux installation script
# Note: CONFIGS is set by sourcing init.sh
source ~/configs/init.sh

# Init all submodules recursively
echo "Initializing git submodules..."
git submodule init
git submodule update --recursive

# Install Homebrew and CLI tools (skip on NixOS - packages managed by nix)
if [ "${OS_TYPE}" != "nixos" ]; then
    echo "Setting up Homebrew..."
    source ${CONFIGS}/install-script/functions/linux-install-brew.sh
    source ${CONFIGS}/install-script/functions/brew-installs.sh
else
    echo "NixOS detected - skipping Homebrew setup"
fi

# Install GUI apps via dnf (Fedora only)
if [ "${OS_TYPE}" = "fedora" ]; then
    echo "Installing GUI apps via dnf..."
    source ${CONFIGS}/install-script/functions/dnf-installs.sh
fi

# Symlink stuff
source ${CONFIGS}/install-script/functions/symlinks.sh

# Configure git
source ${CONFIGS}/install-script/functions/git-config.sh

echo "✓ Linux installation complete!"