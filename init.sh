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

# Detect OS for conditional loading
case "$(uname -s)" in
    Darwin*)
        export OS_TYPE="mac"
        ;;

    Linux*)
        # Check if WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            export OS_TYPE="wsl"

            # WSL-specific setup
            export WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%") 2>/dev/null)
            export WINHOME=${WINHOME//$'\015'}

            # WSL-specific aliases
            alias cmd='/mnt/c/Windows/System32/cmd.exe'
            alias vscode="/mnt/c/'Program Files'/'Microsoft VS Code'/Code.exe"

            # Change to home directory if we're in a weird location
            if [ -d "./home" ]; then
                cd home
            fi
        else
            export OS_TYPE="linux"

            # Linux-specific: torch activation if available
            if [ -d "${HOME}/torch" ]; then
                source ${HOME}/torch/install/bin/torch-activate
            fi
        fi
        ;;

    *)
        export OS_TYPE="unknown"
        ;;
esac

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
