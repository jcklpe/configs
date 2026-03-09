#!/bin/bash
##- Symlink stuff to $HOME (idempotent - checks before creating)

source "${CONFIGS}/install-script/functions/detect-os.sh"

# Helper function to create symlink only if needed
create_symlink_if_needed() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        echo "✓ $target already linked correctly"
    else
        ln -sf "$source" "$target"
        echo "✓ Created symlink: $target → $source"
    fi
}

# Helper function to create directory if needed
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        echo "✓ Created directory: $1"
    fi
}

##- Cross-platform symlinks
create_symlink_if_needed "${CONFIGS}/bash/bashrc.sh" "${HOME}/.bashrc"
create_symlink_if_needed "${CONFIGS}/bash/bash.profile" "${HOME}/.profile"
create_symlink_if_needed "${CONFIGS}/git/git.gitignore_global" "${HOME}/.gitignore_global"
create_symlink_if_needed "${CONFIGS}/zsh/zshrc" "${HOME}/.zshrc"
create_symlink_if_needed "${CONFIGS}/zsh/zprofile" "${HOME}/.zprofile"

# WezTerm uses XDG on all platforms
ensure_dir "${HOME}/.config/wezterm"
create_symlink_if_needed "${CONFIGS}/wezterm/wezterm.lua" "${HOME}/.config/wezterm/wezterm.lua"

##- Mac-specific symlinks
if [ "${OS_TYPE}" = "mac" ]; then
    ensure_dir "${HOME}/Library/Application Support/tabby"
    create_symlink_if_needed "${CONFIGS}/tabby/config.yaml" "${HOME}/Library/Application Support/tabby/config.yaml"
fi

##- Linux-specific symlinks (includes Fedora, NixOS and WSL)
if [ "${OS_TYPE}" = "fedora" ] || [ "${OS_TYPE}" = "linux" ] || [ "${OS_TYPE}" = "nixos" ] || [ "${OS_TYPE}" = "wsl" ]; then
    ensure_dir "${HOME}/.config/tabby"
    create_symlink_if_needed "${CONFIGS}/tabby/config.yaml" "${HOME}/.config/tabby/config.yaml"
fi
