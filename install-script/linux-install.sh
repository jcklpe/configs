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

# Install fonts
source ${CONFIGS}/install-script/functions/install-fonts.sh

# Set zsh as default shell (not needed on NixOS — set via configuration.nix)
if [ "${OS_TYPE}" != "nixos" ]; then
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "Setting zsh as default shell..."
        chsh -s $(which zsh)
    else
        echo "✓ zsh already set as default shell"
    fi
fi

# Symlink stuff (must run before nixos-rebuild so configuration.nix is in place)
source ${CONFIGS}/install-script/functions/symlinks.sh

# Run nixos-rebuild now that configuration.nix symlink is in place (NixOS only)
if [ "${OS_TYPE}" = "nixos" ]; then
    echo "Running nixos-rebuild switch..."
    sudo nixos-rebuild switch
fi

# Configure git
source ${CONFIGS}/install-script/functions/git-config.sh

# Set Tabby as the default GNOME terminal (used by Nautilus "Open Terminal Here")
# Uses xdg-settings with dynamic .desktop file lookup for compatibility across GNOME versions
if command -v xdg-settings &>/dev/null; then
    TABBY_DESKTOP=$(grep -rl "tabby\|Tabby" /usr/share/applications/ 2>/dev/null | head -1 | xargs basename 2>/dev/null)
    if [ -n "$TABBY_DESKTOP" ]; then
        xdg-settings set default-terminal-emulator "$TABBY_DESKTOP"
        echo "✓ Tabby set as default GNOME terminal ($TABBY_DESKTOP)"
    else
        echo_warning "⚠ Could not find Tabby .desktop file — skipping default terminal setup"
    fi
else
    echo_warning "⚠ xdg-settings not found — skipping default terminal setup"
fi

echo "✓ Linux installation complete!"