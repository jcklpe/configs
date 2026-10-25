#!/usr/bin/env bash
##- Legacy callers must choose private policy explicitly; all transport is stubbed.
set -eu
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-explicit-choices.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SCRIPT_DIR="$TOOL_DIR"; LIB_DIR="$TOOL_DIR/lib"; SECRETS_DIR="$WORK"; ENV_FILE="$WORK/.env"; QA_DIR="$WORK"
. "$LIB_DIR/common.sh"
. "$LIB_DIR/google.sh"
. "$LIB_DIR/trello.sh"
expect_failure() { if "$@" > "$WORK/out" 2> "$WORK/err"; then echo 'unexpected success'; exit 1; fi; }
_google_account_value() { printf '%s' "${EXCLUSION_TYPE:-null}"; }
_drive_export_index() { printf '%s\n' "$@" > "$WORK/export-args"; }
expect_failure _drive_sync example --output "$WORK/index.md"
[ ! -e "$WORK/export-args" ]
grep -F 'implicit exclusions are retired' "$WORK/err" >/dev/null
_drive_sync example --recent 0 --exclude-folder 'Private Folder' --exclude-folder 'Second Folder' --output "$WORK/index.md"
grep -Fx 'Private Folder' "$WORK/export-args" >/dev/null
grep -Fx 'Second Folder' "$WORK/export-args" >/dev/null
EXCLUSION_TYPE=array _drive_sync example --output "$WORK/index.md"
rm "$WORK/export-args"
_google_account_value() { return 1; }
expect_failure _drive_sync example --output "$WORK/index.md"
[ ! -e "$WORK/export-args" ]

unset TRELLO_SNOOZE_DEFAULT_LIST TRELLO_SNOOZE_LISTS
_trello_write_ready() { return 0; }
_trello_resolve_list_id() { printf '%s\n' "$2" > "$WORK/chosen-list"; printf '%s' synthetic-list; }
_trello_write() { printf '%s\n' "$@" > "$WORK/write-args"; printf '%s' '{"id":"card-one","name":"Example"}'; }
expect_failure _trello_snooze --card card-one --until 2026-10-30
[ ! -e "$WORK/write-args" ]
grep -F 'requires --list' "$WORK/err" >/dev/null
_trello_snooze --card card-one --until 2026-10-30 --list 'Caller List' > /dev/null
[ "$(cat "$WORK/chosen-list")" = 'Caller List' ]
grep -F 'start=2026-10-30T12:00:00.000Z' "$WORK/write-args" >/dev/null
TRELLO_SNOOZE_DEFAULT_LIST='Configured List' _trello_snooze --card card-one --until 2026-10-30 > /dev/null
[ "$(cat "$WORK/chosen-list")" = 'Configured List' ]
[ -z "$(_trello_snooze_lists)" ]
[ "$(TRELLO_SNOOZE_LISTS='Caller List' _trello_snooze_lists)" = 'Caller List' ]
printf '%s\n' 'PASS: explicit legacy exclusions, scheduling lists, and warning lists'
