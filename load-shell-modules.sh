#!/usr/bin/env bash
##- Load all shell modules
##- Used by both bash and zsh
##- Source this file after init.sh has set CONFIGS

# Movement aliases and functions (zsh-specific due to eza overrides)
source ${CONFIGS}/movement/movement.sh

# Tool-specific configs (shell-agnostic)
source ${CONFIGS}/git/git.sh

# Smart dev-script / env-command dispatcher (`run` / `runjs`) + completions
source ${CONFIGS}/plugins/run/run.sh
if [ -n "$ZSH_VERSION" ]; then
    source ${CONFIGS}/plugins/run/completion.zsh
elif [ -n "$BASH_VERSION" ]; then
    source ${CONFIGS}/plugins/run/completion.bash
fi
