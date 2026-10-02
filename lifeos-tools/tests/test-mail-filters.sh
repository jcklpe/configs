#!/usr/bin/env bash
##- Test Gmail filters and Microsoft 365 Inbox rules offline: scopes, required criteria and actions, refused folders, dry-run gates, opt-in flags, readback, and the audit log. Gmail and Graph calls are stubbed.

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
. "${LIB_DIR}/mail-filters.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-mail-filters-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
LIFEOS_MAIL_AUDIT_LOG="${WORK}/audit.jsonl"
export LIFEOS_MAIL_AUDIT_LOG

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() { if "$@" > "${WORK}/out.txt" 2> "${WORK}/err.txt"; then fail "expected failure: $*"; fi; }

##- Gmail
jq '.accounts |= map(.gmail.filters_enabled = false)' "${SECRETS_DIR}/google-accounts.example.json" > "${WORK}/g-off.json"
jq '.accounts |= map(.gmail.filters_enabled = true)' "${SECRETS_DIR}/google-accounts.example.json" > "${WORK}/g-on.json"
GOOGLE_ACCOUNTS_PATH="${WORK}/g-off.json"
export GOOGLE_ACCOUNTS_PATH
if _google_account_scopes personal 2>/dev/null | grep -q 'gmail.settings.basic'; then fail "settings scope requested without filters_enabled"; fi
GOOGLE_ACCOUNTS_PATH="${WORK}/g-on.json"
_google_account_scopes personal 2>/dev/null | grep -qx 'https://www.googleapis.com/auth/gmail.settings.basic' || fail "settings scope missing with filters_enabled"
GOOGLE_ACCOUNTS_PATH="${WORK}/g-off.json"

_gmail_labels_fetch() { printf '%s\n' '{"labels":[{"id":"INBOX","name":"INBOX","type":"system"},{"id":"Label_1","name":"delete-me","type":"user"}]}'; }
_gmail_list() { printf 'preview for: %s\n' "$3"; }
_google_get_url() {
    case "$2" in
        */settings/filters) printf '%s\n' '{"filter":[{"id":"f-old","criteria":{"from":"news@example.com"},"action":{"addLabelIds":["Label_1"],"removeLabelIds":["INBOX"]}}]}' ;;
        */settings/filters/f-new) printf '%s\n' '{"id":"f-new","criteria":{"from":"statements@bank.example.com","subject":"Your eStatement has arrived"},"action":{"addLabelIds":["Label_1"],"removeLabelIds":["INBOX"]}}' ;;
        *) return 1 ;;
    esac
}
_gmail_send() { printf '%s %s %s\n' "$1" "$3" "$4" >> "${WORK}/gmail-writes.log"; printf '%s\n' '{"id":"f-new"}'; }

out="$(_gmail_filters personal)"
printf '%s\n' "$out" | grep -F -- "filter_id: f-old | when: from=news@example.com | then: label delete-me, skip inbox" >/dev/null || fail "filter listing"

expect_fail _gmail_create_filter personal --label delete-me
expect_fail _gmail_create_filter personal --from x@example.com
expect_fail _gmail_create_filter personal --from x@example.com --label INBOX

out="$(_gmail_create_filter personal --from statements@bank.example.com --subject "Your eStatement has arrived" --label delete-me --skip-inbox)"
printf '%s\n' "$out" | grep -F -- "DRY RUN: no filter was created" >/dev/null || fail "gmail dry run"
printf '%s\n' "$out" | grep -F -- 'preview for: from:(statements@bank.example.com) subject:(Your eStatement has arrived)' >/dev/null || fail "gmail preview search"
[ ! -f "${WORK}/gmail-writes.log" ] || fail "dry run wrote"
expect_fail _gmail_create_filter personal --from statements@bank.example.com --subject "Your eStatement has arrived" --label delete-me --skip-inbox --execute
[ ! -f "${WORK}/gmail-writes.log" ] || fail "write without filters_enabled"

GOOGLE_ACCOUNTS_PATH="${WORK}/g-on.json"
out="$(_gmail_create_filter personal --from statements@bank.example.com --subject "Your eStatement has arrived" --label delete-me --skip-inbox --execute)"
printf '%s\n' "$out" | grep -F -- "Created filter (confirmed by readback): filter_id: f-new" >/dev/null || fail "gmail create"
grep -F -- 'POST' "${WORK}/gmail-writes.log" | grep -F -- '"removeLabelIds":["INBOX"]' >/dev/null || fail "gmail body"
if grep -F -- 'forward' "${WORK}/gmail-writes.log" >/dev/null; then fail "forward in body"; fi
jq -e 'select(.action == "create-filter") | .verified == true' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null || fail "gmail audit"

##- Microsoft 365
jq '(.accounts[] | select(.alias == "ut") | .mail.rules_enabled) = false' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/m-off.json"
jq '(.accounts[] | select(.alias == "ut") | .mail.rules_enabled) = true' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/m-on.json"
M365_ACCOUNTS_PATH="${WORK}/m-off.json"
export M365_ACCOUNTS_PATH
if _m365_scopes ut 2>/dev/null | grep -qx 'MailboxSettings.ReadWrite'; then fail "MailboxSettings requested without rules_enabled"; fi
M365_ACCOUNTS_PATH="${WORK}/m-on.json"
_m365_scopes ut 2>/dev/null | grep -qx 'MailboxSettings.ReadWrite' || fail "MailboxSettings missing with rules_enabled"
M365_ACCOUNTS_PATH="${WORK}/m-off.json"

_m365_mail_folder_tree() {
    printf '%s\n' '[{"id":"f-inbox","displayName":"Inbox","path":"Inbox","wellKnown":"inbox","moveTarget":true},{"id":"f-arch","displayName":"Archive","path":"Archive","wellKnown":"archive","moveTarget":true},{"id":"f-del","displayName":"Deleted Items","path":"Deleted Items","wellKnown":"deleteditems","moveTarget":false}]' > "$2"
}
_m365_get() {
    case "$2" in
        */messageRules) printf '%s\n' '{"value":[{"id":"r-old","displayName":"Old","sequence":3,"isEnabled":true,"conditions":{"senderContains":["x"]},"actions":{"assignCategories":["work"]}}]}' ;;
        */messageRules/r-new) printf '%s\n' '{"id":"r-new","displayName":"Workday","sequence":4,"conditions":{"senderContains":["myworkday.com"]},"actions":{"assignCategories":["work"],"moveToFolder":"f-arch"}}' ;;
        *) return 1 ;;
    esac
}
_m365_write() { printf '%s %s %s\n' "$1" "$3" "$4" >> "${WORK}/m365-writes.log"; printf '%s\n' '{"id":"r-new"}'; }

out="$(_m365_mail_rules ut)"
printf '%s\n' "$out" | grep -F -- "Old | rule_id: r-old | enabled | when: senderContains=x | then: category work" >/dev/null || fail "rule listing"

expect_fail _m365_mail_create_rule ut --name X --category work
expect_fail _m365_mail_create_rule ut --name X --sender-contains a
expect_fail _m365_mail_create_rule ut --name Old --sender-contains a --category work
expect_fail _m365_mail_create_rule ut --name X --sender-contains a --folder "Deleted Items"

out="$(_m365_mail_create_rule ut --name Workday --sender-contains myworkday.com --category work --folder archive)"
printf '%s\n' "$out" | grep -F -- "DRY RUN: no rule was created" >/dev/null || fail "m365 dry run"
printf '%s\n' "$out" | grep -F -- "then: category work, move to Archive" >/dev/null || fail "m365 plan rendering"
[ ! -f "${WORK}/m365-writes.log" ] || fail "m365 dry run wrote"
expect_fail _m365_mail_create_rule ut --name Workday --sender-contains myworkday.com --category work --folder archive --execute
[ ! -f "${WORK}/m365-writes.log" ] || fail "m365 write without rules_enabled"

M365_ACCOUNTS_PATH="${WORK}/m-on.json"
out="$(_m365_mail_create_rule ut --name Workday --sender-contains myworkday.com --category work --folder archive --execute)"
printf '%s\n' "$out" | grep -F -- "Created rule (confirmed by readback): Workday | rule_id: r-new" >/dev/null || fail "m365 create"
grep -F -- '"sequence":4' "${WORK}/m365-writes.log" >/dev/null || fail "rule sequence"
jq -e 'select(.action == "create-rule") | .verified == true' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null || fail "m365 audit"

printf 'mail filter and rule tests passed\n'
