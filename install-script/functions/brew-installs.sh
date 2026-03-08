#!/bin/bash
##- Install stuff through brew (idempotent - skips already installed packages)

source "${CONFIGS}/install-script/functions/detect-os.sh"

# Brew is not used on NixOS - packages are managed by nix
if [ "${OS_TYPE}" = "nixos" ]; then
    echo "NixOS detected - skipping brew installs"
    return 0 2>/dev/null || exit 0
fi

# Helper function to install package only if not already installed
brew_install_if_needed() {
    if brew list "$1" &>/dev/null; then
        echo "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        brew install "$1"
    fi
}

# Helper function to install cask only if not already installed
brew_cask_install_if_needed() {
    if brew list --cask "$1" &>/dev/null; then
        echo "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        brew install --cask "$1"
    fi
}

##- Cross-platform packages
brew_install_if_needed gcc
brew_install_if_needed eza
brew_install_if_needed jump
brew_install_if_needed mc
brew_install_if_needed ranger
brew_install_if_needed fnm
brew_cask_install_if_needed wezterm
brew_cask_install_if_needed tabby

# Install zsh on Linux/WSL only (macOS has it pre-installed)
if [ "${OS_TYPE}" != "mac" ]; then
    brew_install_if_needed zsh
fi

##- Mac-only packages
if [ "${OS_TYPE}" = "mac" ]; then
    brew_cask_install_if_needed visual-studio-code
fi
