#!/usr/bin/env bash
##- Optional Agent Hands checkout; service setup owns runtimes and client links.
_configs_agent_hands_setup() {
    local agent_hands_root agent_hands_answer agent_hands_declared agent_hands_entry
    printf '%s\n' \
        '_______                    _____     ______  __             _________       ' \
        '___    |______ ______________  /_    ___  / / /_____ _____________  /_______' \
        '__  /| |_  __ `/  _ \_  __ \  __/    __  /_/ /_  __ `/_  __ \  __  /__  ___/' \
        '_  ___ |  /_/ //  __/  / / / /_      _  __  / / /_/ /_  / / / /_/ / _(__  ) ' \
        '/_/  |_|\__, / \___//_/ /_/\__/      /_/ /_/  \__,_/ /_/ /_/\__,_/  /____/  ' \
        '       /____/'
    printf '\n'
    if [ -z "${CONFIGS:-}" ] || ! agent_hands_root="$(cd -- "$CONFIGS" 2>/dev/null && pwd -P)"; then
        printf '%s\n' 'Cannot locate the configs checkout. Run this notice with CONFIGS set to its actual repository directory.' >&2
        return 1
    fi
    if [ ! -f "$agent_hands_root/agent-hands/setup-agent-hands/SKILL.md" ]; then
        printf '%s\n' 'Agent Hands is not checked out. Initialization may download its recorded revision; it does not configure services or global skill links.'
        if [ -t 0 ] && [ -t 1 ]; then
            printf '%s' 'Initialize the Agent Hands submodule now? [y/N] '
            if ! IFS= read -r agent_hands_answer; then
                printf '\n'
                agent_hands_answer=''
            fi
        else
            printf '%s\n' 'No interactive terminal; leaving Agent Hands unchanged.'
            agent_hands_answer=''
        fi
        case "$agent_hands_answer" in
            y|Y|yes|Yes|YES) ;;
            *)
                printf '%s\n' 'Skipped initialization. To try later, run this notice from a terminal:'
                printf '  CONFIGS=%q bash %q\n' "$agent_hands_root" "$agent_hands_root/install-script/functions/agent-hands-setup.sh"
                return 0
                ;;
        esac
        # Verify this checkout and its declared path before a scoped update.
        if [ "$(git -C "$agent_hands_root" rev-parse --show-toplevel 2>/dev/null)" != "$agent_hands_root" ]; then
            printf '%s\n' 'Refusing initialization: CONFIGS is not the repository root. No checkout was changed.' >&2
            return 1
        fi
        agent_hands_declared="$(git -C "$agent_hands_root" config --file "$agent_hands_root/.gitmodules" --get submodule.agent-hands.path 2>/dev/null)" || agent_hands_declared=''
        agent_hands_entry="$(git -C "$agent_hands_root" ls-files --stage -- agent-hands 2>/dev/null)" || agent_hands_entry=''
        if [ "$agent_hands_declared" != 'agent-hands' ]; then
            printf '%s\n' 'Refusing initialization: .gitmodules does not declare agent-hands at the expected path. Inspect the checkout before retrying.' >&2
            return 1
        fi
        case "$agent_hands_entry" in
            "160000 "*"$(printf '\t')agent-hands") ;;
            *) printf '%s\n' 'Refusing initialization: agent-hands is not a tracked submodule. Inspect the checkout before retrying.' >&2; return 1 ;;
        esac
        if ! git -C "$agent_hands_root" -c submodule.recurse=false -c fetch.recurseSubmodules=false submodule update --init --checkout -- agent-hands; then
            printf '%s\n' 'Agent Hands initialization failed. Check the Git error above and repository access, then rerun this notice. No service setup was started.' >&2
            return 1
        fi
        if [ ! -f "$agent_hands_root/agent-hands/setup-agent-hands/SKILL.md" ]; then
            printf '%s\n' 'Git finished, but setup-agent-hands/SKILL.md is still missing. Inspect the recorded Agent Hands revision before retrying; no service setup was started.' >&2
            return 1
        fi
        printf '%s\n' 'Agent Hands checkout is ready.'
    fi
    printf '%s\n' 'Follow agent-hands/setup-agent-hands/SKILL.md to choose services, runtimes and optional global client links; each service setup owns its link installer.'
    printf '%s\n' 'For the copyable setup prompt, open agent-hands/README.md.'
}

# This file can be sourced by either main installer or run directly with CONFIGS set.
if _configs_agent_hands_setup; then
    unset -f _configs_agent_hands_setup
else
    unset -f _configs_agent_hands_setup
    return 1 2>/dev/null || exit 1
fi
