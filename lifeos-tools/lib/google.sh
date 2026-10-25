#!/usr/bin/env bash
##- Compatibility commands use provider-owned Google configuration and capability runtimes.
source "${LIB_DIR}/../../agent-hands/skills/authorize-google/scripts/client.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-google-calendar/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-gmail/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-google-drive/scripts/operations.sh"

_docs_run() { bash "${GOOGLE_AUTH_DIR}/../use-google-docs/scripts/docs" "$@"; }
_people_resolve() { bash "${GOOGLE_AUTH_DIR}/../use-google-contacts/scripts/contacts" resolve "$@"; }
_gmail_sync() {
    [ "${1:-}" != --all ] || { _err 'gmail sync --all is retired; select each account and --output FILE in the consuming workflow'; return 2; }
    _gmail_export "$@"
}

# Existing callers must continue to declare index exclusions explicitly.
_drive_sync() {
    local alias="" out="" explicit_exclusion=0 exclusion_type arguments=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) [ -n "${2:-}" ] || return 1; out="$2"; shift 2 ;;
            --exclude-folder) [ -n "${2:-}" ] || { _err '--exclude-folder requires NAME'; return 1; }; explicit_exclusion=1; arguments+=( "$1" "$2" ); shift 2 ;;
            --folders|--recent|--recent-days) [ -n "${2:-}" ] || return 1; arguments+=( "$1" "$2" ); shift 2 ;;
            -*) _err "Unknown drive sync option: $1"; return 1 ;;
            *) alias="$1"; shift ;;
        esac
    done
    [ -n "$alias" ] || { _err 'drive sync requires ALIAS'; return 1; }
    if [ "$explicit_exclusion" -eq 0 ]; then
        exclusion_type="$(_google_account_value "$alias" '.drive.index_exclude | type')" || return 1
        [ "$exclusion_type" = array ] || { _err 'Legacy implicit exclusions are retired: supply --exclude-folder NAME or configure drive.index_exclude explicitly (an empty array deliberately permits all child samples).'; return 1; }
    fi
    [ -n "$out" ] || { _err 'drive sync requires --output FILE'; return 1; }
    if [ "${#arguments[@]}" -gt 0 ]; then _drive_export_index "$alias" --output "$out" "${arguments[@]}"
    else _drive_export_index "$alias" --output "$out"
    fi
}
