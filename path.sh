#!/usr/bin/env bash
##- PATH modifications and tool environment initialization
##- Source this after init.sh in your shell RC files

if [ -d "${CONFIGS}/lifeos-tools" ]; then
    case ":$PATH:" in
        *":${CONFIGS}/lifeos-tools:"*) ;;
        *) export PATH="${CONFIGS}/lifeos-tools:$PATH" ;;
    esac
fi

# fnm (Fast Node Manager)
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd)"
fi

# Add other PATH tools here (pyenv, rbenv, etc.)

# pipx
[ -d "$HOME/.local/bin" ] && export PATH="$PATH:$HOME/.local/bin"

# pixi
[ -d "$HOME/.pixi/bin" ] && export PATH="$HOME/.pixi/bin:$PATH"
