#!/usr/bin/env bash
##- Test Google Gmail and Sheets Markdown renderers

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GMAIL_OUT="${TMPDIR:-/tmp}/lifeos-gmail-render-test.md"
SHEET_OUT="${TMPDIR:-/tmp}/lifeos-sheet-render-test.md"

python3 "${TOOL_DIR}/lib/google-gmail-render.py" \
    personal \
    aslan@example.com \
    "in:inbox newer_than:30d" \
    150 \
    8000 \
    "2026-06-01 18:00:00 UTC" \
    "${SCRIPT_DIR}/fixtures/gmail-messages.json" > "$GMAIL_OUT"

python3 "${TOOL_DIR}/lib/google-sheets-render.py" \
    open-austin \
    sheet_id_123 \
    "${SCRIPT_DIR}/fixtures/sheet-meta.json" \
    "${SCRIPT_DIR}/fixtures/sheet-values.json" > "$SHEET_OUT"

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

assert_contains "$GMAIL_OUT" "# Gmail - personal"
assert_contains "$GMAIL_OUT" "Query: \`in:inbox newer_than:30d\`"
assert_contains "$GMAIL_OUT" "### 2026-06-01T17:00:00Z - Plain message"
assert_contains "$GMAIL_OUT" "> Hello from plain text."
assert_contains "$GMAIL_OUT" "Attachments: yes"
assert_contains "$GMAIL_OUT" "> Hello link (https://example.com)"
assert_not_contains "$GMAIL_OUT" "<p>"
assert_not_contains "$GMAIL_OUT" "agenda.pdf"

assert_contains "$SHEET_OUT" "# Google Sheet - Test Sheet"
assert_contains "$SHEET_OUT" "Account alias: \`open-austin\`"
assert_contains "$SHEET_OUT" "| Name | Role | Link |"
assert_contains "$SHEET_OUT" "| Taylor | Designer | notes \\| context |"

printf 'google render fixtures passed\n'
