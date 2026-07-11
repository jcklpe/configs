#!/usr/bin/env bash
##- LifeOS helper CLI
##- Pulls source data into the private LifeOS vault and supports bounded, explicit writes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="${CONFIGS:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
LIB_DIR="${SCRIPT_DIR}/lib"
ENV_FILE="${SCRIPT_DIR}/.env"

LIFEOS_DAYS_BACK="${LIFEOS_DAYS_BACK:-14}"
LIFEOS_DAYS_AHEAD="${LIFEOS_DAYS_AHEAD:-30}"

# Shared helpers live in lib/. common.sh must load first — the feature modules use its functions.
. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/trello.sh"
. "${LIB_DIR}/google.sh"

_usage() {
    cat <<'EOF'
LifeOS helper

Usage:
  ./lifeos.sh help
  ./lifeos.sh doctor
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
  ./lifeos.sh open-austin-org path
  ./lifeos.sh open-austin-org sync [--qa | --output DIR]
  ./lifeos.sh open-austin-org create-issue --title TITLE [--body TEXT | --body-file FILE] [--label LABEL] [--assign-me | --assignee LOGIN] [--repo OWNER/REPO] [--execute] [--no-sync]
  ./lifeos.sh sync

Real config lives in .env, copied from .env.example.
EOF
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
    local issues=0 vault sources file google_accounts google_aliases google_alias google_token

    if [ -f "$ENV_FILE" ]; then
        _say "OK: ${ENV_FILE}"
    else
        _say "MISSING: ${ENV_FILE}"
        _say "NEXT: cp ${SCRIPT_DIR}/.env.example ${ENV_FILE}"
        issues=$((issues + 1))
    fi

    _check_command curl || issues=$((issues + 1))
    _check_command jq || issues=$((issues + 1))
    _check_command python3 || issues=$((issues + 1))

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
        _say "NEXT: cp ${SCRIPT_DIR}/google-accounts.example.json $google_accounts"
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

For Open Austin GitHub/org work, also read:

$vault/open-austin/repo.md
$vault/sources/open-austin-org/issues.md
$vault/sources/open-austin-org/board-org-kanban.md

Then add the relevant focus-thread file, such as:

$vault/open-austin/index.open-austin.md
EOF
}

_open_austin_org_repo_path() {
    if _var_is_set OPEN_AUSTIN_ORG_REPO_PATH; then
        _path_value OPEN_AUSTIN_ORG_REPO_PATH
    else
        printf "%s/work/org\n" "$HOME"
    fi
}

_open_austin_org_snapshot_dir() {
    printf "%s/snapshot\n" "$(_open_austin_org_repo_path)"
}

_open_austin_org_ready() {
    local repo run
    repo="$(_open_austin_org_repo_path)"
    run="${repo}/tools/sync/run.sh"

    if [ ! -d "$repo" ]; then
        _err "OPEN_AUSTIN_ORG_REPO_PATH does not exist: $repo"
        return 1
    fi
    if [ ! -x "$run" ]; then
        _err "Open Austin org sync script is missing or not executable: $run"
        return 1
    fi
    return 0
}

_open_austin_org_path() {
    local repo snapshot
    repo="$(_open_austin_org_repo_path)"
    snapshot="$(_open_austin_org_snapshot_dir)"
    _say "Repo: $repo"
    _say "Snapshot: $snapshot"
    if _vault_ready >/dev/null 2>&1; then
        _say "LifeOS output: $(_sources_dir)/open-austin-org"
    fi
}

_copy_open_austin_org_snapshot() {
    local src="$1" dest="$2" name

    [ -d "$src" ] || { _err "Snapshot directory does not exist: $src"; return 1; }
    mkdir -p "$dest" || return 1

    find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

    for name in issues.md labels.md board-org-kanban.md board-open-roles.md weekly-summary.md; do
        if [ -f "$src/$name" ]; then
            cp "$src/$name" "$dest/$name" || return 1
        fi
    done

    if [ -d "$src/issues" ]; then
        mkdir -p "$dest/issues" || return 1
        find "$src/issues" -maxdepth 1 -type f -name "*.md" -exec cp {} "$dest/issues/" \;
    fi
}

_open_austin_org_sync() {
    local custom_out="" repo snapshot out

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${SCRIPT_DIR}/open-austin-org-qa"
                shift
                ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires DIR"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown open-austin-org sync option: $1"; return 1 ;;
        esac
    done

    _open_austin_org_ready || return 1
    repo="$(_open_austin_org_repo_path)"
    snapshot="$(_open_austin_org_snapshot_dir)"

    _say "Refreshing Open Austin org snapshot from $repo" >&2
    (cd "$repo" && tools/sync/run.sh) || return 1

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/open-austin-org"
    fi

    _copy_open_austin_org_snapshot "$snapshot" "$out" || return 1

    _say "Updated $out"
    [ -f "$out/issues.md" ] && _say "- $out/issues.md"
    [ -f "$out/board-org-kanban.md" ] && _say "- $out/board-org-kanban.md"
    [ -f "$out/board-open-roles.md" ] && _say "- $out/board-open-roles.md"
    [ -f "$out/weekly-summary.md" ] && _say "- $out/weekly-summary.md"
}


_open_austin_org_github_repo() {
    if _var_is_set OPEN_AUSTIN_ORG_GITHUB_REPO; then
        _path_value OPEN_AUSTIN_ORG_GITHUB_REPO
    else
        printf 'open-austin/org\n'
    fi
}

_open_austin_org_gh_ready() {
    _check_command gh >/dev/null || { _err "gh is required"; return 1; }
    return 0
}

_open_austin_org_create_issue() {
    local repo title="" body="" body_file="" execute=0 sync_after=1 assign_me=0 login="" created_url=""
    local labels=() assignees=() cmd=()

    repo="$(_open_austin_org_github_repo)"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --title)
                [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }
                title="$2"
                shift 2
                ;;
            --body)
                [ -n "${2+x}" ] || { _err "--body requires TEXT"; return 1; }
                body="$2"
                shift 2
                ;;
            --body-file)
                [ -n "${2:-}" ] || { _err "--body-file requires FILE"; return 1; }
                body_file="$2"
                shift 2
                ;;
            --label)
                [ -n "${2:-}" ] || { _err "--label requires LABEL"; return 1; }
                labels+=("$2")
                shift 2
                ;;
            --assignee|--assign)
                [ -n "${2:-}" ] || { _err "$1 requires LOGIN"; return 1; }
                assignees+=("$2")
                shift 2
                ;;
            --assign-me)
                assign_me=1
                shift
                ;;
            --repo)
                [ -n "${2:-}" ] || { _err "--repo requires OWNER/REPO"; return 1; }
                repo="$2"
                shift 2
                ;;
            --execute)
                execute=1
                shift
                ;;
            --dry-run)
                execute=0
                shift
                ;;
            --no-sync)
                sync_after=0
                shift
                ;;
            *) _err "Unknown open-austin-org create-issue option: $1"; return 1 ;;
        esac
    done

    [ -n "$title" ] || { _err "create-issue requires --title"; return 1; }
    if [ -n "$body_file" ] && [ ! -f "$body_file" ]; then
        _err "Body file does not exist: $body_file"
        return 1
    fi

    if [ "$assign_me" -eq 1 ] && [ "$execute" -eq 1 ]; then
        _open_austin_org_gh_ready || return 1
        login="$(gh api user --jq .login)" || return 1
        assignees+=("$login")
    elif [ "$assign_me" -eq 1 ]; then
        assignees+=("@me")
    fi

    _say "GitHub issue create plan:"
    _say "Repo: $repo"
    _say "Title: $title"
    if [ -n "$body_file" ]; then
        _say "Body file: $body_file"
    elif [ -n "$body" ]; then
        _say "Body:"
        printf '%s\n' "$body"
    else
        _say "Body: <empty>"
    fi
    if [ "${#labels[@]}" -gt 0 ]; then
        _say "Labels: ${labels[*]}"
    else
        _say "Labels: <none>"
    fi
    if [ "${#assignees[@]}" -gt 0 ]; then
        _say "Assignees: ${assignees[*]}"
    else
        _say "Assignees: <none>"
    fi

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no GitHub issue was created. Re-run with --execute to create it."
        return 0
    fi

    _open_austin_org_gh_ready || return 1

    cmd=(gh issue create --repo "$repo" --title "$title")
    if [ -n "$body_file" ]; then
        cmd+=(--body-file "$body_file")
    else
        cmd+=(--body "$body")
    fi
    for label in "${labels[@]}"; do
        cmd+=(--label "$label")
    done
    for login in "${assignees[@]}"; do
        cmd+=(--assignee "$login")
    done

    created_url="$("${cmd[@]}")" || return 1
    _say "Created issue: $created_url"

    if [ "$sync_after" -eq 1 ]; then
        _open_austin_org_sync || return 1
    fi
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
