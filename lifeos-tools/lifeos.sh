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
LIFEOS_LONG_HORIZON_DAYS="${LIFEOS_LONG_HORIZON_DAYS:-180}"

# Shared helpers live in lib/. common.sh must load first — the feature modules use its functions.
. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/trello.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"
. "${LIB_DIR}/m365-planner.sh"
. "${LIB_DIR}/m365-files.sh"
. "${LIB_DIR}/mail-filters.sh"
. "${LIB_DIR}/odoo.sh"
. "${LIB_DIR}/slack.sh"
. "${LIB_DIR}/github.sh"
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
  ./lifeos.sh trello list-labels [board_id]
  ./lifeos.sh trello sync [--qa | --output FILE]
  ./lifeos.sh trello add-card --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello move-card --card CARD_ID_OR_URL --list LIST [--board BOARD_ID]
  ./lifeos.sh trello snooze --card CARD_ID_OR_URL --until YYYY-MM-DD [--list LIST] [--board BOARD_ID]
  ./lifeos.sh trello rename-card --card CARD_ID_OR_URL --name NAME
  ./lifeos.sh trello set-desc --card CARD_ID_OR_URL --file FILE
  ./lifeos.sh trello comment --card CARD_ID_OR_URL (--text TEXT | --file FILE)
  ./lifeos.sh trello create-label --name NAME [--color COLOR] [--board BOARD_ID]
  ./lifeos.sh trello add-label --card CARD_ID_OR_URL --label LABEL_ID_OR_NAME [--board BOARD_ID]
  ./lifeos.sh trello remove-label --card CARD_ID_OR_URL --label LABEL_ID_OR_NAME [--board BOARD_ID]
  ./lifeos.sh trello delete-label --label LABEL_ID_OR_NAME [--board BOARD_ID]
  ./lifeos.sh trello supersede --from CARD_ID_OR_URL --to CARD_ID_OR_URL [--board BOARD_ID]
  ./lifeos.sh trello supersede --create --from CARD_ID_OR_URL --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello chain --card CARD_ID_OR_URL [--json]
  ./lifeos.sh calendar auth
  ./lifeos.sh calendar list-calendars
  ./lifeos.sh calendar find QUERY [--calendar CALENDAR_ID] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--json]
  ./lifeos.sh calendar sync [--google-only] [--qa | --output FILE]   # one agenda: Google calendars plus enabled Microsoft 365 calendars
  ./lifeos.sh calendar create-event --title TITLE --start DATE_OR_DATETIME [--end ...] [--calendar CALENDAR_ID] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--recurrence RRULE]... [--notify] [--execute]
  ./lifeos.sh calendar update-event --event EVENT_ID [--series | --instance] [--calendar CALENDAR_ID] [--title TEXT] [--start ...] [--end ...] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--replace-attendees] [--recurrence RRULE]... [--notify] [--execute]
  ./lifeos.sh people resolve NAME [--json]
  ./lifeos.sh people list-aliases
  ./lifeos.sh people add-alias NAME EMAIL
  ./lifeos.sh google accounts
  ./lifeos.sh google auth ALIAS [--docs-write] [--docs-comment] [--no-browser]
  ./lifeos.sh gmail sync ALIAS [--qa | --output FILE] [--query GMAIL_SEARCH] [--max-results N]   # overrides need --qa or --output
  ./lifeos.sh gmail sync --all [--qa [--query GMAIL_SEARCH] [--max-results N]]   # continues past a failing account, then reports it
  ./lifeos.sh gmail labels ALIAS [--json]
  ./lifeos.sh gmail list ALIAS (--label NAME_OR_ID | --query GMAIL_SEARCH) [--limit N] [--json]
  ./lifeos.sh gmail archive ALIAS (--message ID | --thread ID | --ids-file FILE)... [--execute]   # remove from Inbox; Inbox mail only
  ./lifeos.sh gmail unarchive ALIAS (--message ID | --thread ID | --ids-file FILE)... [--execute]
  ./lifeos.sh gmail label ALIAS --label NAME_OR_ID (--message ID | --thread ID | --ids-file FILE)... [--skip-inbox] [--execute]   # user labels only
  ./lifeos.sh gmail unlabel ALIAS --label NAME_OR_ID (--message ID | --thread ID | --ids-file FILE)... [--execute]
  ./lifeos.sh gmail create-label ALIAS --name NAME [--execute]
  ./lifeos.sh gmail spam ALIAS [--limit N] [--json]   # list mail Gmail filed as spam; never synced
  ./lifeos.sh gmail not-spam ALIAS (--message ID | --thread ID | --ids-file FILE)... [--execute]   # Spam -> Inbox
  ./lifeos.sh gmail filters ALIAS [--json]
  ./lifeos.sh gmail create-filter ALIAS (--from TEXT | --to TEXT | --subject TEXT | --query GMAIL_SEARCH)... (--label NAME_OR_ID | --skip-inbox)... [--execute]   # label and/or skip inbox only; needs gmail.filters_enabled
  ./lifeos.sh gmail delete-filter ALIAS --filter FILTER_ID [--execute]   # removes the rule only
  ./lifeos.sh drive accounts
  ./lifeos.sh drive search ALIAS QUERY [--json]
  ./lifeos.sh drive list ALIAS FOLDER_ID [--json]
  ./lifeos.sh drive meta ALIAS FILE_URL_OR_ID [--json]
  ./lifeos.sh drive read ALIAS FILE_URL_OR_ID [--range RANGE]
  ./lifeos.sh drive download ALIAS FILE_URL_OR_ID [--out PATH] [--mime EXPORT_MIME] [--force]
  ./lifeos.sh drive sync ALIAS [--folders N] [--recent N] [--recent-days N] [--qa | --output FILE]
  ./lifeos.sh drive import-doc ALIAS SOURCE_FILE --title TITLE [--folder FOLDER_ID] [--execute]
  ./lifeos.sh docs read ALIAS DOC_URL_OR_ID [--tab-id ID]... [--show-links]
  ./lifeos.sh docs replace-once ALIAS DOC_URL_OR_ID (--old TEXT | --old-file FILE) (--new TEXT | --new-file FILE) [--tab-id ID]... [--link "TEXT=URL"]... [--markdown] [--execute]   # --markdown formats the replacement (headings, bullets, bold, links) in place
  ./lifeos.sh docs set-body ALIAS DOC_URL_OR_ID (--file FILE | --new MARKDOWN) [--tab-id ID]... [--execute]   # rewrite the doc body in place from markdown (preserves id/history/links)
  ./lifeos.sh docs comments ALIAS DOC_URL_OR_ID
  ./lifeos.sh docs comment ALIAS DOC_URL_OR_ID [--quote TEXT] (--body TEXT | --body-file FILE) [--tab-id ID]... [--execute]   # add one comment; the quote must occur once
  ./lifeos.sh m365 accounts
  ./lifeos.sh m365 auth ALIAS [--no-browser]
  ./lifeos.sh m365 profile ALIAS [--json]
  ./lifeos.sh m365 mail sync ALIAS [--qa | --output FILE]
  ./lifeos.sh m365 mail folders ALIAS [--json]
  ./lifeos.sh m365 mail list ALIAS --folder NAME_PATH_OR_ID [--limit N] [--json]
  ./lifeos.sh m365 mail archive ALIAS (--message ID | --ids-file FILE)... [--execute]   # Inbox -> Archive
  ./lifeos.sh m365 mail unarchive ALIAS (--message ID | --ids-file FILE)... [--execute]   # Archive -> Inbox
  ./lifeos.sh m365 mail move ALIAS --folder NAME_PATH_OR_ID (--message ID | --ids-file FILE)... [--execute]
  ./lifeos.sh m365 mail create-folder ALIAS --name NAME [--parent NAME_PATH_OR_ID] [--execute]
  ./lifeos.sh m365 mail attachments ALIAS --message ID [--save DIR] [--force]   # list, or save file attachments (read-only)
  ./lifeos.sh m365 mail categorize ALIAS --category NAME (--message ID | --ids-file FILE)... [--execute]   # Outlook category = tag; IDs unchanged
  ./lifeos.sh m365 mail uncategorize ALIAS --category NAME (--message ID | --ids-file FILE)... [--execute]
  ./lifeos.sh m365 mail junk ALIAS [--limit N] [--json]   # list Junk Email; never synced
  ./lifeos.sh m365 mail not-junk ALIAS (--message ID | --ids-file FILE)... [--execute]   # Junk -> Inbox
  ./lifeos.sh m365 mail rules ALIAS [--json]   # Inbox rules
  ./lifeos.sh m365 mail create-rule ALIAS --name NAME (--from ADDRESS | --sender-contains TEXT | --subject-contains TEXT)... (--category NAME | --folder NAME_PATH_OR_ID)... [--stop] [--execute]   # categorize and/or move only; needs mail.rules_enabled
  ./lifeos.sh m365 mail delete-rule ALIAS --rule RULE_ID [--execute]   # removes the rule only
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
  ./lifeos.sh m365 files search ALIAS QUERY [--drive DRIVE_ID] [--json]
  ./lifeos.sh m365 files resolve-link ALIAS URL [--json]
  ./lifeos.sh m365 files meta ALIAS ITEM_ID [--drive DRIVE_ID] [--json]
  ./lifeos.sh m365 files download ALIAS ITEM_ID --out PATH [--drive DRIVE_ID] [--force]
  ./lifeos.sh m365 files upload ALIAS LOCAL_FILE --parent FOLDER_ITEM_ID|root [--drive DRIVE_ID] [--name NAME] [--execute]   # new file only; refuses an existing name
  ./lifeos.sh m365 files replace ALIAS ITEM_ID --file LOCAL_FILE [--drive DRIVE_ID] [--execute]   # eTag-guarded; version history keeps the old copy
  ./lifeos.sh m365 files create-folder ALIAS --parent FOLDER_ITEM_ID|root --name NAME [--drive DRIVE_ID] [--execute]   # no delete, move, rename, or sharing
  ./lifeos.sh m365 planner plans ALIAS [--json]   # plans shared with you; marks the ones configured in planner.plans
  ./lifeos.sh m365 planner buckets ALIAS --plan PLAN_ID [--json]
  ./lifeos.sh m365 planner tasks ALIAS --plan PLAN_ID [--bucket BUCKET_ID] [--mine] [--open] [--json]
  ./lifeos.sh m365 planner task ALIAS --task TASK_ID [--json]   # includes description and checklist
  ./lifeos.sh m365 planner sync ALIAS [--qa | --output FILE]   # snapshot configured plans to sources/m365/<alias>-planner.md
  ./lifeos.sh m365 planner create-task ALIAS --plan PLAN_ID --bucket BUCKET_ID --title TEXT [--due YYYY-MM-DD] [--progress not-started|in-progress|done] [--assign me|EMAIL|USER_ID]... [--desc TEXT | --desc-file FILE] [--execute]
  ./lifeos.sh m365 planner update-task ALIAS --task TASK_ID [--title TEXT] [--bucket BUCKET_ID] [--due YYYY-MM-DD|none] [--progress ...] [--assign WHO]... [--unassign WHO]... [--desc TEXT | --desc-file FILE] [--execute]   # configured plans only; no delete
  ./lifeos.sh odoo accounts
  ./lifeos.sh odoo projects list ALIAS [--json]
  ./lifeos.sh odoo stages list ALIAS --project PROJECT_ID [--json]
  ./lifeos.sh odoo tasks list ALIAS --project PROJECT_ID [--stage STAGE_ID] [--limit COUNT] [--json]
  ./lifeos.sh odoo tasks find ALIAS QUERY --project PROJECT_ID [--json]
  ./lifeos.sh odoo tasks get ALIAS TASK_ID [--json]
  ./lifeos.sh odoo tasks comments ALIAS TASK_ID [--limit COUNT] [--json]
  ./lifeos.sh odoo tasks create ALIAS --project PROJECT_ID --name NAME [--description TEXT | --description-file FILE] [--stage STAGE_ID] [--assignee USER_ID]... [--deadline YYYY-MM-DD] [--execute] [--json]
  ./lifeos.sh odoo tasks update ALIAS TASK_ID [--name NAME] [--description TEXT | --description-file FILE] [--stage STAGE_ID] [--assignee USER_ID]... [--clear-assignees] [--deadline YYYY-MM-DD | --clear-deadline] [--execute] [--json]
  ./lifeos.sh odoo tasks comment ALIAS TASK_ID [--body TEXT | --body-file FILE] [--execute] [--json]
  ./lifeos.sh slack accounts
  ./lifeos.sh slack whoami ALIAS
  ./lifeos.sh slack channels ALIAS [QUERY]
  ./lifeos.sh slack users ALIAS [QUERY]
  ./lifeos.sh slack thread ALIAS (MESSAGE_URL | --channel ID --ts TS)
  ./lifeos.sh slack post ALIAS (--channel ID [--thread-ts TS] | --url MESSAGE_URL) (--text TEXT | --text-file FILE) [--execute]   # as the user; dry-run by default
  ./lifeos.sh slack dm ALIAS --user USER_ID (--text TEXT | --text-file FILE) [--execute]
  ./lifeos.sh slack sync [ALIAS] [--qa | --output DIR]   # snapshot configured Lists into sources/slack/<alias>/list-<name>.md
  ./lifeos.sh slack lists schema ALIAS LIST_ID
  ./lifeos.sh slack lists items ALIAS LIST_ID [--limit N] [--archived]
  ./lifeos.sh slack lists get ALIAS LIST_ID ITEM_ID
  ./lifeos.sh slack lists create ALIAS LIST_ID --field NAME=VALUE... [--parent ITEM_ID] [--execute]
  ./lifeos.sh slack lists update ALIAS LIST_ID ITEM_ID --field NAME=VALUE... [--execute]
  ./lifeos.sh resume render INPUT.md [--output PATH] [--theme CSS] [--open]
  ./lifeos.sh github list-repos
  ./lifeos.sh github sync [ALIAS] [--qa | --output DIR]
  ./lifeos.sh github create-issue --repo ALIAS_OR_OWNER/REPO --title TITLE [--body TEXT | --body-file FILE] [--label NAME]... [--assignee LOGIN]... [--assign-me] [--execute]
  ./lifeos.sh github move-card --repo ALIAS --issue NUMBER --status COLUMN [--execute]
  ./lifeos.sh sync      # Trello, Calendar, GitHub, Slack Lists, and Microsoft 365 Planner; each skipped with a warning when not configured

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
    local issues=0 vault sources file google_accounts google_aliases google_alias google_token m365_accounts m365_aliases m365_alias m365_provider m365_token pwsh odoo_accounts odoo_aliases odoo_alias odoo_key_env odoo_key_value slack_accounts slack_alias slack_token_env slack_token_value

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
            m365_aliases="$(jq -r '(.accounts // [])[] | select((.mail.enabled // false) == true or (.calendar.enabled // false) == true or (.contacts.enabled // false) == true) | .alias' "$m365_accounts")"
            for m365_alias in $m365_aliases; do
                m365_provider="$(_m365_auth_provider "$m365_alias")" || m365_provider=""
                case "$m365_provider" in
                    graph-powershell)
                        pwsh="$(_m365_powershell_bin)"
                        if command -v "$pwsh" >/dev/null 2>&1 && "$pwsh" -NoLogo -NoProfile -Command 'if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) { exit 1 }' >/dev/null 2>&1; then
                            _say "OK: Microsoft Graph PowerShell provider is ready for alias '$m365_alias'"
                        else
                            _say "MISSING: PowerShell or Microsoft.Graph.Authentication for alias '$m365_alias'"
                            _say "NEXT: install PowerShell, then run 'Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'"
                            issues=$((issues + 1))
                        fi
                        ;;
                    msal)
                        if "$LIFEOS_PY" -c 'import msal' >/dev/null 2>&1; then
                            _say "OK: MSAL is installed for alias '$m365_alias'"
                        else
                            _say "MISSING: MSAL Python dependency for alias '$m365_alias'"
                            _say "NEXT: run './lifeos.sh setup'"
                            issues=$((issues + 1))
                        fi
                        m365_token="$(_m365_account_path "$m365_alias" '.token_path')" || m365_token=""
                        if [ -n "$m365_token" ] && [ -f "$m365_token" ]; then
                            _say "OK: Microsoft token cache exists for alias '$m365_alias'"
                        else
                            _say "MISSING: Microsoft token cache for alias '$m365_alias'"
                            _say "NEXT: run './lifeos.sh m365 auth $m365_alias'"
                        fi
                        ;;
                    *)
                        _say "MISSING: supported Microsoft auth_provider for alias '$m365_alias'"
                        issues=$((issues + 1))
                        ;;
                esac
            done
        else
            _say "MISSING: Microsoft 365 account alias config is not valid JSON shape"
            issues=$((issues + 1))
        fi
    else
        _say "OPTIONAL: Microsoft 365 account alias config is not set up"
        _say "NEXT: cp ${SECRETS_DIR}/m365-accounts.example.json $m365_accounts"
    fi

    odoo_accounts="$(_odoo_accounts_path)"
    if [ -f "$odoo_accounts" ]; then
        if jq -e '.accounts | type == "array"' "$odoo_accounts" >/dev/null 2>&1; then
            _say "OK: Odoo account alias config exists"
            odoo_aliases="$(jq -r '(.accounts // [])[] | .alias' "$odoo_accounts")"
            for odoo_alias in $odoo_aliases; do
                odoo_key_env="$(_odoo_account_value "$odoo_alias" '.api_key_env')" || odoo_key_env=""
                case "$odoo_key_env" in
                    ''|*[!A-Za-z0-9_]*)
                        _say "MISSING: valid Odoo api_key_env for alias '$odoo_alias'"
                        issues=$((issues + 1))
                        ;;
                    *)
                        eval "odoo_key_value=\${${odoo_key_env}:-}"
                        if [ -n "$odoo_key_value" ]; then
                            _say "OK: Odoo API key is set for alias '$odoo_alias' (redacted)"
                        else
                            _say "MISSING: $odoo_key_env for Odoo alias '$odoo_alias'"
                            issues=$((issues + 1))
                        fi
                        ;;
                esac
            done
        else
            _say "MISSING: Odoo account alias config is not valid JSON shape"
            issues=$((issues + 1))
        fi
    else
        _say "OPTIONAL: Odoo account alias config is not set up"
        _say "NEXT: cp ${SECRETS_DIR}/odoo-accounts.example.json $odoo_accounts"
    fi

    slack_accounts="${SLACK_ACCOUNTS_PATH:-${SECRETS_DIR}/slack-accounts.json}"
    if [ -f "$slack_accounts" ]; then
        if jq -e '.accounts | type == "array"' "$slack_accounts" >/dev/null 2>&1; then
            _say "OK: Slack account alias config exists"
            while IFS=$'\t' read -r slack_alias slack_token_env; do
                [ -n "$slack_alias" ] || continue
                case "$slack_token_env" in
                    ''|*[!A-Za-z0-9_]*)
                        _say "MISSING: valid Slack token_env for alias '$slack_alias'"
                        issues=$((issues + 1))
                        ;;
                    *)
                        eval "slack_token_value=\${${slack_token_env}:-}"
                        if [ -n "$slack_token_value" ]; then
                            _say "OK: Slack token is set for alias '$slack_alias' (redacted; run 'lifeos slack whoami $slack_alias' to verify identity)"
                        else
                            _say "MISSING: $slack_token_env for Slack alias '$slack_alias'"
                            issues=$((issues + 1))
                        fi
                        ;;
                esac
            done <<EOF_SLACK
$(jq -r '(.accounts // [])[] | [(.alias // ""), (.token_env // "")] | @tsv' "$slack_accounts")
EOF_SLACK
        else
            _say "MISSING: Slack account alias config is not valid JSON shape"
            issues=$((issues + 1))
        fi
    else
        _say "OPTIONAL: Slack account alias config is not set up"
        _say "NEXT: cp ${SECRETS_DIR}/slack-accounts.example.json $slack_accounts"
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
$vault/sources/github/open-austin-org/issues.md
$vault/sources/github/open-austin-org/board-org-kanban.md
$vault/sources/slack/open-austin/list-org.md

Then add the relevant focus-thread file, such as:

$vault/open-austin/index.open-austin.md
EOF
}

# Sync every configured M365 account that has calendar enabled. Google-only setups
# skip silently; a missing/!ready M365 config is a warning, not a failure.
# `lifeos calendar sync` means "refresh my calendar", and UT meetings live in M365.
# Syncing only Google silently hides every Teams meeting, so fan out by default.
# --google-only restores the old behaviour; --qa/--output stay Google-scoped since
# the M365 renderer writes its own per-account file.
_calendar_sync_combined() {
    local status=0 google_only=0 passthrough=() scoped=0
    for arg in "$@"; do
        case "$arg" in
            --google-only) google_only=1 ;;
            --qa|--output) scoped=1; passthrough+=("$arg") ;;
            *) passthrough+=("$arg") ;;
        esac
    done
    # Microsoft 365 calendars are merged into the one agenda inside _calendar_sync; the separate per-alias M365 calendar snapshot is no longer written here (`lifeos m365 calendar sync` still writes it on request).
    if [ "$google_only" -eq 1 ]; then
        LIFEOS_CALENDAR_GOOGLE_ONLY=1 _calendar_sync "${passthrough[@]}" || status=$?
    else
        _calendar_sync "${passthrough[@]}" || status=$?
    fi
    : "$scoped"
    return "$status"
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

    if [ -f "$(_github_repos_config)" ]; then
        _github_sync || status=$?
    else
        _warn "Skipping GitHub sync: no $(_github_repos_config)."
    fi

    if [ -f "${SLACK_ACCOUNTS_PATH:-${SECRETS_DIR}/slack-accounts.json}" ] && jq -e '[.accounts[]?.lists[]?] | length > 0' "${SLACK_ACCOUNTS_PATH:-${SECRETS_DIR}/slack-accounts.json}" >/dev/null 2>&1; then
        _slack_sync || status=$?
    else
        _warn "Skipping Slack Lists sync: no Slack account names any lists."
    fi

    # Planner joins the aggregate sync per alias (planner.sync, default true) once plans are configured; see docs/decisions/0008-lifeos-m365-planner.md.
    local planner_alias planner_aliases=""
    if [ -f "$(_m365_accounts_path)" ]; then
        planner_aliases="$(jq -r '(.accounts // [])[] | select((.planner.enabled // false) == true and (.planner.sync // true) == true and ((.planner.plans // []) | length) > 0) | .alias' "$(_m365_accounts_path)" 2>/dev/null)"
    fi
    if [ -n "$planner_aliases" ]; then
        while IFS= read -r planner_alias || [ -n "$planner_alias" ]; do
            [ -n "$planner_alias" ] && { _m365_planner_sync "$planner_alias" || status=$?; }
        done <<EOF
$planner_aliases
EOF
    else
        _warn "Skipping Microsoft 365 Planner sync: no account has planner enabled with configured plans."
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
            list-labels) shift 2; _trello_list_labels "$@" ;;
            sync) shift 2; _trello_sync "$@" ;;
            add-card) shift 2; _trello_add_card "$@" ;;
            move-card) shift 2; _trello_move_card "$@" ;;
            snooze) shift 2; _trello_snooze "$@" ;;
            rename-card) shift 2; _trello_rename_card "$@" ;;
            set-desc) shift 2; _trello_set_desc "$@" ;;
            comment) shift 2; _trello_comment "$@" ;;
            create-label) shift 2; _trello_create_label "$@" ;;
            add-label) shift 2; _trello_add_label "$@" ;;
            remove-label) shift 2; _trello_remove_label "$@" ;;
            delete-label) shift 2; _trello_delete_label "$@" ;;
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
            sync)
                shift 2
                _calendar_sync_combined "$@"
                ;;
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
            labels) shift 2; _gmail_labels "$@" ;;
            list) shift 2; _gmail_list "$@" ;;
            archive) shift 2; _gmail_archive "$@" ;;
            unarchive) shift 2; _gmail_unarchive "$@" ;;
            label) shift 2; _gmail_label "$@" ;;
            unlabel) shift 2; _gmail_unlabel "$@" ;;
            create-label) shift 2; _gmail_create_label "$@" ;;
            spam) shift 2; _gmail_spam "$@" ;;
            not-spam) shift 2; _gmail_not_spam "$@" ;;
            filters) shift 2; _gmail_filters "$@" ;;
            create-filter) shift 2; _gmail_create_filter "$@" ;;
            delete-filter) shift 2; _gmail_delete_filter "$@" ;;
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
            download) shift 2; _drive_download "$@" ;;
            sync) shift 2; _drive_sync "$@" ;;
            import-doc) shift 2; _drive_import_doc "$@" ;;
            *) _err "Unknown Drive command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    docs)
        case "${2:-}" in
            read) shift 2; _docs_run read "$@" ;;
            replace-once) shift 2; _docs_run replace-once "$@" ;;
            set-body) shift 2; _docs_run set-body "$@" ;;
            comments) shift 2; _docs_run comments "$@" ;;
            comment) shift 2; _docs_run comment "$@" ;;
            *) _err "Unknown Docs command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    m365)
        shift
        _m365_dispatch "$@"
        ;;
    odoo)
        shift
        _odoo_dispatch "$@"
        ;;
    slack)
        shift
        _slack_dispatch "$@"
        ;;
    resume)
        case "${2:-}" in
            render) shift 2; _resume_render "$@" ;;
            *) _err "Unknown Resume command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    github)
        case "${2:-}" in
            list-repos) shift 2; _github_list_repos "$@" ;;
            sync) shift 2; _github_sync "$@" ;;
            create-issue) shift 2; _github_create_issue "$@" ;;
            move-card) shift 2; _github_move_card "$@" ;;
            *) _err "Unknown GitHub command: ${2:-}"; _usage; exit 1 ;;
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
