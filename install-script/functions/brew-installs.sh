#!/bin/bash
##- Install stuff through brew (idempotent - skips already installed packages)

# Helper function to install package only if not already installed
brew_install_if_needed() {
    if brew list "$1" &>/dev/null; then
        echo "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        brew install "$1"
    fi
}

# Install brew version of gcc for easier building
brew_install_if_needed gcc

# Install zsh on Linux/WSL only (macOS has it pre-installed)
if [ "${OS_TYPE}" != "mac" ]; then
    brew_install_if_needed zsh
fi

# Install other packages
brew_install_if_needed eza
brew_install_if_needed jump
brew_install_if_needed mc
brew_install_if_needed ranger