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
        echo_skip "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        brew install "$1"
    fi
}

# Helper function to install cask only if not already installed
brew_cask_install_if_needed() {
    if brew list --cask "$1" &>/dev/null; then
        echo_skip "✓ $1 already installed, skipping"
    else
        echo "Installing $1..."
        brew install --cask "$1"
    fi
}

##- CLI tools not in Fedora default repos (brew everywhere)
brew_install_if_needed eza
brew_install_if_needed jump
brew_install_if_needed fnm

##- CLI tools available in Fedora default repos (use dnf on Fedora, brew elsewhere)
if [ "${OS_TYPE}" != "fedora" ]; then
    brew_install_if_needed gcc
    brew_install_if_needed mc
    brew_install_if_needed ranger
    brew_install_if_needed micro
fi

# zsh: not needed on mac (pre-installed), not needed on Fedora (dnf handles it)
if [ "${OS_TYPE}" != "mac" ] && [ "${OS_TYPE}" != "fedora" ]; then
    brew_install_if_needed zsh
fi

##- Mac-only packages (casks are macOS-only)
if [ "${OS_TYPE}" = "mac" ]; then
    brew_cask_install_if_needed wezterm
    brew_cask_install_if_needed tabby
    brew_cask_install_if_needed visual-studio-code
    brew_cask_install_if_needed google-chrome
    brew_cask_install_if_needed vlc
    brew_cask_install_if_needed typora
fi
