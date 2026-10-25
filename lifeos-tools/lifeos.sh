#!/usr/bin/env bash
##- LifeOS helper CLI
##- Compatibility service commands; workflow selection belongs to the calling workspace.

# Retired orchestration must fail before loading modules, credentials, or configuration. Keep this diagnostic for old callers rather than silently doing a narrower refresh.
case "${1:-}:${2:-}" in
    sync:*|calendar:sync)
        printf '%s\n' 'ERROR: Combined calendar sync and aggregate sync are retired; no sources were refreshed.' >&2
        printf '%s\n' 'For LifeOS, enter its current instructions through operate-lifeos and follow its private refresh procedures.' >&2
        printf '%s\n' 'For other callers, select individual service exports explicitly. Combine calendar export-data bundles with the render-calendar-agenda skill.' >&2
        exit 2
        ;;
    people:list-aliases|people:add-alias)
        printf '%s\n' 'ERROR: Private nickname storage is retired from this CLI. Resolve names in the consuming workspace and pass full attendee emails.' >&2
        exit 2
        ;;
    setup:*|doctor:*)
        printf '%s\n' 'ERROR: Shared setup/doctor is retired. Use setup-agent-hands and the selected service setup/authorization skill for configuration and checks.' >&2
        exit 2
        ;;
    open:*|context:*)
        printf '%s\n' 'ERROR: Workspace routing belongs to operate-lifeos and the private workspace entrypoint; this service CLI no longer loads a vault path.' >&2
        exit 2
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="${CONFIGS:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
LIB_DIR="${SCRIPT_DIR}/lib"


# Shared helpers live in lib/. common.sh must load first — the feature modules use its functions.
. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/trello.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"
. "${LIB_DIR}/m365-planner.sh"
. "${LIB_DIR}/m365-files.sh"
. "${LIB_DIR}/m365-excel.sh"
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
  ./lifeos.sh trello list-boards
  ./lifeos.sh trello list-lists [board_id]
  ./lifeos.sh trello list-labels [board_id]
  ./lifeos.sh trello sync --output FILE
  ./lifeos.sh trello add-card --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello move-card --card CARD_ID_OR_URL --list LIST [--board BOARD_ID]
  ./lifeos.sh trello snooze --card CARD_ID_OR_URL --until YYYY-MM-DD --list LIST [--board BOARD_ID]
  ./lifeos.sh trello rename-card --card CARD_ID_OR_URL --name NAME
  ./lifeos.sh trello set-desc --card CARD_ID_OR_URL --file FILE
  ./lifeos.sh trello comment --card CARD_ID_OR_URL (--text TEXT | --file FILE)
  ./lifeos.sh trello add-checklist --card CARD_ID_OR_URL --name NAME [--item TEXT]...
  ./lifeos.sh trello add-checklist-item --card CARD_ID_OR_URL --checklist NAME_OR_ID --text TEXT [--text TEXT]...
  ./lifeos.sh trello check-item --card CARD_ID_OR_URL --item NAME_OR_ID [--checklist NAME_OR_ID]
  ./lifeos.sh trello uncheck-item --card CARD_ID_OR_URL --item NAME_OR_ID [--checklist NAME_OR_ID]
  ./lifeos.sh trello create-label --name NAME [--color COLOR] [--board BOARD_ID]
  ./lifeos.sh trello add-label --card CARD_ID_OR_URL --label LABEL_ID_OR_NAME [--board BOARD_ID]
  ./lifeos.sh trello remove-label --card CARD_ID_OR_URL --label LABEL_ID_OR_NAME [--board BOARD_ID]
  ./lifeos.sh trello delete-label --label LABEL_ID_OR_NAME [--board BOARD_ID]
  ./lifeos.sh trello supersede --from CARD_ID_OR_URL --to CARD_ID_OR_URL [--board BOARD_ID]
  ./lifeos.sh trello supersede --create --from CARD_ID_OR_URL --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello chain --card CARD_ID_OR_URL [--json]
  ./lifeos.sh calendar auth ALIAS
  ./lifeos.sh calendar list-calendars ALIAS
  ./lifeos.sh calendar find ALIAS QUERY [--calendar CALENDAR_ID] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--json]
  ./lifeos.sh calendar export-data ALIAS --from INSTANT --to INSTANT --output FILE [--calendar ID]
  # calendar sync is retired: use explicit export-data bundles and render-calendar-agenda
  ./lifeos.sh calendar create-event ALIAS --title TITLE --start DATE_OR_DATETIME [--end ...] [--calendar CALENDAR_ID] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee EMAIL]... [--recurrence RRULE]... [--transparency transparent|opaque] [--popup-minutes 0..40320] [--notify] [--execute]
  ./lifeos.sh calendar update-event ALIAS --event EVENT_ID [--series | --instance] [--calendar CALENDAR_ID] [--title TEXT] [--start ...] [--end ...] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee EMAIL]... [--replace-attendees] [--recurrence RRULE]... [--transparency transparent|opaque] [--popup-minutes 0..40320] [--notify] [--execute]
  ./lifeos.sh people resolve ALIAS NAME
  ./lifeos.sh google accounts
  ./lifeos.sh google auth ALIAS [--docs-write] [--docs-comment] [--no-browser]
  ./lifeos.sh gmail sync ALIAS --output FILE [--query GMAIL_SEARCH] [--max-results N]
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
  ./lifeos.sh drive sync ALIAS [--folders N] [--recent N] [--recent-days N] [--exclude-folder NAME]... --output FILE
  ./lifeos.sh drive import-doc ALIAS SOURCE_FILE --title TITLE [--folder FOLDER_ID] [--execute]
  ./lifeos.sh docs read ALIAS DOC_URL_OR_ID [--tab-id ID]... [--show-links]
  ./lifeos.sh docs replace-once ALIAS DOC_URL_OR_ID (--old TEXT | --old-file FILE) (--new TEXT | --new-file FILE) [--tab-id ID]... [--link "TEXT=URL"]... [--markdown] [--execute]   # --markdown formats the replacement (headings, bullets, bold, links) in place
  ./lifeos.sh docs set-body ALIAS DOC_URL_OR_ID (--file FILE | --new MARKDOWN) [--tab-id ID]... [--execute]   # rewrite the doc body in place from markdown (preserves id/history/links)
  ./lifeos.sh docs comments ALIAS DOC_URL_OR_ID
  ./lifeos.sh docs comment ALIAS DOC_URL_OR_ID [--quote TEXT] (--body TEXT | --body-file FILE) [--tab-id ID]... [--execute]   # add one comment; the quote must occur once
  ./lifeos.sh m365 accounts
  ./lifeos.sh m365 auth ALIAS [--no-browser]
  ./lifeos.sh m365 profile ALIAS [--json]
  ./lifeos.sh m365 mail sync ALIAS --output FILE
  ./lifeos.sh m365 mail folders ALIAS [--json]
  ./lifeos.sh m365 mail list ALIAS (--folder NAME_PATH_OR_ID | --search KQL)... [--limit N] [--json]   # metadata and web link; a search without --folder skips Junk Email
  ./lifeos.sh m365 mail read ALIAS --message ID [--full] [--json]   # one message from any folder: recipients, text body, attachment names
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
  ./lifeos.sh m365 mail create-rule ALIAS --name NAME (--from ADDRESS | --sender-contains TEXT | --subject-contains TEXT | --recipient-contains TEXT)... (--category NAME | --folder NAME_PATH_OR_ID | --delete)... [--stop] [--execute]   # --delete requires full --from and recipient addresses; needs mail.rules_enabled
  ./lifeos.sh m365 mail delete-rule ALIAS --rule RULE_ID [--execute]   # removes the rule only
  ./lifeos.sh m365 calendar list-calendars ALIAS
  ./lifeos.sh m365 calendar find ALIAS QUERY [--calendar ID] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--json]
  ./lifeos.sh m365 calendar export-data ALIAS --from INSTANT --to INSTANT --output FILE [--calendar ID]
  ./lifeos.sh m365 calendar sync ALIAS --output FILE
  ./lifeos.sh m365 calendar create-event ALIAS --title TITLE --start DATE_OR_DATETIME [--end ...] [--calendar ID] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee EMAIL]... [--notify] [--execute]
  ./lifeos.sh m365 calendar update-event ALIAS --event ID [--calendar ID] [--title TEXT] [--start ...] [--end ...] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee EMAIL]... [--replace-attendees] [--notify] [--execute]
  ./lifeos.sh m365 contacts list ALIAS [--json]
  ./lifeos.sh m365 contacts find ALIAS QUERY [--json]
  ./lifeos.sh m365 contacts sync ALIAS --output FILE
  ./lifeos.sh m365 contacts create ALIAS [--display-name TEXT] [--given-name TEXT] [--surname TEXT] [--email ADDRESS]... [--phone NUMBER]... [--mobile NUMBER] [--company TEXT] [--job-title TEXT] [--notes TEXT | --notes-file FILE] [--execute]
  ./lifeos.sh m365 contacts update ALIAS --contact ID [contact fields...] [--execute]
  ./lifeos.sh m365 files search ALIAS QUERY [--drive DRIVE_ID] [--json]
  ./lifeos.sh m365 files resolve-link ALIAS URL [--json]
  ./lifeos.sh m365 files meta ALIAS ITEM_ID [--drive DRIVE_ID] [--json]
  ./lifeos.sh m365 files download ALIAS ITEM_ID --out PATH [--drive DRIVE_ID] [--force]
  ./lifeos.sh m365 files upload ALIAS LOCAL_FILE --parent FOLDER_ITEM_ID|root [--drive DRIVE_ID] [--name NAME] [--execute]   # new file only; refuses an existing name
  ./lifeos.sh m365 files replace ALIAS ITEM_ID --file LOCAL_FILE [--drive DRIVE_ID] [--execute]   # eTag-guarded; version history keeps the old copy
  ./lifeos.sh m365 files create-folder ALIAS --parent FOLDER_ITEM_ID|root --name NAME [--drive DRIVE_ID] [--execute]   # no delete, move, rename, or sharing
  ./lifeos.sh m365 excel help   # bounded workbook reads and guarded cell/table/format writes; no whole-file replacement
  ./lifeos.sh m365 planner plans ALIAS [--json]   # plans shared with you; marks the ones configured in planner.plans
  ./lifeos.sh m365 planner comments ALIAS --task TASK_ID [--json]   # group-backed allowlisted task; existing group permissions required
  ./lifeos.sh m365 planner comment ALIAS --task TASK_ID --file PATH [--execute]   # deduplicated group post; may trigger group notifications
  ./lifeos.sh m365 planner labels ALIAS --plan PLAN_ID [--json]   # existing named labels
  ./lifeos.sh m365 planner label ALIAS --task TASK_ID --label NAME [--execute]   # add an existing label; preserve others
  ./lifeos.sh m365 planner unlabel ALIAS --task TASK_ID --label NAME [--execute]
  ./lifeos.sh m365 planner buckets ALIAS --plan PLAN_ID [--json]
  ./lifeos.sh m365 planner tasks ALIAS --plan PLAN_ID [--bucket BUCKET_ID] [--mine] [--open] [--json]
  ./lifeos.sh m365 planner task ALIAS --task TASK_ID [--json]   # includes description and checklist
  ./lifeos.sh m365 planner sync ALIAS --output FILE   # export configured plans to the requested file
  ./lifeos.sh m365 planner create-task ALIAS --plan PLAN_ID --bucket BUCKET_ID --title TEXT [--due YYYY-MM-DD] [--progress not-started|in-progress|done] [--assign me|EMAIL|USER_ID]... [--desc TEXT | --desc-file FILE] [--execute]
  ./lifeos.sh m365 planner update-task ALIAS --task TASK_ID [--title TEXT] [--bucket BUCKET_ID] [--due YYYY-MM-DD|none] [--progress ...] [--assign WHO]... [--unassign WHO]... [--desc TEXT | --desc-file FILE] [--execute]   # configured plans only; no delete
  ./lifeos.sh m365 planner move-task ALIAS --task TASK_ID --plan PLAN_ID --bucket BUCKET_ID [--execute]   # experimental beta; same group, both plans configured
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
  ./lifeos.sh slack conversations ALIAS [--types public_channel,private_channel,im,mpim] [--user USER_ID] [--archived]
  ./lifeos.sh slack history ALIAS --channel ID [--limit 1..100] [--cursor CURSOR] [--oldest TS] [--latest TS] [--inclusive]
  ./lifeos.sh slack search ALIAS QUERY [--limit 1..100] [--page 1..100]
  ./lifeos.sh slack permalink ALIAS --channel ID --ts TS
  ./lifeos.sh slack users ALIAS [QUERY]
  ./lifeos.sh slack thread ALIAS (MESSAGE_URL | --channel ID --ts TS)
  ./lifeos.sh slack post ALIAS (--channel ID [--thread-ts TS] | --url MESSAGE_URL) (--text TEXT | --text-file FILE) [--execute]   # as the user; dry-run by default
  ./lifeos.sh slack dm ALIAS --user USER_ID (--text TEXT | --text-file FILE) [--execute]
  ./lifeos.sh slack sync [ALIAS] --output DIR   # export configured Lists to <DIR>/<alias>/list-<name>.md
  ./lifeos.sh slack lists schema ALIAS LIST_ID
  ./lifeos.sh slack lists items ALIAS LIST_ID [--limit N] [--archived]
  ./lifeos.sh slack lists get ALIAS LIST_ID ITEM_ID
  ./lifeos.sh slack lists comments ALIAS LIST_ID ITEM_ID [--channel ID | --url COMMENT_URL]
  ./lifeos.sh slack lists comment ALIAS LIST_ID ITEM_ID [--channel ID | --url COMMENT_URL] (--text TEXT | --text-file FILE) [--execute]
  ./lifeos.sh slack lists create ALIAS LIST_ID --field NAME=VALUE... [--parent ITEM_ID] [--execute]
  ./lifeos.sh slack lists update ALIAS LIST_ID ITEM_ID --field NAME=VALUE... [--execute]
  ./lifeos.sh resume render INPUT.md [--output PATH] [--theme CSS] [--asset-dir DIR] [--open]
  ./lifeos.sh github list-repos
  ./lifeos.sh github sync [ALIAS] [--all] --output DIR
  ./lifeos.sh github create-issue --repo ALIAS_OR_OWNER/REPO --title TITLE [--body TEXT | --body-file FILE] [--label NAME]... [--assignee LOGIN]... [--assign-me] [--execute]
  ./lifeos.sh github move-card --repo ALIAS --issue NUMBER --status COLUMN [--execute]
  # aggregate sync is retired: the calling workspace selects individual service exports

Real config lives in .env, copied from .env.example.
EOF
}

# Migrated providers load only their own literal configuration, never the legacy shared env.
case "${1:-help}" in
    trello) _trello_load_env || exit 1 ;;
    odoo) _odoo_load_env || exit 1 ;;
    github) _github_load_env || exit 1 ;;
    m365) _m365_load_env || exit 1 ;;
    google|calendar|gmail|drive|docs|people) _google_load_env || exit 1 ;;
    slack|help|-h|--help) ;;
    *) ;;
esac

case "${1:-help}" in
    help|-h|--help)
        _usage
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
            add-checklist) shift 2; _trello_add_checklist "$@" ;;
            add-checklist-item) shift 2; _trello_add_checklist_item "$@" ;;
            check-item) shift 2; _trello_check_item "$@" ;;
            uncheck-item) shift 2; _trello_uncheck_item "$@" ;;
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
        command="${2:-}"; shift 2
        if [ "$command" = auth ]; then _google_auth "$@"
        else bash "${GOOGLE_CALENDAR_DIR}/scripts/calendar" "$command" "$@"
        fi
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
    *)
        _err "Unknown command: $1"
        _usage
        exit 1
        ;;
esac
