#!/usr/bin/env bash
##- LifeOS Microsoft 365: delegated auth plus bounded mail, calendar, and Outlook contact reads and gated writes, including opt-in mail moves between folders (never delete). Planner lives in m365-planner.sh.
##- Sourced by lifeos.sh after common.sh and google.sh; uses the shared people alias map for deterministic attendee resolution.

source "${LIB_DIR}/../../agent-hands/skills/authorize-microsoft/scripts/client.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-mail/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-calendar/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-microsoft-files/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-contacts/scripts/operations.sh"

_m365_accounts_path() {
    if _var_is_set M365_ACCOUNTS_PATH; then
        _path_value M365_ACCOUNTS_PATH
    else
        printf '%s/m365-accounts.json\n' "$SECRETS_DIR"
    fi
}

_m365_path() {
    local value="$1"
    case "$value" in
        '') return 1 ;;
        /*) printf '%s\n' "$value" ;;
        ~/*) printf '%s/%s\n' "$HOME" "${value#~/}" ;;
        \$CONFIGS/*) printf '%s/%s\n' "$CONFIGS" "${value#\$CONFIGS/}" ;;
        \$HOME/*) printf '%s/%s\n' "$HOME" "${value#\$HOME/}" ;;
        *) printf '%s/%s\n' "$SECRETS_DIR" "$value" ;;
    esac
}

_m365_accounts_ready() {
    local config
    config="$(_m365_accounts_path)"
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    if [ ! -f "$config" ]; then
        _err "Microsoft 365 account config does not exist: $config"
        _say "NEXT: cp ${SECRETS_DIR}/m365-accounts.example.json $config"
        return 1
    fi
    return 0
}

# Provider mechanics are shared; the hooks below retain existing local configuration and SDK context behavior.
_m365_python() { shift; "$LIFEOS_PY" "$@"; }
_m365_expected_account() { _m365_account_value "$1" '.expected_account' 2>/dev/null || printf ''; }

_m365_sources_dir() {
    printf '%s/m365\n' "$(_sources_dir)"
}

_m365_output() {
    local alias="$1" service="$2" qa="$3"
    if [ "$qa" -eq 1 ]; then
        printf '%s/m365/%s-%s.md\n' "$QA_DIR" "$alias" "$service"
    else
        printf '%s/%s-%s.md\n' "$(_m365_sources_dir)" "$alias" "$service"
    fi
}

_m365_write_index() {
    local dir="$1" refreshed="${2:-}" alias service file
    [ -d "$dir" ] || return 0
    {
        printf '# Microsoft 365\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf '## Source Snapshots\n\n'
        while IFS= read -r alias || [ -n "$alias" ]; do
            for service in mail calendar contacts planner; do
                file="${alias}-${service}.md"
                [ -f "${dir}/${file}" ] && printf -- '- [%s %s](%s)\n' "$alias" "$service" "$file"
            done
        done <<EOF
$(jq -r '(.accounts // [])[] | .alias' "$(_m365_accounts_path)")
EOF
    } > "${dir}/index.md"
}

_m365_days_ago() {
    "$LIFEOS_PY" -c 'from datetime import datetime, timedelta, timezone; import sys; print((datetime.now(timezone.utc) - timedelta(days=int(sys.argv[1]))).replace(microsecond=0).isoformat().replace("+00:00", "Z"))' "$1"
}

_m365_render_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-render.py" "$@"
}

_m365_write_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-write.py" "$@"
}

_m365_mail_python() { "$LIFEOS_PY" "$@"; }
_m365_mail_audit_path() { _mail_audit_log_path; }
_m365_mail_audit_append() { _mail_audit_append; }
_m365_mail_sync() {
    local alias="${1:-}" qa=0 out="" refreshed
    [ -n "$alias" ] || { _err 'm365 mail sync requires ALIAS'; return 1; }
    shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) qa=1; shift ;;
            --output) [ -n "${2:-}" ] || return 1; out="$2"; shift 2 ;;
            *) _err "Unknown m365 mail sync option: $1"; return 1 ;;
        esac
    done
    if [ -z "$out" ]; then
        if [ "$qa" -eq 0 ]; then _vault_ready && _ensure_sources_dir || return 1; fi
        out="$(_m365_output "$alias" mail "$qa")" || return 1
    fi
    _ensure_parent_dir "$out" || return 1
    _m365_mail_export "$alias" --output "$out" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    case "$out" in */m365/*.md) _m365_write_index "$(dirname "$out")" "$refreshed" ;; esac
}

_m365_calendar_timezone() {
    local alias="$1"
    _m365_account_value "$alias" '.calendar.timezone // "Central Standard Time"' 2>/dev/null || printf 'Central Standard Time'
}

_m365_calendar_window() {
    "$LIFEOS_PY" -c 'from datetime import datetime, timedelta, timezone; import sys; now=datetime.now(timezone.utc); start=(now-timedelta(days=int(sys.argv[1]))).replace(hour=0,minute=0,second=0,microsecond=0); end=(now+timedelta(days=int(sys.argv[2])+1)).replace(hour=0,minute=0,second=0,microsecond=0); print(start.isoformat().replace("+00:00","Z")); print(end.isoformat().replace("+00:00","Z"))' "$LIFEOS_DAYS_BACK" "$LIFEOS_DAYS_AHEAD"
}

_m365_calendar_enabled_aliases() {
    local accounts_path
    accounts_path="$(_m365_accounts_path)"
    [ -f "$accounts_path" ] || return 0
    jq -r '(.accounts // [])[] | select((.calendar.enabled // false) == true) | .alias' "$accounts_path" 2>/dev/null
}

_m365_calendar_normalize_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-calendar-normalize.py" "$@"
}

_m365_calendar_sync() {
    local alias="${1:-}" qa=0 custom_out="" out tmp json profile_email refreshed window from to timezone ids limit dir
    [ -n "$alias" ] || { _err "m365 calendar sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) qa=1; shift ;;
            --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;;
            *) _err "Unknown m365 calendar sync option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" calendar || return 1
    if [ -n "$custom_out" ]; then out="$custom_out"; elif [ "$qa" -eq 1 ]; then out="$(_m365_output "$alias" calendar 1)"; else _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_m365_output "$alias" calendar 0)"; fi
    _ensure_parent_dir "$out" || return 1
    _m365_calendar_export "$alias" --output "$out" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    dir="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dir" "$refreshed" ;; esac
}

_m365_resolve_attendees() {
    local raw email
    _RESOLVED_EMAILS=()
    _RESOLVED_DISPLAY=()
    for raw in "$@"; do
        case "$raw" in
            *@*) email="$raw" ;;
            *)
                email="$(_people_alias_lookup "$raw")" || {
                    _err "No deterministic local alias matched '$raw'. Pass a full email or run 'lifeos people add-alias NAME EMAIL'."
                    return 1
                }
                ;;
        esac
        _RESOLVED_EMAILS+=("$email")
        if [ "$raw" = "$email" ]; then _RESOLVED_DISPLAY+=("$email"); else _RESOLVED_DISPLAY+=("$raw -> $email"); fi
    done
}

_m365_contacts_sync() {
    local alias="${1:-}" qa=0 custom_out="" out refreshed dir
    [ -n "$alias" ] || { _err "m365 contacts sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --qa) qa=1; shift ;; --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;; *) _err "Unknown m365 contacts sync option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" contacts || return 1
    if [ -n "$custom_out" ]; then out="$custom_out"; elif [ "$qa" -eq 1 ]; then out="$(_m365_output "$alias" contacts 1)"; else _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_m365_output "$alias" contacts 0)"; fi
    _ensure_parent_dir "$out" || return 1
    _m365_contacts_export "$alias" --output "$out" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    dir="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dir" "$refreshed" ;; esac
}

_m365_dispatch() {
    case "${1:-}" in
        accounts) shift; _m365_accounts_list "$@" ;;
        auth) shift; _m365_auth "$@" ;;
        profile) shift; _m365_profile "$@" ;;
        mail)
            case "${2:-}" in
                sync) shift 2; _m365_mail_sync "$@" ;;
                folders) shift 2; _m365_mail_folders "$@" ;;
                list) shift 2; _m365_mail_list "$@" ;;
                read) shift 2; _m365_mail_read "$@" ;;
                move) shift 2; _m365_mail_move "$@" ;;
                archive) shift 2; _m365_mail_archive "$@" ;;
                unarchive) shift 2; _m365_mail_unarchive "$@" ;;
                create-folder) shift 2; _m365_mail_create_folder "$@" ;;
                junk) shift 2; _m365_mail_junk "$@" ;;
                attachments) shift 2; _m365_mail_attachments "$@" ;;
                categorize) shift 2; _m365_mail_category_cmd categorize "$@" ;;
                uncategorize) shift 2; _m365_mail_category_cmd uncategorize "$@" ;;
                not-junk) shift 2; _m365_mail_not_junk "$@" ;;
                rules) shift 2; _m365_mail_rules "$@" ;;
                create-rule) shift 2; _m365_mail_create_rule "$@" ;;
                delete-rule) shift 2; _m365_mail_delete_rule "$@" ;;
                *) _err "Unknown m365 mail command: ${2:-}"; return 1 ;;
            esac
            ;;
        calendar)
            case "${2:-}" in
                list-calendars) shift 2; _m365_calendar_list "$@" ;;
                find) shift 2; _m365_calendar_find "$@" ;;
                sync) shift 2; _m365_calendar_sync "$@" ;;
                export-data) shift 2; _m365_calendar_export_data "$@" ;;
                create-event) shift 2; _m365_calendar_create "$@" ;;
                update-event) shift 2; _m365_calendar_update "$@" ;;
                *) _err "Unknown m365 calendar command: ${2:-}"; return 1 ;;
            esac
            ;;
        files)
            case "${2:-}" in
                search) shift 2; _m365_files_search "$@" ;;
                resolve-link) shift 2; _m365_files_resolve_link "$@" ;;
                meta) shift 2; _m365_files_meta "$@" ;;
                download) shift 2; _m365_files_download "$@" ;;
                upload) shift 2; _m365_files_upload "$@" ;;
                replace) shift 2; _m365_files_replace "$@" ;;
                create-folder) shift 2; _m365_files_create_folder "$@" ;;
                *) _err "Unknown m365 files command: ${2:-}"; return 1 ;;
            esac
            ;;
        contacts)
            case "${2:-}" in
                list) shift 2; _m365_contacts_list "$@" ;;
                find) shift 2; _m365_contacts_find "$@" ;;
                sync) shift 2; _m365_contacts_sync "$@" ;;
                create) shift 2; _m365_contacts_create "$@" ;;
                update) shift 2; _m365_contacts_update "$@" ;;
                *) _err "Unknown m365 contacts command: ${2:-}"; return 1 ;;
            esac
            ;;
        planner) shift; _m365_planner_dispatch "$@" ;;
        excel) shift; _m365_excel_dispatch "$@" ;;
        *) _err "Unknown m365 command: ${1:-}"; return 1 ;;
    esac
}
