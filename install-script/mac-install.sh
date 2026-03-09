#!/bin/bash
##- Mac installation script
# Note: CONFIGS is set by sourcing init.sh
source ~/configs/init.sh

# Init all submodules recursively
echo "Initializing git submodules..."
git submodule init
git submodule update --recursive

# Install Xcode Command Line Tools (required by git, brew, and compiler toolchain)
if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Waiting for Xcode CLI tools installation to complete..."
    until xcode-select -p &>/dev/null; do sleep 5; done
    echo "✓ Xcode Command Line Tools installed"
else
    echo "✓ Xcode Command Line Tools already installed"
fi

# Install Homebrew if not already installed
echo "Setting up Homebrew..."
if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Set up Homebrew environment (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"
grep -qF 'brew shellenv' "${HOME}/.zprofile" || \
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"

# Install apps using brew
source ${CONFIGS}/install-script/functions/brew-installs.sh

# Install fonts
source ${CONFIGS}/install-script/functions/install-fonts.sh

# Symlink stuff
source ${CONFIGS}/install-script/functions/symlinks.sh

# Configure git
source ${CONFIGS}/install-script/functions/git-config.sh

echo "✓ Mac installation complete!"