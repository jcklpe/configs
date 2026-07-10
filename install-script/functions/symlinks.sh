#!/bin/bash
##- Symlink stuff to $HOME (idempotent - checks before creating)

source "${CONFIGS}/install-script/functions/detect-os.sh"

# Helper function to create symlink only if needed
create_symlink_if_needed() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        echo_skip "✓ $target already linked correctly"
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
create_symlink_if_needed "${CONFIGS}/nano/config.nanorc" "${HOME}/.nanorc"

##- Global agent instruction files
# One source file, two links. Deliberately not named AGENTS.md in-repo: Codex loads
# every file literally called AGENTS.md from the repo root down to the cwd, so
# agents/AGENTS.md would get pulled in a second time by anyone working in that folder.
#
# Copilot reads skills from ~/.claude/skills and reports reading CLAUDE.md too, so
# these two links may cover all three agents. Unconfirmed: it was asked from inside
# configs/, which has its own CLAUDE.md -> AGENTS.md symlink, so "CLAUDE.md" in its
# answer is ambiguous. To settle it, ask Copilot from a repo with neither file
# whether its instructions contain the heading "Global Agent Instructions".
#
# HAZARD, accepted: Claude Code's /memory command and `#` shortcut append user memories
# to ~/.claude/CLAUDE.md, which this symlink points into a tracked file in a PUBLIC repo.
# Agent-written memories are unaffected (they live in ~/.claude/projects/<slug>/memory/).
# The user does not use those features. To close it, replace the CLAUDE.md symlink with a
# real file containing one line: @${CONFIGS}/agents/AGENTS.global.md
ensure_dir "${HOME}/.codex"
ensure_dir "${HOME}/.claude"
create_symlink_if_needed "${CONFIGS}/agents/AGENTS.global.md" "${HOME}/.codex/AGENTS.md"
create_symlink_if_needed "${CONFIGS}/agents/AGENTS.global.md" "${HOME}/.claude/CLAUDE.md"

##- Codex global skill symlinks
# Add one explicit call for each skill folder that should be globally available.
# Keep skill links individual so repo-local helper files under skills/ do not become broken skill packages.
ensure_dir "${HOME}/.codex/skills"
create_symlink_if_needed "${CONFIGS}/skills/setup-project-docs" "${HOME}/.codex/skills/setup-project-docs"
create_symlink_if_needed "${CONFIGS}/skills/setup-local-skills" "${HOME}/.codex/skills/setup-local-skills"
create_symlink_if_needed "${CONFIGS}/skills/run-project-spike" "${HOME}/.codex/skills/run-project-spike"
create_symlink_if_needed "${CONFIGS}/skills/triage-project-misc" "${HOME}/.codex/skills/triage-project-misc"
create_symlink_if_needed "${CONFIGS}/skills/track-changes" "${HOME}/.codex/skills/track-changes"
create_symlink_if_needed "${CONFIGS}/skills/track-deferred-decisions" "${HOME}/.codex/skills/track-deferred-decisions"
create_symlink_if_needed "${CONFIGS}/skills/commit-work" "${HOME}/.codex/skills/commit-work"

##- Claude global skill symlinks
# Mirror the same global seed skills for Claude Code while keeping configs/ as the source of truth.
ensure_dir "${HOME}/.claude/skills"
create_symlink_if_needed "${CONFIGS}/skills/setup-project-docs" "${HOME}/.claude/skills/setup-project-docs"
create_symlink_if_needed "${CONFIGS}/skills/setup-local-skills" "${HOME}/.claude/skills/setup-local-skills"
create_symlink_if_needed "${CONFIGS}/skills/run-project-spike" "${HOME}/.claude/skills/run-project-spike"
create_symlink_if_needed "${CONFIGS}/skills/triage-project-misc" "${HOME}/.claude/skills/triage-project-misc"
create_symlink_if_needed "${CONFIGS}/skills/track-changes" "${HOME}/.claude/skills/track-changes"
create_symlink_if_needed "${CONFIGS}/skills/track-deferred-decisions" "${HOME}/.claude/skills/track-deferred-decisions"
create_symlink_if_needed "${CONFIGS}/skills/commit-work" "${HOME}/.claude/skills/commit-work"

# WezTerm uses XDG on all platforms
ensure_dir "${HOME}/.config/wezterm"
create_symlink_if_needed "${CONFIGS}/wezterm/wezterm.lua" "${HOME}/.config/wezterm/wezterm.lua"

# Micro editor
ensure_dir "${HOME}/.config/micro"
create_symlink_if_needed "${CONFIGS}/micro/settings.json" "${HOME}/.config/micro/settings.json"
create_symlink_if_needed "${CONFIGS}/micro/colorschemes" "${HOME}/.config/micro/colorschemes"

# Ranger
ensure_dir "${HOME}/.config/ranger/plugins"
create_symlink_if_needed "${CONFIGS}/ranger/rc.conf" "${HOME}/.config/ranger/rc.conf"
# ranger_devicons plugin (required for default_linemode devicons in rc.conf)
if [ ! -d "${HOME}/.config/ranger/plugins/ranger_devicons" ]; then
    git clone https://github.com/alexanderjeurissen/ranger_devicons "${HOME}/.config/ranger/plugins/ranger_devicons"
    echo "✓ Installed ranger_devicons plugin"
else
    echo "✓ ranger_devicons already installed, skipping"
fi

##- NixOS-specific symlinks
if [ "${OS_TYPE}" = "nixos" ]; then
    sudo ln -sf "${CONFIGS}/nixos/configuration.nix" /etc/nixos/configuration.nix
    echo "✓ Symlinked configuration.nix → /etc/nixos/configuration.nix"
fi

##- Mac-specific symlinks
if [ "${OS_TYPE}" = "mac" ]; then
    ensure_dir "${HOME}/Library/Application Support/tabby"
    create_symlink_if_needed "${CONFIGS}/tabby/config.mac.yaml" "${HOME}/Library/Application Support/tabby/config.yaml"
fi

##- Linux-specific symlinks (includes Fedora, NixOS and WSL)
if [ "${OS_TYPE}" = "fedora" ] || [ "${OS_TYPE}" = "linux" ] || [ "${OS_TYPE}" = "nixos" ] || [ "${OS_TYPE}" = "wsl" ]; then
    ensure_dir "${HOME}/.config/tabby"
    create_symlink_if_needed "${CONFIGS}/tabby/config.linux.yaml" "${HOME}/.config/tabby/config.yaml"
fi
