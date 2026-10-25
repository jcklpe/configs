#!/usr/bin/env bash
##- Compatibility route preserving existing credentials, snapshot destinations, and consumer defaults.
TRELLO_USE_DIR="$(cd "${LIB_DIR}/../../agent-hands/skills/use-trello" && pwd)" || return 1
TRELLO_AUTH_DIR="$(cd "${TRELLO_USE_DIR}/../authorize-trello" && pwd)" || return 1
. "${TRELLO_AUTH_DIR}/scripts/client.sh"
. "${TRELLO_USE_DIR}/scripts/operations.sh"
. "${TRELLO_USE_DIR}/scripts/export.sh"

_trello_snooze() { TRELLO_SNOOZE_DEFAULT_LIST="${TRELLO_SNOOZE_DEFAULT_LIST:-Snoozed}" _trello_schedule_card "$@"; }
_trello_snooze_lists() { printf '%s\n' "${TRELLO_SNOOZE_LISTS:-Snoozed}"; }

_trello_sync() {
    local output=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) output="${QA_DIR}/trello-qa.md"; shift ;;
            --output) [ -n "${2:-}" ] || { _err '--output requires FILE'; return 1; }; output="$2"; shift 2 ;;
            *) _err "Unknown trello sync option: $1"; return 1 ;;
        esac
    done
    if [ -z "$output" ]; then
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        output="$(_sources_dir)/trello.md"
    fi
    _trello_export --output "$output"
}
