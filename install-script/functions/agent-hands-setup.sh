#!/usr/bin/env bash
##- Agent Hands owns selected capabilities and their independent runtimes.
if [ ! -f "${CONFIGS}/agent-hands/setup-agent-hands/SKILL.md" ]; then
    printf '%s\n' 'Agent Hands is not checked out; initialize the agent-hands submodule before using service commands.'
    return 0 2>/dev/null || exit 0
fi
printf '%s\n' 'Agent Hands is available. Follow agent-hands/setup-agent-hands/SKILL.md to choose services, runtimes and optional global client links; each service setup owns its link installer.'
# Dotfile setup does not install/remove Agent Hands skill links, synchronize runtimes or change provider authentication/configuration. Existing client links are preserved.
