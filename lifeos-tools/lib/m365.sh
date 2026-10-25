#!/usr/bin/env bash
##- Compatibility commands; provider configuration and capability runtimes own service mechanics.
source "${LIB_DIR}/../../agent-hands/skills/authorize-microsoft/scripts/client.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-mail/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-calendar/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-microsoft-files/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-contacts/scripts/operations.sh"

# These spellings preserve callers, not implicit destinations or directory-index rewrites.
_m365_mail_sync() { _m365_mail_export "$@"; }
_m365_calendar_sync() { _m365_calendar_export "$@"; }
_m365_contacts_sync() { _m365_contacts_export "$@"; }

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
