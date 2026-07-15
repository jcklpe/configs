#!/usr/bin/env bash
##- LifeOS helper CLI
##- Pulls source data into the private LifeOS vault and supports bounded, explicit writes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="${CONFIGS:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
LIB_DIR="${SCRIPT_DIR}/lib"
SECRETS_DIR="${SCRIPT_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"
QA_DIR="${SCRIPT_DIR}/qa"

LIFEOS_DAYS_BACK="${LIFEOS_DAYS_BACK:-14}"
LIFEOS_DAYS_AHEAD="${LIFEOS_DAYS_AHEAD:-30}"

# Shared helpers live in lib/. common.sh must load first — the feature modules use its functions.
. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/trello.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"
. "${LIB_DIR}/open-austin-org.sh"
. "${LIB_DIR}/resume.sh"

_usage() {
    cat <<'EOF'
LifeOS helper

Usage:
  ./lifeos.sh help
  ./lifeos.sh doctor
  ./lifeos.sh setup
  ./lifeos.sh open
  ./lifeos.sh context
  ./lifeos.sh trello list-boards
  ./lifeos.sh trello list-lists [board_id]
  ./lifeos.sh trello sync [--qa | --output FILE]
  ./lifeos.sh trello add-card --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello move-card --card CARD_ID_OR_URL --list LIST [--board BOARD_ID]
  ./lifeos.sh trello rename-card --card CARD_ID_OR_URL --name NAME
  ./lifeos.sh trello set-desc --card CARD_ID_OR_URL --file FILE
  ./lifeos.sh trello comment --card CARD_ID_OR_URL (--text TEXT | --file FILE)
  ./lifeos.sh trello supersede --from CARD_ID_OR_URL --to CARD_ID_OR_URL [--board BOARD_ID]
  ./lifeos.sh trello supersede --create --from CARD_ID_OR_URL --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello chain --card CARD_ID_OR_URL [--json]
  ./lifeos.sh calendar auth
  ./lifeos.sh calendar list-calendars
  ./lifeos.sh calendar find QUERY [--calendar CALENDAR_ID] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--json]
  ./lifeos.sh calendar sync [--qa | --output FILE]
  ./lifeos.sh calendar create-event --title TITLE --start DATE_OR_DATETIME [--end ...] [--calendar CALENDAR_ID] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--recurrence RRULE]... [--notify] [--execute]
  ./lifeos.sh calendar update-event --event EVENT_ID [--series | --instance] [--calendar CALENDAR_ID] [--title TEXT] [--start ...] [--end ...] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--replace-attendees] [--recurrence RRULE]... [--notify] [--execute]
  ./lifeos.sh people resolve NAME [--json]
  ./lifeos.sh people list-aliases
  ./lifeos.sh people add-alias NAME EMAIL
  ./lifeos.sh google accounts
  ./lifeos.sh google auth ALIAS [--no-browser]
  ./lifeos.sh gmail sync ALIAS [--qa | --output FILE]
  ./lifeos.sh gmail sync --all [--qa]
  ./lifeos.sh drive accounts
  ./lifeos.sh drive search ALIAS QUERY [--json]
  ./lifeos.sh drive list ALIAS FOLDER_ID [--json]
  ./lifeos.sh drive meta ALIAS FILE_URL_OR_ID [--json]
  ./lifeos.sh drive read ALIAS FILE_URL_OR_ID [--range RANGE]
  ./lifeos.sh drive import-doc ALIAS SOURCE_FILE --title TITLE [--folder FOLDER_ID] [--execute]
  ./lifeos.sh m365 accounts
  ./lifeos.sh m365 auth ALIAS [--no-browser]
  ./lifeos.sh m365 profile ALIAS [--json]
  ./lifeos.sh m365 mail sync ALIAS [--qa | --output FILE]
  ./lifeos.sh m365 calendar list-calendars ALIAS
  ./lifeos.sh m365 calendar find ALIAS QUERY [--calendar ID] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--json]
  ./lifeos.sh m365 calendar sync ALIAS [--qa | --output FILE]
  ./lifeos.sh m365 calendar create-event ALIAS --title TITLE --start DATE_OR_DATETIME [--end ...] [--calendar ID] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--notify] [--execute]
  ./lifeos.sh m365 calendar update-event ALIAS --event ID [--calendar ID] [--title TEXT] [--start ...] [--end ...] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--replace-attendees] [--notify] [--execute]
  ./lifeos.sh m365 contacts list ALIAS [--json]
  ./lifeos.sh m365 contacts find ALIAS QUERY [--json]
  ./lifeos.sh m365 contacts sync ALIAS [--qa | --output FILE]
  ./lifeos.sh m365 contacts create ALIAS [--display-name TEXT] [--given-name TEXT] [--surname TEXT] [--email ADDRESS]... [--phone NUMBER]... [--mobile NUMBER] [--company TEXT] [--job-title TEXT] [--notes TEXT | --notes-file FILE] [--execute]
  ./lifeos.sh m365 contacts update ALIAS --contact ID [contact fields...] [--execute]
  ./lifeos.sh resume render INPUT.md [--output PATH] [--theme CSS] [--open]
  ./lifeos.sh open-austin-org path
  ./lifeos.sh open-austin-org sync [--qa | --output DIR]
  ./lifeos.sh open-austin-org create-issue --title TITLE [--body TEXT | --body-file FILE] [--label LABEL] [--assign-me | --assignee LOGIN] [--repo OWNER/REPO] [--execute] [--no-sync]
  ./lifeos.sh sync

Real config lives in .env, copied from .env.example.
EOF
}

_setup() {
    if ! command -v uv >/dev/null 2>&1; then
        _err "uv is required for setup — install it (brew install uv), then re-run"
        return 1
    fi
    _say "Syncing lifeos-tools Python env (uv sync)..."
    ( cd "${SCRIPT_DIR}" && uv sync ) || { _err "uv sync failed"; return 1; }
    _say "OK: .venv ready ($(${SCRIPT_DIR}/.venv/bin/python --version 2>&1))"
}

_doctor_file() {
    if [ -f "$1" ]; then
        _say "OK: $1"
        return 0
    fi
    _say "MISSING: $1"
    return 1
}

_doctor() {
    local issues=0 vault sources file google_accounts google_aliases google_alias google_token m365_accounts m365_aliases m365_alias m365_token

    if [ -f "$ENV_FILE" ]; then
        _say "OK: ${ENV_FILE}"
    else
        _say "MISSING: ${ENV_FILE}"
        _say "NEXT: cp ${SECRETS_DIR}/.env.example ${ENV_FILE}"
        issues=$((issues + 1))
    fi

    _check_command curl || issues=$((issues + 1))
    _check_command jq || issues=$((issues + 1))
    _check_command python3 || issues=$((issues + 1))

    # Resume render pipeline (optional feature): pandoc + weasyprint.
    _check_command pandoc
    _check_command weasyprint

    # Python env for lib/*.py: uv-managed venv preferred, system python3 as fallback.
    _check_command uv
    if [ -x "${SCRIPT_DIR}/.venv/bin/python" ]; then
        _say "OK: uv venv present ($(${SCRIPT_DIR}/.venv/bin/python --version 2>&1))"
    else
        _say "OPTIONAL: uv venv (.venv) not set up; using system python3. Run './lifeos.sh setup' to create it."
    fi

    if _var_is_set LIFEOS_VAULT_PATH; then
        vault="$(_vault_path)"
        _say "OK: LIFEOS_VAULT_PATH is set: $vault"
        if _vault_ready; then
            sources="$(_sources_dir)"
            if [ -d "$sources" ]; then
                _say "OK: ${sources}"
            else
                _say "MISSING: ${sources}"
                _say "NEXT: sync commands will create ${sources}"
            fi

            for file in README.md now.md weekly-review.md; do
                _doctor_file "$vault/$file" || issues=$((issues + 1))
            done
        else
            issues=$((issues + 1))
        fi
    else
        _say "MISSING: LIFEOS_VAULT_PATH"
        issues=$((issues + 1))
    fi

    _redacted_status TRELLO_API_KEY || issues=$((issues + 1))
    _redacted_status TRELLO_TOKEN || issues=$((issues + 1))
    if _var_is_set TRELLO_WRITE_TOKEN; then
        _say "OK: TRELLO_WRITE_TOKEN is set (redacted)"
    else
        _say "OPTIONAL: TRELLO_WRITE_TOKEN is not set; Trello write commands will be disabled"
    fi
    if _var_is_set TRELLO_BOARD_IDS; then
        _say "OK: TRELLO_BOARD_IDS is set"
    else
        _say "MISSING: TRELLO_BOARD_IDS"
        _say "NEXT: run './lifeos.sh trello list-boards' after Trello auth is configured"
    fi

    if _var_is_set GOOGLE_CALENDAR_CREDENTIALS_PATH; then
        _say "OK: GOOGLE_CALENDAR_CREDENTIALS_PATH is configured"
        if [ -f "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" ]; then
            _say "OK: Google Calendar credentials file exists"
        else
            _say "MISSING: Google Calendar credentials file"
        fi
    else
        _say "MISSING: GOOGLE_CALENDAR_CREDENTIALS_PATH"
    fi

    if _var_is_set GOOGLE_CALENDAR_TOKEN_PATH; then
        _say "OK: GOOGLE_CALENDAR_TOKEN_PATH is configured"
        if [ -f "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)" ]; then
            _say "OK: Google Calendar token file exists"
        else
            _say "MISSING: Google Calendar token file"
            _say "NEXT: run './lifeos.sh calendar auth'"
        fi
    else
        _say "MISSING: GOOGLE_CALENDAR_TOKEN_PATH"
    fi

    google_accounts="$(_google_accounts_path)"
    if [ -f "$google_accounts" ]; then
        if jq -e '.accounts | type == "array"' "$google_accounts" >/dev/null 2>&1; then
            _say "OK: Google account alias config exists"
            google_aliases="$(jq -r '(.accounts // [])[] | select((.gmail.enabled // false) == true or (.drive.enabled // false) == true) | .alias' "$google_accounts")"
            for google_alias in $google_aliases; do
                google_token="$(_google_account_path "$google_alias" '.token_path')" || google_token=""
                if [ -n "$google_token" ] && [ -f "$google_token" ]; then
                    _say "OK: Google token exists for alias '$google_alias'"
                else
                    _say "MISSING: Google token for alias '$google_alias'"
                    _say "NEXT: run './lifeos.sh google auth $google_alias'"
                fi
            done
        else
            _say "MISSING: Google account alias config is not valid JSON shape"
        fi
    else
        _say "OPTIONAL: Google account alias config is not set up for Gmail/Drive"
        _say "NEXT: cp ${SECRETS_DIR}/google-accounts.example.json $google_accounts"
    fi

    m365_accounts="$(_m365_accounts_path)"
    if [ -f "$m365_accounts" ]; then
        if jq -e '.accounts | type == "array"' "$m365_accounts" >/dev/null 2>&1; then
            _say "OK: Microsoft 365 account alias config exists"
            if "$LIFEOS_PY" -c 'import msal' >/dev/null 2>&1; then
                _say "OK: MSAL is installed"
            else
                _say "MISSING: MSAL Python dependency"
                _say "NEXT: run './lifeos.sh setup'"
                issues=$((issues + 1))
            fi
            m365_aliases="$(jq -r '(.accounts // [])[] | select((.mail.enabled // false) == true or (.calendar.enabled // false) == true or (.contacts.enabled // false) == true) | .alias' "$m365_accounts")"
            for m365_alias in $m365_aliases; do
                m365_token="$(_m365_account_path "$m365_alias" '.token_path')" || m365_token=""
                if [ -n "$m365_token" ] && [ -f "$m365_token" ]; then
                    _say "OK: Microsoft token cache exists for alias '$m365_alias'"
                else
                    _say "MISSING: Microsoft token cache for alias '$m365_alias'"
                    _say "NEXT: run './lifeos.sh m365 auth $m365_alias'"
                fi
            done
        else
            _say "MISSING: Microsoft 365 account alias config is not valid JSON shape"
            issues=$((issues + 1))
        fi
    else
        _say "OPTIONAL: Microsoft 365 account alias config is not set up"
        _say "NEXT: cp ${SECRETS_DIR}/m365-accounts.example.json $m365_accounts"
    fi

    if [ "$issues" -eq 0 ]; then
        _say "OK: doctor found no blocking issues for the implemented commands"
        return 0
    fi

    _say "Doctor found $issues issue(s)"
    return 1
}

_open_vault() {
    _vault_ready || return 1
    if command -v code >/dev/null 2>&1; then
        code "$(_vault_path)"
    else
        _say "$(_vault_path)"
    fi
}

_context() {
    local vault
    _require_var LIFEOS_VAULT_PATH || return 1
    vault="$(_vault_path)"
    cat <<EOF
Recommended LifeOS context files:

$vault/README.md
$vault/now.md
$vault/weekly-review.md
$vault/sources/trello.md
$vault/sources/calendar.md
$vault/sources/gmail/
$vault/sources/m365/

For Open Austin GitHub/org work, also read:

$vault/open-austin/repo.md
$vault/sources/open-austin-org/issues.md
$vault/sources/open-austin-org/board-org-kanban.md

Then add the relevant focus-thread file, such as:

$vault/open-austin/index.open-austin.md
EOF
}

_sync() {
    local status=0

    if _var_is_set TRELLO_API_KEY && _var_is_set TRELLO_TOKEN && _var_is_set TRELLO_BOARD_IDS; then
        _trello_sync || status=$?
    else
        _warn "Skipping Trello sync: Trello env values are incomplete."
    fi

    if _var_is_set GOOGLE_CALENDAR_CREDENTIALS_PATH || _var_is_set GOOGLE_CALENDAR_TOKEN_PATH; then
        _calendar_sync || status=$?
    else
        _warn "Skipping Calendar sync: Google Calendar is not configured."
    fi

    return "$status"
}

_load_env

case "${1:-help}" in
    help|-h|--help)
        _usage
        ;;
    doctor)
        _doctor
        ;;
    setup)
        _setup
        ;;
    open)
        _open_vault
        ;;
    context)
        _context
        ;;
    trello)
        case "${2:-}" in
            list-boards) _trello_list_boards ;;
            list-lists) shift 2; _trello_list_lists "$@" ;;
            sync) shift 2; _trello_sync "$@" ;;
            add-card) shift 2; _trello_add_card "$@" ;;
            move-card) shift 2; _trello_move_card "$@" ;;
            rename-card) shift 2; _trello_rename_card "$@" ;;
            set-desc) shift 2; _trello_set_desc "$@" ;;
            comment) shift 2; _trello_comment "$@" ;;
            supersede) shift 2; _trello_supersede "$@" ;;
            chain) shift 2; _trello_chain "$@" ;;
            *) _err "Unknown Trello command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    calendar)
        case "${2:-}" in
            auth) shift 2; _calendar_auth "$@" ;;
            list-calendars) shift 2; _calendar_list_calendars "$@" ;;
            find) shift 2; _calendar_find "$@" ;;
            sync) shift 2; _calendar_sync "$@" ;;
            create-event) shift 2; _calendar_create_event "$@" ;;
            update-event) shift 2; _calendar_update_event "$@" ;;
            *) _err "Unknown Calendar command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    google)
        case "${2:-}" in
            accounts) shift 2; _google_accounts_list "$@" ;;
            auth) shift 2; _google_auth "$@" ;;
            *) _err "Unknown Google command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    people)
        case "${2:-}" in
            resolve) shift 2; _people_resolve "$@" ;;
            list-aliases) shift 2; _people_list_aliases "$@" ;;
            add-alias) shift 2; _people_add_alias "$@" ;;
            *) _err "Unknown People command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    gmail)
        case "${2:-}" in
            sync) shift 2; _gmail_sync "$@" ;;
            *) _err "Unknown Gmail command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    drive)
        case "${2:-}" in
            accounts) shift 2; _drive_accounts "$@" ;;
            search) shift 2; _drive_search "$@" ;;
            list) shift 2; _drive_list "$@" ;;
            meta) shift 2; _drive_meta "$@" ;;
            read) shift 2; _drive_read "$@" ;;
            import-doc) shift 2; _drive_import_doc "$@" ;;
            *) _err "Unknown Drive command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    m365)
        shift
        _m365_dispatch "$@"
        ;;
    resume)
        case "${2:-}" in
            render) shift 2; _resume_render "$@" ;;
            *) _err "Unknown Resume command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    open-austin-org)
        case "${2:-}" in
            path) shift 2; _open_austin_org_path "$@" ;;
            sync) shift 2; _open_austin_org_sync "$@" ;;
            create-issue) shift 2; _open_austin_org_create_issue "$@" ;;
            *) _err "Unknown Open Austin org command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    sync)
        _sync
        ;;
    *)
        _err "Unknown command: $1"
        _usage
        exit 1
        ;;
esac
