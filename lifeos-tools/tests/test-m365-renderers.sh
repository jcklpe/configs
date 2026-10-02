#!/usr/bin/env bash
##- Test Microsoft 365 Markdown renderers with synthetic Graph responses.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON="${TOOL_DIR}/.venv/bin/python"
[ -x "$PYTHON" ] || PYTHON=python3
MAIL_OUT="${TMPDIR:-/tmp}/lifeos-m365-mail-render-test.md"
CALENDAR_OUT="${TMPDIR:-/tmp}/lifeos-m365-calendar-render-test.md"
CONTACTS_OUT="${TMPDIR:-/tmp}/lifeos-m365-contacts-render-test.md"

"$PYTHON" "${TOOL_DIR}/lib/m365-render.py" mail \
    --alias ut \
    --email student@my.example.edu \
    --refreshed "2026-07-15 18:00:00 UTC" \
    --days 30 \
    --max-results 150 \
    --body-limit 8000 \
    --input "${SCRIPT_DIR}/fixtures/m365-mail.json" > "$MAIL_OUT"

"$PYTHON" "${TOOL_DIR}/lib/m365-render.py" calendar \
    --alias ut \
    --email student@my.example.edu \
    --refreshed "2026-07-15 18:00:00 UTC" \
    --start "2026-07-01T00:00:00Z" \
    --end "2026-09-01T00:00:00Z" \
    --timezone "Central Standard Time" \
    --description-limit 8000 \
    --input "${SCRIPT_DIR}/fixtures/m365-calendar.json" > "$CALENDAR_OUT"

"$PYTHON" "${TOOL_DIR}/lib/m365-render.py" contacts \
    --alias ut \
    --email student@my.example.edu \
    --refreshed "2026-07-15 18:00:00 UTC" \
    --max-results 500 \
    --notes-limit 4000 \
    --input "${SCRIPT_DIR}/fixtures/m365-contacts.json" > "$CONTACTS_OUT"

assert_contains() {
    file="$1"
    text="$2"
    if ! grep -F -- "$text" "$file" >/dev/null 2>&1; then
        printf 'Expected %s to contain:\n%s\n\nFull output:\n' "$file" "$text" >&2
        cat "$file" >&2
        exit 1
    fi
}

assert_not_contains() {
    file="$1"
    text="$2"
    if grep -F -- "$text" "$file" >/dev/null 2>&1; then
        printf 'Expected %s not to contain:\n%s\n\nFull output:\n' "$file" "$text" >&2
        cat "$file" >&2
        exit 1
    fi
}

assert_contains "$MAIL_OUT" "# Microsoft 365 Mail - ut"
assert_contains "$MAIL_OUT" "### 2026-07-15T14:30:00Z - Orientation details"
assert_contains "$MAIL_OUT" "UT iSchool <ischool@example.edu>"
assert_contains "$MAIL_OUT" "> Read the agenda (https://example.edu/orientation)"
assert_not_contains "$MAIL_OUT" "<p>"

assert_contains "$CALENDAR_OUT" "# Microsoft 365 Calendar - ut"
assert_contains "$CALENDAR_OUT" "### 2026-08-18T09:30:00.0000000 - Graduate orientation"
assert_contains "$CALENDAR_OUT" "Event ID: \`event-1\`"
assert_contains "$CALENDAR_OUT" "Location: Santa Rita Room"

assert_contains "$CONTACTS_OUT" "# Microsoft 365 Contacts - ut"
assert_contains "$CONTACTS_OUT" "### Ada Lovelace"
assert_contains "$CONTACTS_OUT" "Contact ID: \`contact-1\`"
assert_contains "$CONTACTS_OUT" "Met through a research seminar."


PLANNER_OUT="${TMPDIR:-/tmp}/lifeos-m365-planner-render-test.md"
"$PYTHON" "${TOOL_DIR}/lib/m365-render.py" planner \
    --alias ut \
    --email student@my.example.edu \
    --me user-me \
    --refreshed "2026-10-02 18:00:00 UTC" \
    --description-limit 2000 \
    --input "${SCRIPT_DIR}/fixtures/m365-planner.json" > "$PLANNER_OUT"
grep -F -- "# Microsoft 365 Planner - ut" "$PLANNER_OUT" >/dev/null
grep -F -- "Open tasks: 3 | Done: 1 | Open and assigned to you: 1" "$PLANNER_OUT" >/dev/null
grep -F -- "- Assignees: Test Student (you)" "$PLANNER_OUT" >/dev/null
grep -F -- "- Labels: LMS" "$PLANNER_OUT" >/dev/null
grep -F -- "- Priority: important" "$PLANNER_OUT" >/dev/null
grep -F -- "  - [x] Collect examples" "$PLANNER_OUT" >/dev/null
grep -F -- "### (no bucket)" "$PLANNER_OUT" >/dev/null
grep -F -- "Kickoff meeting | To Do | completed 2026-09-22 by Pat Example" "$PLANNER_OUT" >/dev/null
# Buckets follow Planner's ascending orderHint, so LMS Build (1000) precedes To Do (8585).
[ "$(grep -n '^### LMS Build' "$PLANNER_OUT" | cut -d: -f1)" -lt "$(grep -n '^### To Do' "$PLANNER_OUT" | cut -d: -f1)" ]

printf 'm365 renderer fixtures passed\n'
