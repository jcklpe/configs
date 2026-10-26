#!/usr/bin/env bash
##- Agent Hands owns selected capabilities and their independent runtimes.
if [ ! -f "${CONFIGS}/agent-hands/setup-agent-hands/SKILL.md" ]; then
    printf '%s\n' 'Agent Hands is not checked out; initialize the agent-hands submodule before using service commands.'
    return 0 2>/dev/null || exit 0
fi
printf '%s\n' 'Agent Hands capability skills are available. Follow agent-hands/setup-agent-hands/SKILL.md for only the providers/capabilities you need.'
# No shared uv sync and no provider authentication or configuration changes during dotfile installation.
