#!/bin/bash
##- Linux installation script
# Note: CONFIGS is set by sourcing init.sh
source ~/configs/init.sh

# Init all submodules recursively
echo "Initializing git submodules..."
git submodule init
git submodule update --recursive

# Install base tools + GUI apps via dnf first (Fedora only)
# This runs before brew so system gcc is available, avoiding brew trying to download it
if [ "${OS_TYPE}" = "fedora" ]; then
    echo "Installing packages via dnf..."
    source ${CONFIGS}/install-script/functions/dnf-installs.sh
fi

# Install Homebrew and CLI tools not covered by native package managers
# (skip on NixOS - packages managed by nix)
if [ "${OS_TYPE}" != "nixos" ]; then
    echo "Setting up Homebrew..."
    source ${CONFIGS}/install-script/functions/linux-install-brew.sh
    source ${CONFIGS}/install-script/functions/brew-installs.sh
else
    echo "NixOS detected - skipping Homebrew setup"
fi

# Set zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Setting zsh as default shell..."
    chsh -s $(which zsh)
else
    echo "✓ zsh already set as default shell"
fi

# Symlink stuff
source ${CONFIGS}/install-script/functions/symlinks.sh

# Configure git
source ${CONFIGS}/install-script/functions/git-config.sh

echo "✓ Linux installation complete!"