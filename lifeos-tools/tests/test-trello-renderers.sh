#!/usr/bin/env bash
##- Test the Trello card renderer. Offline: fixtures only, no credentials and no network.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGS="$(cd "${TOOL_DIR}/.." && pwd)"
SECRETS_DIR="${TOOL_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"
LIB_DIR="${TOOL_DIR}/lib"
QA_DIR="${TOOL_DIR}/qa"
export CONFIGS SECRETS_DIR ENV_FILE LIB_DIR QA_DIR

# shellcheck source=/dev/null
. "${LIB_DIR}/common.sh"
# shellcheck source=/dev/null
. "${LIB_DIR}/trello.sh"

OUT="${TMPDIR:-/tmp}/lifeos-trello-render-test.md"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    printf -- '--- rendered output ---\n' >&2
    cat "$OUT" >&2
    exit 1
}

line_for() {
    grep -F -- "$1" "$OUT" | head -1
}

_trello_render_cards \
    "${SCRIPT_DIR}/fixtures/trello-lists.json" \
    "${SCRIPT_DIR}/fixtures/trello-cards.json" > "$OUT"

##- A start date is rendered raw, matching the existing `due:` convention.
got="$(line_for 'Correctly snoozed card')"
case "$got" in
    *"| start: 2026-09-21T12:00:00.000Z"*) : ;;
    *) fail "a snoozed card must render its start date raw; got: ${got}" ;;
esac

##- The whole point: a snoozed card's wake date must be readable from the snapshot.
case "$got" in
    *MISSING*) fail "a card with a start date must not be flagged as missing; got: ${got}" ;;
esac

##- A card in Snoozed with no start date will never be woken by Butler. Say so, loudly —
# rendering it as a plain absence leaves the defect as invisible as it was before.
got="$(line_for 'Broken snooze, dragged by hand')"
case "$got" in
    *"| start: MISSING (snoozed card will never wake)"*) : ;;
    *) fail "a Snoozed card without a start date must be flagged; got: ${got}" ;;
esac

##- The marker is scoped to Snoozed. Absence elsewhere is ordinary, not a defect.
got="$(line_for 'Plain card, no dates')"
case "$got" in
    *start:*) fail "a non-snoozed card without a start date must render no start clause; got: ${got}" ;;
    *due:*) fail "a card with no due date must render no due clause; got: ${got}" ;;
esac

got="$(line_for 'Parked card with no start')"
case "$got" in
    *start:*) fail "the MISSING marker must not leak to non-Snoozed lists; got: ${got}" ;;
esac

##- Both fields coexist, start first, so the line reads chronologically.
got="$(line_for 'Card with both start and due')"
case "$got" in
    *"| start: 2026-09-01T12:00:00.000Z | due: 2026-09-15T20:46:00.000Z"*) : ;;
    *) fail "start must render immediately before due; got: ${got}" ;;
esac

##- Last activity renders after due, so a retrospective can find cards that moved in its window.
got="$(line_for 'Card with both start and due')"
case "$got" in
    *"| due: 2026-09-15T20:46:00.000Z | last activity: 2026-09-20T10:00:00.000Z"*) : ;;
    *) fail "last activity must render immediately after due; got: ${got}" ;;
esac

##- A card without the field renders no last-activity clause.
got="$(line_for 'Plain card, no dates')"
case "$got" in
    *"last activity"*) fail "a card with no dateLastActivity must render no last-activity clause; got: ${got}" ;;
esac

##- Checklist items render under the card, in Trello's position order, with their state; the progress count stays on the card line.
got="$(line_for 'Card with a checklist')"
case "$got" in
    *"| checklists: Apply 1/2, Empty 0/0"*) : ;;
    *) fail "the card line must keep its checklist progress; got: ${got}" ;;
esac
block="$(grep -A3 -F -- 'Card with a checklist' "$OUT")"
expected="$(printf '  - Checklist: Apply\n    - [x] Tailor résumé\n    - [ ] Submit')"
case "$block" in
    *"$expected"*) : ;;
    *) fail "checklist items must render in pos order with [x]/[ ] state; got: ${block}" ;;
esac

##- A checklist with no items renders no block.
grep -q -F -- '- Checklist: Empty' "$OUT" && fail "an empty checklist must render no item block"

##- Only Snoozed is a snooze list by default, so another list without a start date is not flagged.
got="$(line_for 'Second snooze list, no start')"
case "$got" in
    *MISSING*) fail "a list outside TRELLO_SNOOZE_LISTS must not be flagged; got: ${got}" ;;
esac

##- TRELLO_SNOOZE_LISTS adds lists to the MISSING check, and Snoozed is only checked if it is named.
TRELLO_SNOOZE_LISTS="Snoozed, Follow Up Later" _trello_render_cards \
    "${SCRIPT_DIR}/fixtures/trello-lists.json" \
    "${SCRIPT_DIR}/fixtures/trello-cards.json" > "$OUT"
got="$(line_for 'Second snooze list, no start')"
case "$got" in
    *"| start: MISSING (snoozed card will never wake)"*) : ;;
    *) fail "a card in a configured snooze list without a start date must be flagged; got: ${got}" ;;
esac
got="$(line_for 'Broken snooze, dragged by hand')"
case "$got" in
    *MISSING*) : ;;
    *) fail "Snoozed must still be flagged when listed in TRELLO_SNOOZE_LISTS; got: ${got}" ;;
esac

rm -f "$OUT"
printf 'ok: trello card renderer\n'
