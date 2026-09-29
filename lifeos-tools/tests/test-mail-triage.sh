#!/usr/bin/env bash
##- Test Microsoft 365 mail moves and Gmail label changes offline: folder-tree resolution, refused targets, dry-run gates, write opt-in, readback, and the audit log. Graph and Gmail calls are stubbed; no real mail is involved.

set -eu

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
CONFIGS="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
SECRETS_DIR="${SCRIPT_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"
QA_DIR="${SCRIPT_DIR}/qa"
LIFEOS_DAYS_BACK=14
LIFEOS_DAYS_AHEAD=30

. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-mail-triage-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
LIFEOS_MAIL_AUDIT_LOG="${WORK}/audit.jsonl"
export LIFEOS_MAIL_AUDIT_LOG

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { if "$@" > "${WORK}/out.txt" 2> "${WORK}/err.txt"; then fail "expected failure: $*"; fi; }

##- Microsoft 365
jq '(.accounts[] | select(.alias == "ut") | .mail.write_enabled) = false' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/m365-read.json"
jq '(.accounts[] | select(.alias == "ut") | .mail.write_enabled) = true' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/m365-write.json"
M365_ACCOUNTS_PATH="${WORK}/m365-read.json"
export M365_ACCOUNTS_PATH

_m365_scopes ut | grep -x 'Mail.Read' >/dev/null || fail "read-only alias should request Mail.Read"
M365_ACCOUNTS_PATH="${WORK}/m365-write.json" _m365_scopes ut | grep -x 'Mail.ReadWrite' >/dev/null || fail "write-enabled alias should request Mail.ReadWrite"
M365_ACCOUNTS_PATH="${WORK}/m365-write.json" _m365_scopes ut | grep -x 'Mail.Read' >/dev/null && fail "write-enabled alias should not also request Mail.Read"

# Synthetic mailbox: Inbox/Receipts, Archive/Old, Deleted Items/Old. msg-inbox sits in the Inbox, msg-archived in the Archive.
_m365_get_paginated() {
    case "$4" in
        */me/mailFolders) printf '%s\n' '{"value":[
          {"id":"f-inbox","displayName":"Inbox","parentFolderId":"root","childFolderCount":1,"totalItemCount":2,"unreadItemCount":1},
          {"id":"f-archive","displayName":"Archive","parentFolderId":"root","childFolderCount":1,"totalItemCount":1,"unreadItemCount":0},
          {"id":"f-deleted","displayName":"Deleted Items","parentFolderId":"root","childFolderCount":1,"totalItemCount":0,"unreadItemCount":0},
          {"id":"f-sent","displayName":"Sent Items","parentFolderId":"root","childFolderCount":0,"totalItemCount":0,"unreadItemCount":0}]}' > "$3" ;;
        *) return 1 ;;
    esac
}

_m365_write() {
    printf '%s %s\n' "$1" "$3" >> "${WORK}/m365-calls.log"
    printf '%s\n' "$4" >> "${WORK}/m365-bodies.log"
    printf '%s' "$4" | jq -c '{responses: [.requests[] | . as $r | {id: .id} + (
      if (.url | test("^/me/mailFolders/f-inbox/childFolders")) then {status: 200, body: {value: [{id: "f-receipts", displayName: "Receipts", parentFolderId: "f-inbox", childFolderCount: 0, totalItemCount: 0, unreadItemCount: 0}]}}
      elif (.url | test("^/me/mailFolders/f-archive/childFolders")) then {status: 200, body: {value: [{id: "f-archive-old", displayName: "Old", parentFolderId: "f-archive", childFolderCount: 0, totalItemCount: 0, unreadItemCount: 0}]}}
      elif (.url | test("^/me/mailFolders/f-deleted/childFolders")) then {status: 200, body: {value: [{id: "f-deleted-old", displayName: "Old", parentFolderId: "f-deleted", childFolderCount: 0, totalItemCount: 0, unreadItemCount: 0}]}}
      elif (.url | test("^/me/mailFolders/inbox[?]")) then {status: 200, body: {id: "f-inbox"}}
      elif (.url | test("^/me/mailFolders/archive[?]")) then {status: 200, body: {id: "f-archive"}}
      elif (.url | test("^/me/mailFolders/deleteditems[?]")) then {status: 200, body: {id: "f-deleted"}}
      elif (.url | test("^/me/mailFolders/sentitems[?]")) then {status: 200, body: {id: "f-sent"}}
      elif (.url | test("^/me/mailFolders/")) then {status: 404, body: {error: {code: "ErrorFolderNotFound"}}}
      elif (.url | test("^/me/messages/msg-inbox[?]")) then {status: 200, body: {id: "msg-inbox", subject: "Newsletter", from: {emailAddress: {address: "news@example.com"}}, receivedDateTime: "2026-09-01T00:00:00Z", parentFolderId: "f-inbox"}}
      elif (.url | test("^/me/messages/msg-archived[?]")) then {status: 200, body: {id: "msg-archived", subject: "Old notice", from: {emailAddress: {address: "notice@example.com"}}, receivedDateTime: "2026-08-01T00:00:00Z", parentFolderId: "f-archive"}}
      elif (.method == "POST" and (.url | test("/move$"))) then {status: 201, body: {id: ("new-" + (.url | capture("/me/messages/(?<m>[^/]+)/move").m)), parentFolderId: .body.destinationId}}
      elif (.url | test("^/me/messages/new-")) then {status: 200, body: {id: (.url | capture("/me/messages/(?<m>[^?]+)").m), parentFolderId: "f-archive"}}
      else {status: 404, body: {error: {code: "ErrorItemNotFound", message: "not found"}}} end)]}'
}

TREE="${WORK}/tree.json"
_m365_mail_folder_tree ut "$TREE"
jq -e 'map(.path) == ["Archive", "Archive/Old", "Deleted Items", "Deleted Items/Old", "Inbox", "Inbox/Receipts", "Sent Items"]' "$TREE" >/dev/null || fail "folder tree paths"
jq -e 'map({key: .path, value: .moveTarget}) | from_entries | .["Deleted Items"] == false and .["Deleted Items/Old"] == false and .["Sent Items"] == false and .["Inbox/Receipts"] == true and .Archive == true' "$TREE" >/dev/null || fail "blocked move targets"
jq -e '.[] | select(.path == "Archive") | .wellKnown == "archive"' "$TREE" >/dev/null || fail "well-known annotation"

[ "$(_m365_mail_resolve_folder "$TREE" receipts | jq -r .id)" = "f-receipts" ] || fail "resolve by unique display name"
[ "$(_m365_mail_resolve_folder "$TREE" "archive/old" | jq -r .id)" = "f-archive-old" ] || fail "resolve by path"
[ "$(_m365_mail_resolve_folder "$TREE" ARCHIVE | jq -r .id)" = "f-archive" ] || fail "resolve by well-known name"
expect_fail _m365_mail_resolve_folder "$TREE" old
grep -F "more than one folder" "${WORK}/err.txt" >/dev/null || fail "ambiguous name should fail"
expect_fail _m365_mail_resolve_folder "$TREE" "Nope"
grep -F "No mail folder matches" "${WORK}/err.txt" >/dev/null || fail "missing folder should fail"

_m365_mail_folders ut > "${WORK}/folders.txt"
grep -F -- "  - Receipts | path: Inbox/Receipts" "${WORK}/folders.txt" >/dev/null || fail "folders output nests children"
grep -F -- "- Deleted Items | path: Deleted Items | id: f-deleted" "${WORK}/folders.txt" | grep -F "move target: no" >/dev/null || fail "folders output marks blocked targets"

: > "${WORK}/m365-calls.log"
_m365_mail_archive ut --message msg-inbox > "${WORK}/plan.txt"
grep -F "DRY RUN: nothing was moved" "${WORK}/plan.txt" >/dev/null || fail "archive defaults to dry run"
grep -F "Newsletter | from folder: Inbox" "${WORK}/plan.txt" >/dev/null || fail "archive plan lists the message"
grep -F '/move' "${WORK}/m365-bodies.log" >/dev/null && fail "dry run must not send a move"

expect_fail _m365_mail_archive ut --message msg-archived
grep -F "currently in 'Inbox'" "${WORK}/err.txt" >/dev/null || fail "archive requires an Inbox source"
expect_fail _m365_mail_unarchive ut --message msg-inbox
grep -F "currently in 'Archive'" "${WORK}/err.txt" >/dev/null || fail "unarchive requires an Archive source"
expect_fail _m365_mail_move ut --message msg-inbox --folder "Deleted Items"
grep -F "never move targets" "${WORK}/err.txt" >/dev/null || fail "Deleted Items is refused"
expect_fail _m365_mail_move ut --message msg-inbox --folder "Deleted Items/Old"
grep -F "never move targets" "${WORK}/err.txt" >/dev/null || fail "subfolders of Deleted Items are refused"
expect_fail _m365_mail_move ut --message msg-inbox --folder "sentitems"
expect_fail _m365_mail_archive ut --message msg-missing
grep -F "were not found" "${WORK}/err.txt" >/dev/null || fail "unknown IDs fail rather than skip"
expect_fail _m365_mail_archive ut --message msg-inbox --execute
grep -F "not enabled for alias 'ut'" "${WORK}/err.txt" >/dev/null || fail "execute requires mail.write_enabled"
grep -F '/move' "${WORK}/m365-bodies.log" >/dev/null && fail "refused execute must not send a move"

M365_ACCOUNTS_PATH="${WORK}/m365-write.json"
_m365_mail_archive ut --message msg-inbox --execute > "${WORK}/moved.txt"
grep -F "new message_id: new-msg-inbox" "${WORK}/moved.txt" >/dev/null || fail "move prints the new ID"
grep -F "confirmed by readback" "${WORK}/moved.txt" >/dev/null || fail "move is confirmed by readback"
jq -e -s 'length == 1 and .[0].action == "archive" and .[0].new_message_id == "new-msg-inbox" and .[0].verified == true' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null || fail "move is written to the audit log"

printf 'msg-inbox\n\n# comment\nmsg-inbox\n' > "${WORK}/ids.txt"
_m365_mail_move ut --ids-file "${WORK}/ids.txt" --folder receipts > "${WORK}/ids-plan.txt"
grep -F "Messages: 1" "${WORK}/ids-plan.txt" >/dev/null || fail "ids-file dedupes and skips comments"
grep -F "Destination: Inbox/Receipts" "${WORK}/ids-plan.txt" >/dev/null || fail "move resolves a nested destination"

_m365_mail_create_folder ut --name Receipts --parent inbox > "${WORK}/out.txt" 2> "${WORK}/err.txt" && fail "duplicate folder should fail"
grep -F "already exists at 'Inbox/Receipts'" "${WORK}/err.txt" >/dev/null || fail "duplicate folder message"
_m365_mail_create_folder ut --name Newsletters --parent inbox > "${WORK}/create.txt"
grep -F "New folder: Inbox/Newsletters" "${WORK}/create.txt" >/dev/null && grep -F "DRY RUN" "${WORK}/create.txt" >/dev/null || fail "create-folder dry run"
expect_fail _m365_mail_create_folder ut --name Stash --parent "Deleted Items"

##- Gmail
jq '(.accounts[] | select(.alias == "personal") | .gmail.write_enabled) = false' "${SECRETS_DIR}/google-accounts.example.json" > "${WORK}/google-read.json"
jq '(.accounts[] | select(.alias == "personal") | .gmail.write_enabled) = true' "${SECRETS_DIR}/google-accounts.example.json" > "${WORK}/google-write.json"
GOOGLE_ACCOUNTS_PATH="${WORK}/google-read.json"
export GOOGLE_ACCOUNTS_PATH

_google_account_scopes personal | grep -x 'https://www.googleapis.com/auth/gmail.modify' >/dev/null && fail "read-only alias should not request gmail.modify"
GOOGLE_ACCOUNTS_PATH="${WORK}/google-write.json" _google_account_scopes personal | grep -x 'https://www.googleapis.com/auth/gmail.modify' >/dev/null || fail "write-enabled alias should request gmail.modify"

# Synthetic mailbox: m-inbox (INBOX), m-spam (SPAM), thread t-1 holding m-inbox. Label changes are recorded in a state file so readback sees them.
printf '{"m-inbox": ["INBOX", "UNREAD"], "m-spam": ["SPAM"]}\n' > "${WORK}/gmail-state.json"
_google_get_url() {
    local url="$2" id
    case "$url" in
        */labels) printf '%s\n' '{"labels":[{"id":"INBOX","name":"INBOX","type":"system"},{"id":"TRASH","name":"TRASH","type":"system"},{"id":"Label_1","name":"Receipts","type":"user"}]}' ;;
        */threads/t-1) jq -c '{id: "t-1", messages: [{id: "m-inbox", threadId: "t-1", labelIds: .["m-inbox"], payload: {headers: [{name: "Subject", value: "Invoice"}, {name: "From", value: "shop@example.com"}]}}]}' "${WORK}/gmail-state.json" ;;
        */messages/*)
            id="${url##*/}"
            jq -e --arg id "$id" 'has($id)' "${WORK}/gmail-state.json" >/dev/null || { printf 'curl: (22) The requested URL returned error: 404\n' >&2; return 22; }
            jq -c --arg id "$id" '{id: $id, threadId: "t-1", labelIds: .[$id], payload: {headers: [{name: "Subject", value: "Invoice"}, {name: "From", value: "shop@example.com"}]}}' "${WORK}/gmail-state.json" ;;
        *) return 1 ;;
    esac
}
_gmail_send() {
    printf '%s %s %s\n' "$1" "$3" "$4" >> "${WORK}/gmail-calls.log"
    local ids
    case "$3" in
        */messages/batchModify) ids="$(printf '%s' "$4" | jq -c '.ids')" ;;
        */threads/t-1/modify) ids='["m-inbox"]' ;;
        *) return 1 ;;
    esac
    jq --argjson ids "$ids" --argjson req "$4" 'reduce $ids[] as $i (.; .[$i] = ((.[$i] + ($req.addLabelIds // [])) - ($req.removeLabelIds // []) | unique))' "${WORK}/gmail-state.json" > "${WORK}/gmail-state.next" && mv "${WORK}/gmail-state.next" "${WORK}/gmail-state.json"
    printf '{}\n'
}
: > "${WORK}/gmail-calls.log"

_gmail_archive personal --message m-inbox > "${WORK}/g-plan.txt"
grep -F "DRY RUN: nothing was changed" "${WORK}/g-plan.txt" >/dev/null || fail "gmail archive defaults to dry run"
[ -s "${WORK}/gmail-calls.log" ] && fail "gmail dry run must not write"
expect_fail _gmail_archive personal --message m-inbox --execute
grep -F "not enabled for alias 'personal'" "${WORK}/err.txt" >/dev/null || fail "gmail execute requires gmail.write_enabled"
expect_fail _gmail_archive personal --message m-spam
grep -F "Trash or Spam" "${WORK}/err.txt" >/dev/null || fail "spam targets are refused"
expect_fail _gmail_archive personal --message m-missing
grep -F "were not found" "${WORK}/err.txt" >/dev/null || fail "missing Gmail IDs fail"
expect_fail _gmail_label personal --label TRASH --message m-inbox
grep -F "system label" "${WORK}/err.txt" >/dev/null || fail "system labels are refused"
expect_fail _gmail_label personal --label Nope --message m-inbox
grep -F "No Gmail label matches" "${WORK}/err.txt" >/dev/null || fail "unknown labels fail"
expect_fail _gmail_unarchive personal --message m-inbox
grep -F "Already in Inbox" "${WORK}/err.txt" >/dev/null || fail "unarchive refuses Inbox mail"

GOOGLE_ACCOUNTS_PATH="${WORK}/google-write.json"
_gmail_label personal --label receipts --message m-inbox --skip-inbox --execute > "${WORK}/g-label.txt"
grep -F "confirmed by readback" "${WORK}/g-label.txt" >/dev/null || fail "gmail label is confirmed by readback"
jq -e '.["m-inbox"] == ["Label_1", "UNREAD"]' "${WORK}/gmail-state.json" >/dev/null || fail "label --skip-inbox adds the label and removes INBOX"
grep -F '"removeLabelIds":["INBOX"]' "${WORK}/gmail-calls.log" >/dev/null || fail "skip-inbox sends removeLabelIds INBOX"

_gmail_unarchive personal --thread t-1 --execute > "${WORK}/g-unarchive.txt"
grep -F "/threads/t-1/modify" "${WORK}/gmail-calls.log" >/dev/null || fail "thread targets use threads.modify"
jq -e '.["m-inbox"] | index("INBOX")' "${WORK}/gmail-state.json" >/dev/null || fail "unarchive restores INBOX"

_gmail_archive personal --thread t-1 --execute > /dev/null
_gmail_unlabel personal --label Receipts --message m-inbox --execute > /dev/null
jq -e '.["m-inbox"] == ["UNREAD"]' "${WORK}/gmail-state.json" >/dev/null || fail "archive then unlabel leaves only UNREAD"
jq -e -s '[.[] | select(.service == "gmail")] | length == 4 and all(.verified)' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null || fail "gmail changes are written to the audit log"
grep -E 'trash|delete' "${WORK}/gmail-calls.log" >/dev/null && fail "no Gmail call may trash or delete"

expect_fail _gmail_create_label personal --name receipts
grep -F "already exists" "${WORK}/err.txt" >/dev/null || fail "duplicate label fails"
_gmail_create_label personal --name "Triage/Newsletters" | grep -F "DRY RUN" >/dev/null || fail "create-label dry run"

printf 'OK: mail triage tests passed\n'
