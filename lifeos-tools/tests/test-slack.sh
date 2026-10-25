#!/usr/bin/env bash
##- Run the extracted Slack request/guardrail smoke checks without a live account.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/../../agent-hands/tests/test_slack_operations.py"
