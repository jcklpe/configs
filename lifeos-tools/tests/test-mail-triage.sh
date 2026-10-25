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
          {"id":"f-sent","displayName":"Sent Items","parentFolderId":"root","childFolderCount":0,"totalItemCount":0,"unreadItemCount":0},
          {"id":"f-junk","displayName":"Junk Email","parentFolderId":"root","childFolderCount":0,"totalItemCount":0,"unreadItemCount":0}]}' > "$3" ;;
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
      elif (.url | test("^/me/mailFolders/junkemail[?]")) then {status: 200, body: {id: "f-junk"}}
      elif (.url | test("^/me/mailFolders/")) then {status: 404, body: {error: {code: "ErrorFolderNotFound"}}}
      elif (.url | test("^/me/messages/msg-inbox[?]")) then {status: 200, body: {id: "msg-inbox", subject: "Newsletter", from: {emailAddress: {address: "news@example.com"}}, receivedDateTime: "2026-09-01T00:00:00Z", parentFolderId: "f-inbox"}}
      elif (.url | test("^/me/messages/msg-archived[?]")) then {status: 200, body: {id: "msg-archived", subject: "Old notice", from: {emailAddress: {address: "notice@example.com"}}, receivedDateTime: "2026-08-01T00:00:00Z", parentFolderId: "f-archive"}}
      elif (.method == "POST" and (.url | test("/move$"))) then {status: 201, body: {id: ("new-" + (.url | capture("/me/messages/(?<m>[^/]+)/move").m)), parentFolderId: .body.destinationId}}
      elif (.url | test("^/me/messages/new-")) then {status: 200, body: {id: (.url | capture("/me/messages/(?<m>[^?]+)").m), parentFolderId: "f-archive"}}
      else {status: 404, body: {error: {code: "ErrorItemNotFound", message: "not found"}}} end)]}'
}

TREE="${WORK}/tree.json"
_m365_mail_folder_tree ut "$TREE"
jq -e 'map(.path) == ["Archive", "Archive/Old", "Deleted Items", "Deleted Items/Old", "Inbox", "Inbox/Receipts", "Junk Email", "Sent Items"]' "$TREE" >/dev/null || fail "folder tree paths"
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

expect_fail _m365_mail_not_junk ut --message msg-inbox
grep -F "currently in 'Junk Email'" "${WORK}/err.txt" >/dev/null || fail "not-junk requires a Junk source"

##- Microsoft 365 categories
printf '{"msg-a": ["Existing"], "msg-b": []}\n' > "${WORK}/cats.json"
_m365_write() {
    printf '%s\n' "$4" >> "${WORK}/cat-bodies.log"
    local body="$4"
    printf '%s' "$body" | jq -c --slurpfile st "${WORK}/cats.json" '{responses: [.requests[] | {id: .id} + (
      (.url | capture("^/me/messages/(?<m>[^?]+)").m) as $m |
      if ($st[0] | has($m)) | not then {status: 404, body: {error: {code: "ErrorItemNotFound"}}}
      elif .method == "GET" then {status: 200, body: {id: $m, subject: ("Subject " + $m), from: {emailAddress: {address: "x@example.com"}}, receivedDateTime: "2026-09-30T00:00:00Z", categories: $st[0][$m]}}
      else {status: 200, body: {id: $m}} end)]}'
    # Apply PATCHes to the state file so readback sees them.
    printf '%s' "$body" | jq -c '[.requests[] | select(.method == "PATCH") | {m: (.url | capture("^/me/messages/(?<m>[^?]+)").m), c: .body.categories}]' > "${WORK}/patches.json"
    jq --slurpfile p "${WORK}/patches.json" 'reduce $p[0][] as $x (.; .[$x.m] = $x.c)' "${WORK}/cats.json" > "${WORK}/cats.next" && mv "${WORK}/cats.next" "${WORK}/cats.json"
}
M365_ACCOUNTS_PATH="${WORK}/m365-read.json"
: > "${WORK}/cat-bodies.log"
_m365_mail_category_cmd categorize ut --category hai --message msg-a --message msg-b > "${WORK}/cat-plan.txt"
grep -F "DRY RUN" "${WORK}/cat-plan.txt" >/dev/null || fail "categorize defaults to dry run"
grep -F '"PATCH"' "${WORK}/cat-bodies.log" >/dev/null && fail "dry run must not PATCH"
expect_fail _m365_mail_category_cmd categorize ut --category hai --message msg-a --execute
grep -F "not enabled for alias 'ut'" "${WORK}/err.txt" >/dev/null || fail "categorize execute requires mail.write_enabled"
expect_fail _m365_mail_category_cmd categorize ut --category existing --message msg-a
grep -F "already have" "${WORK}/err.txt" >/dev/null || fail "adding a category the message has (case-insensitive) is refused"
expect_fail _m365_mail_category_cmd categorize ut --category hai --message msg-missing
grep -F "were not found" "${WORK}/err.txt" >/dev/null || fail "unknown IDs fail"
expect_fail _m365_mail_category_cmd categorize ut --category "a,b" --message msg-a
M365_ACCOUNTS_PATH="${WORK}/m365-write.json"
_m365_mail_category_cmd categorize ut --category hai --message msg-a --message msg-b --execute > "${WORK}/cat-exec.txt"
grep -F "confirmed by readback" "${WORK}/cat-exec.txt" >/dev/null || fail "categorize confirmed by readback"
jq -e '.["msg-a"] == ["Existing", "hai"] and .["msg-b"] == ["hai"]' "${WORK}/cats.json" >/dev/null || fail "categorize keeps existing categories and adds the new one"
_m365_mail_category_cmd uncategorize ut --category HAI --message msg-a --execute > /dev/null
jq -e '.["msg-a"] == ["Existing"]' "${WORK}/cats.json" >/dev/null || fail "uncategorize removes only that category, case-insensitively"
expect_fail _m365_mail_category_cmd uncategorize ut --category hai --message msg-a
grep -F "already lack" "${WORK}/err.txt" >/dev/null || fail "removing an absent category is refused"
jq -e -s '[.[] | select(.action == "categorize" or .action == "uncategorize")] | length == 3 and all(.verified)' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null || fail "category changes are audit-logged"

bash "${SCRIPT_DIR}/../agent-hands/skills/use-gmail/tests/test-triage.sh"

printf 'OK: mail triage tests passed\n'
