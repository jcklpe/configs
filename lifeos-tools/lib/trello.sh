#!/usr/bin/env bash
##- Compatibility commands using provider-owned configuration and explicit export destinations.
TRELLO_USE_DIR="$(cd "${LIB_DIR}/../../agent-hands/skills/use-trello" && pwd)" || return 1
TRELLO_AUTH_DIR="$(cd "${TRELLO_USE_DIR}/../authorize-trello" && pwd)" || return 1
. "${TRELLO_AUTH_DIR}/scripts/client.sh"
. "${TRELLO_USE_DIR}/scripts/operations.sh"
. "${TRELLO_USE_DIR}/scripts/export.sh"

_trello_snooze() { _trello_schedule_card "$@"; }

_trello_sync() { _trello_export "$@"; }
