#!/usr/bin/env bash
##- PATH modifications and tool environment initialization
##- Source this after init.sh in your shell RC files

# fnm (Fast Node Manager)
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd)"
fi

# Add other PATH tools here (pyenv, rbenv, etc.)

# pipx
[ -d "$HOME/.local/bin" ] && export PATH="$PATH:$HOME/.local/bin"

# pixi
[ -d "$HOME/.pixi/bin" ] && export PATH="$HOME/.pixi/bin:$PATH"
