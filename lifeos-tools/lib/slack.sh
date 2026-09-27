#!/usr/bin/env bash
##- Slack as the user's own account: thin wrapper over lib/slack.py.

_slack_dispatch() {
    SECRETS_DIR="$SECRETS_DIR" "$LIFEOS_PY" "${LIB_DIR}/slack.py" "$@"
}
