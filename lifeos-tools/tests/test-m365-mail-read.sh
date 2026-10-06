#!/usr/bin/env bash
##- Test Microsoft 365 mail reads offline: folder listing with web links, KQL search across folders with Junk Email left out, and reading one message from any folder. Graph calls are stubbed; no real mail is involved.

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
M365_ACCOUNTS_PATH="${SECRETS_DIR}/m365-accounts.example.json"
export M365_ACCOUNTS_PATH

. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-mail-read-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { if "$@" > "${WORK}/out.txt" 2> "${WORK}/err.txt"; then fail "expected failure: $*"; fi; }

# Synthetic mailbox: Inbox, Archive, Sent Items, Junk Email, and Junk Email/Old.
_m365_mail_folder_tree() {
    printf '%s\n' '[
      {"id":"f-arch","displayName":"Archive","path":"Archive","wellKnown":"archive","moveTarget":true,"totalItemCount":2},
      {"id":"f-inbox","displayName":"Inbox","path":"Inbox","wellKnown":"inbox","moveTarget":true,"totalItemCount":1},
      {"id":"f-junk","displayName":"Junk Email","path":"Junk Email","wellKnown":"junkemail","moveTarget":false,"totalItemCount":1},
      {"id":"f-junk-old","displayName":"Old","path":"Junk Email/Old","wellKnown":null,"moveTarget":false,"totalItemCount":1},
      {"id":"f-sent","displayName":"Sent Items","path":"Sent Items","wellKnown":"sentitems","moveTarget":false,"totalItemCount":1}]' > "$2"
}

# Record every query parameter and return one message per folder, plus one whose folder is not in the tree.
_m365_get_paginated() {
    local out="$3" url="$4"
    shift 4
    printf 'URL %s\n' "$url" >> "${WORK}/calls.log"
    while [ "$#" -gt 0 ]; do printf 'ARG %s\n' "$2" >> "${WORK}/calls.log"; shift 2; done
    printf '%s\n' '{"value":[
      {"id":"m-arch","subject":"RE: Weekly update","from":{"emailAddress":{"name":"Pat Doe","address":"pat@example.edu"}},"receivedDateTime":"2026-10-01T15:00:00Z","isRead":true,"parentFolderId":"f-arch","webLink":"https://outlook.example.com/owa/?ItemID=m-arch"},
      {"id":"m-sent","subject":"Weekly update","from":{"emailAddress":{"name":"Me","address":"me@example.edu"}},"receivedDateTime":"2026-09-30T15:00:00Z","isRead":true,"parentFolderId":"f-sent","webLink":"https://outlook.example.com/owa/?ItemID=m-sent"},
      {"id":"m-junk","subject":"You won","from":{"emailAddress":{"address":"spam@example.com"}},"receivedDateTime":"2026-09-29T15:00:00Z","isRead":false,"parentFolderId":"f-junk"},
      {"id":"m-junk-old","subject":"You won again","from":{"emailAddress":{"address":"spam@example.com"}},"receivedDateTime":"2026-09-28T15:00:00Z","isRead":false,"parentFolderId":"f-junk-old"},
      {"id":"m-hidden","subject":"Elsewhere","from":{"emailAddress":{"address":"x@example.com"}},"receivedDateTime":"2026-09-27T15:00:00Z","isRead":true,"parentFolderId":"f-unlisted"}]}' > "$out"
}

##- List one folder: newest first, with the web link and the select that carries it.
: > "${WORK}/calls.log"
_m365_mail_list ut --folder archive > "${WORK}/list.txt"
grep -F -- "Folder: Archive (2 total)" "${WORK}/list.txt" >/dev/null || fail "folder header"
grep -F -- "  outlook: https://outlook.example.com/owa/?ItemID=m-arch" "${WORK}/list.txt" >/dev/null || fail "list prints the web link"
grep -F -- "  message_id: m-arch" "${WORK}/list.txt" >/dev/null || fail "list prints the message ID"
grep -Fx -- "URL https://graph.microsoft.com/v1.0/me/mailFolders/f-arch/messages" "${WORK}/calls.log" >/dev/null || fail "folder list URL"
grep -F -- 'ARG $orderby=receivedDateTime desc' "${WORK}/calls.log" >/dev/null || fail "folder list orders by date"
grep -E -- '^ARG \$select=.*webLink' "${WORK}/calls.log" >/dev/null || fail "list selects webLink"
grep -F -- 'ARG $search=' "${WORK}/calls.log" >/dev/null && fail "plain list must not search"
grep -F -- "| folder:" "${WORK}/list.txt" >/dev/null && fail "plain list should not repeat the folder per message"

##- Search the whole mailbox: KQL quoted for Graph, no $orderby, Junk Email and its subfolders left out, folder named per hit.
: > "${WORK}/calls.log"
_m365_mail_list ut --search 'from:pat subject:"weekly update"' > "${WORK}/search.txt"
grep -Fx -- "URL https://graph.microsoft.com/v1.0/me/messages" "${WORK}/calls.log" >/dev/null || fail "search URL is mailbox-wide"
grep -Fx -- 'ARG $search="from:pat subject:\"weekly update\""' "${WORK}/calls.log" >/dev/null || fail "search query quoting"
grep -F -- 'ARG $orderby' "${WORK}/calls.log" >/dev/null && fail "search must not send \$orderby"
grep -F -- 'all folders except Junk Email | 3 found (2 more in Junk Email left out)' "${WORK}/search.txt" >/dev/null || fail "search header counts"
grep -F -- "RE: Weekly update | folder: Archive" "${WORK}/search.txt" >/dev/null || fail "search names the folder"
grep -F -- "Weekly update | folder: Sent Items" "${WORK}/search.txt" >/dev/null || fail "search covers Sent Items"
grep -F -- "Elsewhere | folder: (folder not listed)" "${WORK}/search.txt" >/dev/null || fail "unlisted folder is named, not dropped"
grep -F -- "m-junk" "${WORK}/search.txt" >/dev/null && fail "mailbox-wide search must leave out Junk Email"
_m365_mail_list ut --search 'pat' --json > "${WORK}/search.json"
jq -e '.excludedJunk == 2 and .search == "pat" and .folder == null and (.value | map(.folderPath)) == ["Archive", "Sent Items", "(folder not listed)"]' "${WORK}/search.json" >/dev/null || fail "search JSON"

##- Search one folder: Junk Email is searchable when named.
: > "${WORK}/calls.log"
_m365_mail_list ut --search 'won' --folder junkemail --json > "${WORK}/junk.json"
grep -Fx -- "URL https://graph.microsoft.com/v1.0/me/mailFolders/f-junk/messages" "${WORK}/calls.log" >/dev/null || fail "folder search URL"
jq -e '.excludedJunk == 0 and (.value | length) == 5 and .folder.path == "Junk Email"' "${WORK}/junk.json" >/dev/null || fail "named Junk Email folder is searched"

expect_fail _m365_mail_list ut
grep -F -- "requires --folder, --search, or both" "${WORK}/err.txt" >/dev/null || fail "list needs a folder or a search"
expect_fail _m365_mail_list ut --search pat --limit 201

##- Read one message from any folder.
LONG_BODY="$(printf 'Thanks for the update.%.0s ' $(seq 1 600))"
_m365_get() {
    printf 'URL %s\n' "$2" >> "${WORK}/read-calls.log"
    case "$2" in
        */me/messages/AAMk%2Babc%3D)
            local args=("$@")
            printf 'ARG %s\n' "${args[@]:2}" >> "${WORK}/read-calls.log"
            jq -n --arg body "$LONG_BODY" '{
              id: "AAMk+abc=", conversationId: "conv-1", subject: "RE: Weekly update",
              from: {emailAddress: {name: "Pat Doe", address: "pat@example.edu"}},
              toRecipients: [{emailAddress: {name: "Me", address: "me@example.edu"}}],
              ccRecipients: [], bccRecipients: [], replyTo: [],
              receivedDateTime: "2026-10-01T15:00:00Z", sentDateTime: "2026-10-01T14:59:58Z",
              isRead: true, isDraft: false, importance: "normal", categories: ["work"],
              hasAttachments: true, parentFolderId: "f-arch",
              webLink: "https://outlook.example.com/owa/?ItemID=AAMk%2Babc%3D",
              body: {contentType: "text", content: ("Hi,\n\n" + $body)},
              attachments: [{"@odata.type": "#microsoft.graph.fileAttachment", id: "a1", name: "agenda.docx", contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", size: 1234, isInline: false},
                            {"@odata.type": "#microsoft.graph.fileAttachment", id: "a2", name: "logo.png", contentType: "image/png", size: 99, isInline: true}]}' ;;
        */me/mailFolders/f-arch) [ -z "${FOLDER_FAILS:-}" ] || return 1; printf '%s\n' '{"id":"f-arch","displayName":"Archive"}' ;;
        *) return 1 ;;
    esac
}

: > "${WORK}/read-calls.log"
_m365_dispatch mail read ut --message 'AAMk+abc=' > "${WORK}/read.txt"
grep -Fx -- "URL https://graph.microsoft.com/v1.0/me/messages/AAMk%2Babc%3D" "${WORK}/read-calls.log" >/dev/null || fail "read URL-encodes the message ID"
grep -F -- 'ARG $expand=attachments($select=id,name,contentType,size,isInline)' "${WORK}/read-calls.log" >/dev/null || fail "read expands attachment names without content"
grep -F -- 'ARG Prefer: outlook.body-content-type="text"' "${WORK}/read-calls.log" >/dev/null || fail "read asks for a text body"
grep -E -- '^ARG \$select=.*body.*webLink' "${WORK}/read-calls.log" >/dev/null || fail "read selects body and webLink"
grep -Fx -- "# RE: Weekly update" "${WORK}/read.txt" >/dev/null || fail "read heading"
grep -Fx -- "- From: Pat Doe <pat@example.edu>" "${WORK}/read.txt" >/dev/null || fail "read sender"
grep -Fx -- "- To: Me <me@example.edu>" "${WORK}/read.txt" >/dev/null || fail "read recipients"
grep -Fx -- "- Folder: Archive" "${WORK}/read.txt" >/dev/null || fail "read names the folder"
grep -Fx -- "- Message ID: \`AAMk+abc=\`" "${WORK}/read.txt" >/dev/null || fail "read prints the message ID"
grep -Fx -- "- Outlook: https://outlook.example.com/owa/?ItemID=AAMk%2Babc%3D" "${WORK}/read.txt" >/dev/null || fail "read prints the web link"
grep -Fx -- "  - agenda.docx | application/vnd.openxmlformats-officedocument.wordprocessingml.document | 1234 bytes" "${WORK}/read.txt" >/dev/null || fail "read lists attachments"
grep -Fx -- "  - logo.png | image/png | 99 bytes | inline" "${WORK}/read.txt" >/dev/null || fail "read marks inline attachments"
grep -F -- "- Cc:" "${WORK}/read.txt" >/dev/null && fail "empty recipient lines are left out"
grep -Fx -- "    > Hi," "${WORK}/read.txt" >/dev/null || fail "read quotes the body"
grep -Fx -- "    > [content truncated]" "${WORK}/read.txt" >/dev/null || fail "read caps the body at mail.body_character_limit"

_m365_mail_read ut --message 'AAMk+abc=' --full > "${WORK}/full.txt"
grep -F -- "[content truncated]" "${WORK}/full.txt" >/dev/null && fail "--full prints the whole body"
[ "$(wc -c < "${WORK}/full.txt")" -gt 13000 ] || fail "--full body length"

_m365_mail_read ut --message 'AAMk+abc=' --json > "${WORK}/read.json"
jq -e '.folder == "Archive" and (.attachments | length) == 2 and (.body.content | length) > 13000' "${WORK}/read.json" >/dev/null || fail "read JSON"

FOLDER_FAILS=1 _m365_mail_read ut --message 'AAMk+abc=' > "${WORK}/nofolder.txt" || fail "a failed folder lookup must not fail the read"
grep -F -- "- Folder:" "${WORK}/nofolder.txt" >/dev/null && fail "unknown folder is left out"

expect_fail _m365_mail_read ut
grep -F -- "requires --message ID" "${WORK}/err.txt" >/dev/null || fail "read requires --message"
expect_fail _m365_mail_read ut --message missing-id

printf 'm365 mail list, search, and read fixtures passed\n'
