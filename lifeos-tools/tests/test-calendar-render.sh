#!/usr/bin/env bash
##- Test Google Calendar Markdown rendering fixtures

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT="${TMPDIR:-/tmp}/lifeos-calendar-render-test.md"

python3 "${TOOL_DIR}/google-calendar-render.py" \
    "${SCRIPT_DIR}/fixtures/calendar.json" \
    "${SCRIPT_DIR}/fixtures/events.json" \
    "${SCRIPT_DIR}/fixtures/calendar-secondary.json" \
    "${SCRIPT_DIR}/fixtures/events-secondary.json" \
    "${SCRIPT_DIR}/fixtures/calendar-empty.json" \
    "${SCRIPT_DIR}/fixtures/events-empty.json" > "$OUT"

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

assert_count() {
    count="$(grep -F -- "$1" "$OUT" | wc -l | tr -d ' ')"
    if [ "$count" != "$2" ]; then
        printf 'Expected output to contain %s instance(s) of:\n%s\nFound: %s\n\nFull output:\n' "$2" "$1" "$count" >&2
        cat "$OUT" >&2
        exit 1
    fi
}

assert_before() {
    first_line="$(grep -n -F -- "$1" "$OUT" | sed -n '1s/:.*//p')"
    second_line="$(grep -n -F -- "$2" "$OUT" | sed -n '1s/:.*//p')"
    if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
        printf 'Expected first text to appear before second text:\n%s\n%s\n\nFull output:\n' "$1" "$2" >&2
        cat "$OUT" >&2
        exit 1
    fi
}

assert_contains "## Combined Agenda"
assert_not_contains "## Test Calendar"
assert_not_contains "## Other Calendar"
assert_not_contains "## Empty Calendar"

assert_contains "### 2026-06-23"
assert_contains "- all day - One Day All Day | calendar: Test Calendar | https://calendar.test/one-day"
assert_not_contains "One Day All Day (multi-day"

assert_contains "### 2026-06-24"
assert_contains "- all day - Visit French Fam in Houston (multi-day, 2026-06-24 through 2026-06-27; end 2026-06-28 exclusive) | calendar: Test Calendar | https://calendar.test/houston"
assert_contains "### 2026-06-27"
assert_contains "- all day - Visit French Fam in Houston (continues, 2026-06-24 through 2026-06-27; end 2026-06-28 exclusive) | calendar: Test Calendar | https://calendar.test/houston"
assert_not_contains "### 2026-06-28"

assert_contains "- 09:00-09:30 - Secondary Timed Event | calendar: Other Calendar | location: Austin, TX | https://calendar.test/secondary"
assert_contains "- 10:00-11:00 - Normal Timed Event | calendar: Test Calendar, Other Calendar | location: Library Room | https://calendar.test/normal"
assert_count "Normal Timed Event" "1"
assert_contains "    > Bring notebook."
assert_contains "    > Plain second line."
assert_before "- 09:00-09:30 - Secondary Timed Event" "- 10:00-11:00 - Normal Timed Event"

assert_contains "- 12:00-13:00 - HTML Description Event | calendar: Other Calendar | https://calendar.test/html"
assert_contains "    > RSVP at Partiful (https://partiful.com/e/example)"
assert_contains "    > Join Zoom: https://zoom.us/j/123456789"
assert_not_contains "<p>"
assert_not_contains "<a href"

assert_contains "- 13:30-14:30 - Long Description Event | calendar: Other Calendar | https://calendar.test/long"
assert_contains "    > [description truncated]"

assert_contains "- 23:30-continues - Cross Midnight Event (continues, 2026-06-26 23:30 to 2026-06-27 01:15) | calendar: Test Calendar | meeting: https://meet.google.com/abc-defg-hij | https://calendar.test/cross-midnight"
assert_contains "- continues-01:15 - Cross Midnight Event (continues, 2026-06-26 23:30 to 2026-06-27 01:15) | calendar: Test Calendar | meeting: https://meet.google.com/abc-defg-hij | https://calendar.test/cross-midnight"

printf 'calendar render fixtures passed\n'
