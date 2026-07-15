#!/usr/bin/env bash
##- Test Microsoft 365 shell-side pagination and local find formatters without network access.

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

PAGES_OUT="${TMPDIR:-/tmp}/lifeos-m365-pages-test.json"
CALENDAR_OUT="${TMPDIR:-/tmp}/lifeos-m365-calendar-find-test.txt"
CONTACTS_OUT="${TMPDIR:-/tmp}/lifeos-m365-contacts-find-test.txt"

_m365_get() {
    case "$2" in
        page-one) printf '%s\n' '{"value":[{"id":"one"}],"@odata.nextLink":"page-two"}' ;;
        page-two) printf '%s\n' '{"value":[{"id":"two"},{"id":"three"}]}' ;;
        *) return 1 ;;
    esac
}

_m365_get_paginated ut 2 "$PAGES_OUT" page-one
jq -e '(.value | length) == 2 and .value[0].id == "one" and .value[1].id == "two"' "$PAGES_OUT" >/dev/null

_m365_calendar_fetch() {
    cp "${TEST_DIR}/fixtures/m365-calendar.json" "$5"
}

_m365_contacts_fetch() {
    cp "${TEST_DIR}/fixtures/m365-contacts.json" "$2"
}

_m365_calendar_find ut "orientation" > "$CALENDAR_OUT"
grep -F -- "Graduate orientation" "$CALENDAR_OUT" >/dev/null
grep -F -- "event_id: event-1" "$CALENDAR_OUT" >/dev/null

_m365_contacts_find ut "analytical" > "$CONTACTS_OUT"
grep -F -- "Ada Lovelace" "$CONTACTS_OUT" >/dev/null
grep -F -- "contact_id: contact-1" "$CONTACTS_OUT" >/dev/null

printf 'm365 shell pagination and find fixtures passed\n'
