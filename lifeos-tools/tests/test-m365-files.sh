#!/usr/bin/env bash
##- Test Microsoft 365 file writes offline: scope, upload transport request, OneNote refusal, existing-name refusal, dry-run and write gates, If-Match on replace, readback, and the audit log.

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
. "${LIB_DIR}/m365-files.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-files-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
LIFEOS_MAIL_AUDIT_LOG="${WORK}/audit.jsonl"
export LIFEOS_MAIL_AUDIT_LOG

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { if "$@" > "${WORK}/out.txt" 2> "${WORK}/err.txt"; then fail "expected failure: $*"; fi; }

jq '(.accounts[] | select(.alias == "ut") | .files) = {enabled: true, write_enabled: false}' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/read.json"
jq '(.accounts[] | select(.alias == "ut") | .files) = {enabled: true, write_enabled: true}' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/write.json"
M365_ACCOUNTS_PATH="${WORK}/read.json"
export M365_ACCOUNTS_PATH

_m365_scopes ut 2>/dev/null | grep -qx 'Files.ReadWrite.All' || fail "Files.ReadWrite.All not requested"
if _m365_scopes ut 2>/dev/null | grep -qx 'Files.ReadWrite'; then fail "narrow Files.ReadWrite requested"; fi

# The PowerShell transport carries an upload as input_file rather than a JSON body.
_m365_prepare_powershell_request PUT ut 'https://graph.microsoft.com/v1.0/me/drive/items/root:/a.txt:/content' '' "${WORK}/req.json" --upload-file /tmp/a.txt -H 'If-Match: "e1"'
jq -e '.input_file == "/tmp/a.txt" and .headers["If-Match"] == "\"e1\"" and .body == ""' "${WORK}/req.json" >/dev/null || fail "upload request shape"

printf 'hello world\n' > "${WORK}/notes.md"
printf 'x' > "${WORK}/section.one"

_m365_get() {
    case "$2" in
        */items/folder-1) printf '%s\n' '{"id":"folder-1","name":"Shared","folder":{"childCount":1},"webUrl":"https://example/Shared","parentReference":{"driveId":"d1","path":"/drive/root:"}}' ;;
        */items/folder-1:/exists.md) printf '%s\n' '{"id":"x"}' ;;
        */items/folder-1:/*) return 1 ;;
        */items/nb-1) printf '%s\n' '{"id":"nb-1","name":"Me + Pat","folder":{},"package":{"type":"oneNote"}}' ;;
        */items/new-1) printf '%s\n' '{"id":"new-1","name":"notes.md","size":12,"webUrl":"https://example/notes.md","parentReference":{"driveId":"d1"}}' ;;
        */items/file-1) if [ -f "${WORK}/replaced" ]; then printf '%s\n' '{"id":"file-1","name":"plan.md","size":12,"webUrl":"https://example/plan.md","parentReference":{"driveId":"d1"}}'; else printf '%s\n' '{"id":"file-1","name":"plan.md","size":5,"eTag":"\"etag-7\"","file":{"mimeType":"text/markdown"},"webUrl":"https://example/plan.md","parentReference":{"driveId":"d1","path":"/drive/root:/Shared"},"lastModifiedDateTime":"2026-10-01T00:00:00Z","lastModifiedBy":{"user":{"displayName":"Pat"}}}'; fi ;;
        *) return 1 ;;
    esac
}
_m365_http() {
    printf '%s %s %s\n' "$1" "$3" "$*" >> "${WORK}/writes.log"
    case "$3" in */items/file-1/content) : > "${WORK}/replaced"; printf '{}\n' ;; *) printf '%s\n' '{"id":"new-1","parentReference":{"driveId":"d1"}}' ;; esac
}

# Refusals.
expect_fail _m365_files_upload ut "${WORK}/section.one" --parent folder-1
expect_fail _m365_files_upload ut "${WORK}/notes.md" --parent nb-1
expect_fail _m365_files_upload ut "${WORK}/notes.md" --parent folder-1 --name exists.md
expect_fail _m365_files_upload ut "${WORK}/notes.md" --parent file-1
expect_fail _m365_files_replace ut nb-1 --file "${WORK}/notes.md"

# Dry runs write nothing, and execute is refused while writes are off.
out="$(_m365_files_upload ut "${WORK}/notes.md" --parent folder-1)"
printf '%s\n' "$out" | grep -F -- "DRY RUN: nothing was uploaded" >/dev/null || fail "upload dry run"
printf '%s\n' "$out" | grep -F -- "Destination: /drive/root:/Shared/notes.md" >/dev/null || fail "upload destination"
expect_fail _m365_files_upload ut "${WORK}/notes.md" --parent folder-1 --execute
[ ! -f "${WORK}/writes.log" ] || fail "write while disabled"

M365_ACCOUNTS_PATH="${WORK}/write.json"
out="$(_m365_files_upload ut "${WORK}/notes.md" --parent folder-1 --execute)"
printf '%s\n' "$out" | grep -F -- "Uploaded (confirmed by readback): notes.md | item_id: new-1" >/dev/null || fail "upload execute"
grep -F -- 'conflictBehavior=fail' "${WORK}/writes.log" | grep -F -- '--upload-file' >/dev/null || fail "upload call"

out="$(_m365_files_replace ut file-1 --file "${WORK}/notes.md")"
printf '%s\n' "$out" | grep -F -- "Now: 5 bytes, modified 2026-10-01T00:00:00Z by Pat" >/dev/null || fail "replace plan"
out="$(_m365_files_replace ut file-1 --file "${WORK}/notes.md" --execute)"
printf '%s\n' "$out" | grep -F -- "Replaced (confirmed by readback): plan.md | 12 bytes" >/dev/null || fail "replace execute"
grep -F -- 'items/file-1/content' "${WORK}/writes.log" | grep -F -- 'If-Match: "etag-7"' >/dev/null || fail "replace If-Match"
jq -e 'select(.action == "replace") | .verified == true and .service == "m365-files"' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null || fail "audit"

printf 'm365 file write tests passed\n'
