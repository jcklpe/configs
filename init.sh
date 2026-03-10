#!/usr/bin/env bash
##- Shared initialization for bash and zsh
##- This file should be sourced first in both .bashrc and .zshrc

# Auto-detect CONFIGS location
if [ -n "$BASH_SOURCE" ]; then
    # Bash
    CONFIGS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "$ZSH_VERSION" ]; then
    # Zsh
    CONFIGS="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    # Fallback to hardcoded path
    CONFIGS="$HOME/configs"
fi

export CONFIGS
export PLUGINS="${CONFIGS}/plugins"

# Detect OS and export OS_TYPE (mac | nixos | wsl | linux | unknown)
source "${CONFIGS}/install-script/functions/detect-os.sh"

# Linux-specific: torch activation if available
if [ "${OS_TYPE}" = "linux" ]; then
    if [ -d "${HOME}/torch" ]; then
        source ${HOME}/torch/install/bin/torch-activate
    fi
fi

# Set up Homebrew environment (all OSes)
# Try common Homebrew locations and eval shellenv if found
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
elif [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "${HOME}/.linuxbrew/bin/brew" ]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
elif command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
fi
