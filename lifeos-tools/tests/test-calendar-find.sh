#!/usr/bin/env bash
##- Test Google Calendar find output formatting

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGS="$(cd "${TOOL_DIR}/.." && pwd)"
LIB_DIR="${TOOL_DIR}/lib"
SECRETS_DIR="${TOOL_DIR}/secrets"
QA_DIR="${TOOL_DIR}/qa"
OUT="${TMPDIR:-/tmp}/lifeos-calendar-find-test.md"
EVENTS="${TMPDIR:-/tmp}/lifeos-calendar-find-events.json"

. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/google.sh"

jq '.items |= map(. + {_calendar_id: "primary", _calendar_summary: "Test Calendar"})' \
    "${SCRIPT_DIR}/fixtures/events.json" > "$EVENTS"

_calendar_find_human < "$EVENTS" > "$OUT"

assert_contains() {
    if ! grep -F -- "$1" "$OUT" >/dev/null 2>&1; then
        printf 'Expected output to contain:\n%s\n\nFull output:\n' "$1" >&2
        cat "$OUT" >&2
        exit 1
    fi
}

assert_contains "- One Day All Day | calendar: Test Calendar | calendar_id: primary | event_id: one-day-all-day | start: 2026-06-23 | end: 2026-06-24 | https://calendar.test/one-day"
assert_contains "- Normal Timed Event | calendar: Test Calendar | calendar_id: primary | event_id: normal-timed | start: 2026-06-25T10:00:00-05:00 | end: 2026-06-25T11:00:00-05:00 | location: Library Room | https://calendar.test/normal"

printf 'calendar find formatter fixture passed\n'
