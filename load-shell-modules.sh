#!/usr/bin/env bash
##- Load all shell modules
##- Used by both bash and zsh
##- Source this file after init.sh has set CONFIGS

# Movement aliases and functions (zsh-specific due to eza overrides)
source ${CONFIGS}/movement/movement.zsh

# Package manager shortcuts (shell-agnostic)
source ${CONFIGS}/apt/apt.sh
source ${CONFIGS}/npm/npm.sh

# Tool-specific configs (shell-agnostic)
source ${CONFIGS}/list/list.sh
source ${CONFIGS}/nextcloud/nextcloud.sh
source ${CONFIGS}/git/git.sh

# Image utilities (zsh-specific due to parameter expansion)
source ${CONFIGS}/image-utilities/image-utilities.zsh
