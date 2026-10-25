#!/usr/bin/env bash
##- Compatibility commands use the selected Slack capability's runtime and provider configuration.
_slack_dispatch() {
    local domain=messages project
    case "${1:-}" in lists|sync) domain=lists ;; esac
    project="${LIB_DIR}/../../agent-hands/skills/use-slack-${domain}"
    if [ -n "${SLACK_PYTHON:-}" ]; then
        "$SLACK_PYTHON" "${LIB_DIR}/slack.py" "$@"
    elif command -v uv >/dev/null 2>&1; then
        uv run --project "$project" python "${LIB_DIR}/slack.py" "$@"
    else
        _err 'Install uv or set SLACK_PYTHON to a compatible Python 3.11+ executable'; return 1
    fi
}
