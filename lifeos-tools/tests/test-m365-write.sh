#!/usr/bin/env bash
##- Test pure Microsoft 365 write bodies and dispatcher dry-run gates.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON="${TOOL_DIR}/.venv/bin/python"
[ -x "$PYTHON" ] || PYTHON=python3
EVENT_OUT="${TMPDIR:-/tmp}/lifeos-m365-event-write-test.json"
ALL_DAY_OUT="${TMPDIR:-/tmp}/lifeos-m365-all-day-write-test.json"
CONTACT_OUT="${TMPDIR:-/tmp}/lifeos-m365-contact-write-test.json"
PLAN_OUT="${TMPDIR:-/tmp}/lifeos-m365-plan-test.txt"

"$PYTHON" "${TOOL_DIR}/lib/m365-write.py" event \
    --title "Coffee" \
    --start "2026-08-20T10:00" \
    --tz "Central Standard Time" \
    --location "UTA" \
    --attendee "professor@example.edu" > "$EVENT_OUT"

"$PYTHON" "${TOOL_DIR}/lib/m365-write.py" event \
    --title "Orientation" \
    --start "2026-08-18" > "$ALL_DAY_OUT"

"$PYTHON" "${TOOL_DIR}/lib/m365-write.py" contact \
    --display-name "Ada Lovelace" \
    --email "ada@example.com" \
    --company "Analytical Engines" \
    --notes "Research contact" > "$CONTACT_OUT"

jq -e '.subject == "Coffee" and .start.dateTime == "2026-08-20T10:00:00" and .end.dateTime == "2026-08-20T11:00:00" and .attendees[0].emailAddress.address == "professor@example.edu"' "$EVENT_OUT" >/dev/null
jq -e '.isAllDay == true and .start.dateTime == "2026-08-18T00:00:00" and .end.dateTime == "2026-08-19T00:00:00"' "$ALL_DAY_OUT" >/dev/null
jq -e '.displayName == "Ada Lovelace" and .emailAddresses[0].address == "ada@example.com" and .companyName == "Analytical Engines"' "$CONTACT_OUT" >/dev/null

M365_ACCOUNTS_PATH="${TOOL_DIR}/secrets/m365-accounts.example.json" \
    "$TOOL_DIR/lifeos.sh" m365 calendar create-event ut \
    --title "Dry run" \
    --start "2026-08-20T10:00" > "$PLAN_OUT"
grep -F -- "DRY RUN: no event was created" "$PLAN_OUT" >/dev/null

M365_ACCOUNTS_PATH="${TOOL_DIR}/secrets/m365-accounts.example.json" \
    "$TOOL_DIR/lifeos.sh" m365 contacts create ut \
    --display-name "Dry Run Contact" \
    --email "dry-run@example.com" > "$PLAN_OUT"
grep -F -- "DRY RUN: no contact was created" "$PLAN_OUT" >/dev/null

if M365_ACCOUNTS_PATH="${TOOL_DIR}/secrets/m365-accounts.example.json" \
    "$TOOL_DIR/lifeos.sh" m365 calendar create-event ut \
    --title "Unsafe attendee test" \
    --start "2026-08-20T10:00" \
    --attendee "professor@example.edu" > "$PLAN_OUT" 2>&1; then
    printf 'Expected attendee-bearing M365 event without --notify to fail\n' >&2
    exit 1
fi
grep -F -- "Re-run with --notify" "$PLAN_OUT" >/dev/null

printf 'm365 write builders and dry-run gates passed\n'
