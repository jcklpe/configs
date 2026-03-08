#!/bin/bash
##- Symlink stuff to $HOME (idempotent - checks before creating)

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

# Create symlinks
create_symlink_if_needed "${CONFIGS}/bash/bashrc.sh" "${HOME}/.bashrc"
create_symlink_if_needed "${CONFIGS}/hyper/hyper.js" "${HOME}/.hyper.js"
create_symlink_if_needed "${CONFIGS}/bash/bash.profile" "${HOME}/.profile"
create_symlink_if_needed "${CONFIGS}/git/git.gitignore_global" "${HOME}/.gitignore_global"
create_symlink_if_needed "${CONFIGS}/zsh/zshrc" "${HOME}/.zshrc"
create_symlink_if_needed "${CONFIGS}/zsh/zprofile" "${HOME}/.zprofile"

# WezTerm config (uses XDG config directory)
ensure_dir "${HOME}/.config/wezterm"
create_symlink_if_needed "${CONFIGS}/wezterm/wezterm.lua" "${HOME}/.config/wezterm/wezterm.lua"

# Tabby config (macOS: ~/Library/Application Support/tabby)
ensure_dir "${HOME}/Library/Application Support/tabby"
create_symlink_if_needed "${CONFIGS}/tabby/config.yaml" "${HOME}/Library/Application Support/tabby/config.yaml"

# VSCode settings
ensure_dir "${HOME}/Library/Application Support/Code/User"
create_symlink_if_needed "${CONFIGS}/vscode/settings.json" "${HOME}/Library/Application Support/Code/User/settings.json"