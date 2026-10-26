#!/bin/bash
##- Symlink stuff to $HOME (idempotent - checks before creating)

source "${CONFIGS}/install-script/functions/detect-os.sh"

# Helper function to create symlink only if needed
create_symlink_if_needed() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            echo_skip "✓ $target already linked correctly"
            return 0
        fi
        # Do not follow an existing directory link and create a nested link inside its destination.
        ln -sfn "$source" "$target" || return 1
    elif [ -e "$target" ]; then
        printf '%s\n' "Refusing to replace an existing file or directory: $target" >&2
        return 1
    else
        ln -s "$source" "$target" || return 1
    fi
    echo "✓ Created symlink: $target → $source"
}

# Remove only installer-owned retired links; preserve user-managed files and other link targets.
remove_symlink_if_owned() {
    local source="$1"
    local target="$2"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        rm -- "$target" || return 1
        echo "✓ Removed retired symlink: $target"
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
create_symlink_if_needed "${CONFIGS}/r/lintr" "${HOME}/.lintr"

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
create_symlink_if_needed "${CONFIGS}/project-workflows/setup-project-workflows" "${HOME}/.codex/skills/setup-project-workflows"
remove_symlink_if_owned "${CONFIGS}/skills/setup-project-docs" "${HOME}/.codex/skills/setup-project-docs"
remove_symlink_if_owned "${CONFIGS}/skills/setup-local-skills" "${HOME}/.codex/skills/setup-local-skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/run-project-spike" "${HOME}/.codex/skills/run-project-spike"
create_symlink_if_needed "${CONFIGS}/project-workflows/triage-project-misc" "${HOME}/.codex/skills/triage-project-misc"
create_symlink_if_needed "${CONFIGS}/project-workflows/log-future-idea" "${HOME}/.codex/skills/log-future-idea"
create_symlink_if_needed "${CONFIGS}/project-workflows/pin-issue" "${HOME}/.codex/skills/pin-issue"
create_symlink_if_needed "${CONFIGS}/general-skills/log-kaizen" "${HOME}/.codex/skills/log-kaizen"
create_symlink_if_needed "${CONFIGS}/general-skills/improve-agent-workflows" "${HOME}/.codex/skills/improve-agent-workflows"
remove_symlink_if_owned "${CONFIGS}/skills/kaizen" "${HOME}/.codex/skills/kaizen"
remove_symlink_if_owned "${CONFIGS}/skills/log-skills-feedback" "${HOME}/.codex/skills/log-skills-feedback"
create_symlink_if_needed "${CONFIGS}/general-skills/write-skills" "${HOME}/.codex/skills/write-skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/draft-approval-slate" "${HOME}/.codex/skills/draft-approval-slate"
create_symlink_if_needed "${CONFIGS}/general-skills/track-changes" "${HOME}/.codex/skills/track-changes"
create_symlink_if_needed "${CONFIGS}/project-workflows/update-project-workflows" "${HOME}/.codex/skills/update-project-workflows"
remove_symlink_if_owned "${CONFIGS}/skills/update-local-skills" "${HOME}/.codex/skills/update-local-skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/commit-work" "${HOME}/.codex/skills/commit-work"
create_symlink_if_needed "${CONFIGS}/general-skills/operate-lifeos" "${HOME}/.codex/skills/operate-lifeos"
remove_symlink_if_owned "${CONFIGS}/skills/lifeos-handoff" "${HOME}/.codex/skills/lifeos-handoff"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-cli" "${HOME}/.codex/skills/lifeos-cli"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-trello" "${HOME}/.codex/skills/lifeos-trello"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-calendar" "${HOME}/.codex/skills/lifeos-calendar"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-gmail" "${HOME}/.codex/skills/lifeos-gmail"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-drive" "${HOME}/.codex/skills/lifeos-drive"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-docs" "${HOME}/.codex/skills/lifeos-docs"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-github" "${HOME}/.codex/skills/lifeos-github"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-m365" "${HOME}/.codex/skills/lifeos-m365"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-odoo" "${HOME}/.codex/skills/lifeos-odoo"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-slack" "${HOME}/.codex/skills/lifeos-slack"
remove_symlink_if_owned "${CONFIGS}/lifeos-tools/skills/lifeos-open-austin" "${HOME}/.codex/skills/lifeos-open-austin"
# Native owners for the already-selected service families and local renderers.
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-github" "${HOME}/.codex/skills/authorize-github"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-google" "${HOME}/.codex/skills/authorize-google"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-microsoft" "${HOME}/.codex/skills/authorize-microsoft"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-odoo" "${HOME}/.codex/skills/authorize-odoo"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-slack" "${HOME}/.codex/skills/authorize-slack"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-trello" "${HOME}/.codex/skills/authorize-trello"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/render-calendar-agenda" "${HOME}/.codex/skills/render-calendar-agenda"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/render-markdown-pdf" "${HOME}/.codex/skills/render-markdown-pdf"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-agent-hands" "${HOME}/.codex/skills/setup-agent-hands"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-github" "${HOME}/.codex/skills/setup-github"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-google-services" "${HOME}/.codex/skills/setup-google-services"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-microsoft-services" "${HOME}/.codex/skills/setup-microsoft-services"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-odoo" "${HOME}/.codex/skills/setup-odoo"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-slack" "${HOME}/.codex/skills/setup-slack"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-trello" "${HOME}/.codex/skills/setup-trello"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-excel-workbooks" "${HOME}/.codex/skills/use-excel-workbooks"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-discussions" "${HOME}/.codex/skills/use-github-discussions"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-issues" "${HOME}/.codex/skills/use-github-issues"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-projects" "${HOME}/.codex/skills/use-github-projects"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-pull-requests" "${HOME}/.codex/skills/use-github-pull-requests"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-gmail" "${HOME}/.codex/skills/use-gmail"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-calendar" "${HOME}/.codex/skills/use-google-calendar"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-contacts" "${HOME}/.codex/skills/use-google-contacts"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-docs" "${HOME}/.codex/skills/use-google-docs"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-drive" "${HOME}/.codex/skills/use-google-drive"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-sheets" "${HOME}/.codex/skills/use-google-sheets"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-microsoft-files" "${HOME}/.codex/skills/use-microsoft-files"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-odoo-projects" "${HOME}/.codex/skills/use-odoo-projects"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-outlook-calendar" "${HOME}/.codex/skills/use-outlook-calendar"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-outlook-contacts" "${HOME}/.codex/skills/use-outlook-contacts"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-outlook-mail" "${HOME}/.codex/skills/use-outlook-mail"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-planner" "${HOME}/.codex/skills/use-planner"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-slack-lists" "${HOME}/.codex/skills/use-slack-lists"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-slack-messages" "${HOME}/.codex/skills/use-slack-messages"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-trello" "${HOME}/.codex/skills/use-trello"


##- Claude global skill symlinks
# Mirror the same global seed skills for Claude Code while keeping configs/ as the source of truth.
ensure_dir "${HOME}/.claude/skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/setup-project-workflows" "${HOME}/.claude/skills/setup-project-workflows"
remove_symlink_if_owned "${CONFIGS}/skills/setup-project-docs" "${HOME}/.claude/skills/setup-project-docs"
remove_symlink_if_owned "${CONFIGS}/skills/setup-local-skills" "${HOME}/.claude/skills/setup-local-skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/run-project-spike" "${HOME}/.claude/skills/run-project-spike"
create_symlink_if_needed "${CONFIGS}/project-workflows/triage-project-misc" "${HOME}/.claude/skills/triage-project-misc"
create_symlink_if_needed "${CONFIGS}/project-workflows/log-future-idea" "${HOME}/.claude/skills/log-future-idea"
create_symlink_if_needed "${CONFIGS}/project-workflows/pin-issue" "${HOME}/.claude/skills/pin-issue"
create_symlink_if_needed "${CONFIGS}/general-skills/log-kaizen" "${HOME}/.claude/skills/log-kaizen"
create_symlink_if_needed "${CONFIGS}/general-skills/improve-agent-workflows" "${HOME}/.claude/skills/improve-agent-workflows"
remove_symlink_if_owned "${CONFIGS}/skills/kaizen" "${HOME}/.claude/skills/kaizen"
remove_symlink_if_owned "${CONFIGS}/skills/log-skills-feedback" "${HOME}/.claude/skills/log-skills-feedback"
create_symlink_if_needed "${CONFIGS}/general-skills/write-skills" "${HOME}/.claude/skills/write-skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/draft-approval-slate" "${HOME}/.claude/skills/draft-approval-slate"
create_symlink_if_needed "${CONFIGS}/general-skills/track-changes" "${HOME}/.claude/skills/track-changes"
create_symlink_if_needed "${CONFIGS}/project-workflows/update-project-workflows" "${HOME}/.claude/skills/update-project-workflows"
remove_symlink_if_owned "${CONFIGS}/skills/update-local-skills" "${HOME}/.claude/skills/update-local-skills"
create_symlink_if_needed "${CONFIGS}/project-workflows/commit-work" "${HOME}/.claude/skills/commit-work"
create_symlink_if_needed "${CONFIGS}/general-skills/operate-lifeos" "${HOME}/.claude/skills/operate-lifeos"
remove_symlink_if_owned "${CONFIGS}/skills/lifeos-handoff" "${HOME}/.claude/skills/lifeos-handoff"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-cli" "${HOME}/.claude/skills/lifeos-cli"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-trello" "${HOME}/.claude/skills/lifeos-trello"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-calendar" "${HOME}/.claude/skills/lifeos-calendar"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-gmail" "${HOME}/.claude/skills/lifeos-gmail"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-drive" "${HOME}/.claude/skills/lifeos-drive"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-docs" "${HOME}/.claude/skills/lifeos-docs"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-github" "${HOME}/.claude/skills/lifeos-github"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-m365" "${HOME}/.claude/skills/lifeos-m365"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-odoo" "${HOME}/.claude/skills/lifeos-odoo"
create_symlink_if_needed "${CONFIGS}/agent-hands/compat/lifeos/skills/lifeos-slack" "${HOME}/.claude/skills/lifeos-slack"
remove_symlink_if_owned "${CONFIGS}/lifeos-tools/skills/lifeos-open-austin" "${HOME}/.claude/skills/lifeos-open-austin"
# Native owners for the already-selected service families and local renderers.
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-github" "${HOME}/.claude/skills/authorize-github"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-google" "${HOME}/.claude/skills/authorize-google"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-microsoft" "${HOME}/.claude/skills/authorize-microsoft"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-odoo" "${HOME}/.claude/skills/authorize-odoo"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-slack" "${HOME}/.claude/skills/authorize-slack"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/authorize-trello" "${HOME}/.claude/skills/authorize-trello"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/render-calendar-agenda" "${HOME}/.claude/skills/render-calendar-agenda"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/render-markdown-pdf" "${HOME}/.claude/skills/render-markdown-pdf"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-agent-hands" "${HOME}/.claude/skills/setup-agent-hands"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-github" "${HOME}/.claude/skills/setup-github"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-google-services" "${HOME}/.claude/skills/setup-google-services"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-microsoft-services" "${HOME}/.claude/skills/setup-microsoft-services"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-odoo" "${HOME}/.claude/skills/setup-odoo"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-slack" "${HOME}/.claude/skills/setup-slack"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/setup-trello" "${HOME}/.claude/skills/setup-trello"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-excel-workbooks" "${HOME}/.claude/skills/use-excel-workbooks"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-discussions" "${HOME}/.claude/skills/use-github-discussions"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-issues" "${HOME}/.claude/skills/use-github-issues"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-projects" "${HOME}/.claude/skills/use-github-projects"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-github-pull-requests" "${HOME}/.claude/skills/use-github-pull-requests"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-gmail" "${HOME}/.claude/skills/use-gmail"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-calendar" "${HOME}/.claude/skills/use-google-calendar"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-contacts" "${HOME}/.claude/skills/use-google-contacts"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-docs" "${HOME}/.claude/skills/use-google-docs"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-drive" "${HOME}/.claude/skills/use-google-drive"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-google-sheets" "${HOME}/.claude/skills/use-google-sheets"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-microsoft-files" "${HOME}/.claude/skills/use-microsoft-files"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-odoo-projects" "${HOME}/.claude/skills/use-odoo-projects"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-outlook-calendar" "${HOME}/.claude/skills/use-outlook-calendar"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-outlook-contacts" "${HOME}/.claude/skills/use-outlook-contacts"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-outlook-mail" "${HOME}/.claude/skills/use-outlook-mail"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-planner" "${HOME}/.claude/skills/use-planner"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-slack-lists" "${HOME}/.claude/skills/use-slack-lists"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-slack-messages" "${HOME}/.claude/skills/use-slack-messages"
create_symlink_if_needed "${CONFIGS}/agent-hands/skills/use-trello" "${HOME}/.claude/skills/use-trello"


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
