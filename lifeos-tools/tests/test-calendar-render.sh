#!/usr/bin/env bash
##- Test Google Calendar Markdown rendering fixtures

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT="${TMPDIR:-/tmp}/lifeos-calendar-render-test.md"

python3 "${TOOL_DIR}/google-calendar-render.py" \
    "${SCRIPT_DIR}/fixtures/calendar.json" \
    "${SCRIPT_DIR}/fixtures/events.json" > "$OUT"

assert_contains() {
    if ! grep -F -- "$1" "$OUT" >/dev/null 2>&1; then
        printf 'Expected output to contain:\n%s\n\nFull output:\n' "$1" >&2
        cat "$OUT" >&2
        exit 1
    fi
}

assert_not_contains() {
    if grep -F -- "$1" "$OUT" >/dev/null 2>&1; then
        printf 'Expected output not to contain:\n%s\n\nFull output:\n' "$1" >&2
        cat "$OUT" >&2
        exit 1
    fi
}

assert_contains "### 2026-06-23"
assert_contains "- all day - One Day All Day | https://calendar.test/one-day"
assert_not_contains "One Day All Day (multi-day"

assert_contains "### 2026-06-24"
assert_contains "- all day - Visit French Fam in Houston (multi-day, 2026-06-24 through 2026-06-27; end 2026-06-28 exclusive) | https://calendar.test/houston"
assert_contains "### 2026-06-27"
assert_contains "- all day - Visit French Fam in Houston (continues, 2026-06-24 through 2026-06-27; end 2026-06-28 exclusive) | https://calendar.test/houston"
assert_not_contains "### 2026-06-28"

assert_contains "- 10:00-11:00 - Normal Timed Event | https://calendar.test/normal"
assert_contains "- 23:30-continues - Cross Midnight Event (continues, 2026-06-26 23:30 to 2026-06-27 01:15) | https://calendar.test/cross-midnight"
assert_contains "- continues-01:15 - Cross Midnight Event (continues, 2026-06-26 23:30 to 2026-06-27 01:15) | https://calendar.test/cross-midnight"

printf 'calendar render fixtures passed\n'
