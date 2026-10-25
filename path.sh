#!/usr/bin/env bash
##- PATH modifications and tool environment initialization
##- Source this after init.sh in your shell RC files

# Remove only the retired entry from an inherited shell PATH. Preserve empty elements.
_configs_path_rest="$PATH"
_configs_path_clean=""
_configs_path_separator=""
while :; do
    case "$_configs_path_rest" in
        *:*) _configs_path_item="${_configs_path_rest%%:*}"; _configs_path_rest="${_configs_path_rest#*:}"; _configs_path_more=1 ;;
        *) _configs_path_item="$_configs_path_rest"; _configs_path_more=0 ;;
    esac
    if [ "$_configs_path_item" != "${CONFIGS}/lifeos-tools" ]; then
        _configs_path_clean="${_configs_path_clean}${_configs_path_separator}${_configs_path_item}"
        _configs_path_separator=:
    fi
    [ "$_configs_path_more" = 1 ] || break
done
export PATH="$_configs_path_clean"
unset _configs_path_rest _configs_path_clean _configs_path_separator _configs_path_item _configs_path_more
if [ -d "${CONFIGS}/agent-hands/bin" ]; then
    case ":$PATH:" in
        *":${CONFIGS}/agent-hands/bin:"*) ;;
        *) export PATH="${CONFIGS}/agent-hands/bin:$PATH" ;;
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
