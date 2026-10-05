#!/usr/bin/env bash
##- Test the Trello checklist commands. Offline: the Trello API is stubbed, so no credentials and no network.

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

TRELLO_API_KEY="test" TRELLO_TOKEN="test" TRELLO_WRITE_TOKEN="test"
export TRELLO_API_KEY TRELLO_TOKEN TRELLO_WRITE_TOKEN

CALLS="${TMPDIR:-/tmp}/lifeos-trello-checklist-calls.$$"
ERR="${TMPDIR:-/tmp}/lifeos-trello-checklist-err.$$"
trap 'rm -f "$CALLS" "$ERR"' EXIT
: > "$CALLS"

CL_A="aaaaaaaaaaaaaaaaaaaaaaaa"
CL_B="bbbbbbbbbbbbbbbbbbbbbbbb"
CL_C="cccccccccccccccccccccccc"
ITEM_SUBMIT_A="111111111111111111111111"
ITEM_TAILOR="222222222222222222222222"
ITEM_SUBMIT_B="333333333333333333333333"

# Card has three checklists: "Apply" (Tailor, Submit), "Follow-up" (Submit), and a second "Follow-up" with no items.
_trello_get() {
    case "$1" in
        /cards/*/checklists)
            printf '[
              {"id":"%s","name":"Apply","checkItems":[{"id":"%s","name":"Tailor","state":"incomplete"},{"id":"%s","name":"Submit","state":"incomplete"}]},
              {"id":"%s","name":"Follow-up","checkItems":[{"id":"%s","name":"Submit","state":"complete"}]},
              {"id":"%s","name":"Follow-up","checkItems":[]}
            ]' "$CL_A" "$ITEM_TAILOR" "$ITEM_SUBMIT_A" "$CL_B" "$ITEM_SUBMIT_B" "$CL_C"
            ;;
        *) printf 'unexpected GET %s\n' "$1" >&2; return 1 ;;
    esac
}

# Record every write as "METHOD ENDPOINT key=value...", minus credentials.
_trello_write() {
    local method="$1" endpoint="$2" args=""
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in --data-urlencode) args="${args} $2"; shift 2 ;; *) shift ;; esac
    done
    printf '%s %s%s\n' "$method" "$endpoint" "$args" >> "$CALLS"
    case "$endpoint" in
        /checklists) printf '{"id":"dddddddddddddddddddddddd"}' ;;
        *) printf '{}' ;;
    esac
}

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    printf -- '--- recorded writes ---\n' >&2
    cat "$CALLS" >&2
    exit 1
}

expect_call() {
    grep -q -F -- "$1" "$CALLS" || fail "expected write: $1"
}

##- add-checklist creates the checklist on the card, then each --item in order, at the bottom.
_trello_add_checklist --card "https://trello.com/c/CARD1/1-x" --name "Apply" --item "Tailor" --item "Submit" > /dev/null
expect_call "POST /checklists idCard=CARD1 name=Apply pos=bottom"
expect_call "POST /checklists/dddddddddddddddddddddddd/checkItems name=Tailor pos=bottom"
expect_call "POST /checklists/dddddddddddddddddddddddd/checkItems name=Submit pos=bottom"
[ "$(grep -n 'name=Tailor' "$CALLS" | cut -d: -f1)" -lt "$(grep -n 'name=Submit' "$CALLS" | cut -d: -f1)" ] || fail "items must be added in argument order"

##- add-checklist with no --item creates only the checklist.
: > "$CALLS"
_trello_add_checklist --card CARD1 --name "Empty" > /dev/null
[ "$(wc -l < "$CALLS" | tr -d ' ')" = "1" ] || fail "add-checklist without items must make exactly one write"

##- add-checklist-item resolves a unique checklist name to its ID.
: > "$CALLS"
_trello_add_checklist_item --card CARD1 --checklist "Apply" --text "Cover letter" > /dev/null
expect_call "POST /checklists/${CL_A}/checkItems name=Cover letter pos=bottom"

##- An ambiguous checklist name fails without writing.
: > "$CALLS"
if _trello_add_checklist_item --card CARD1 --checklist "Follow-up" --text "Nudge" > /dev/null 2> "$ERR"; then
    fail "an ambiguous checklist name must fail"
fi
grep -q 'Multiple checklists' "$ERR" || fail "ambiguous checklist error must say so; got: $(cat "$ERR")"
[ ! -s "$CALLS" ] || fail "an ambiguous checklist name must not write"

##- A missing checklist name fails and lists the card's checklists.
if _trello_add_checklist_item --card CARD1 --checklist "Nope" --text "x" > /dev/null 2> "$ERR"; then
    fail "a missing checklist name must fail"
fi
grep -q 'Checklists: Apply, Follow-up, Follow-up' "$ERR" || fail "missing checklist error must list candidates; got: $(cat "$ERR")"

##- check-item resolves a unique item name across all checklists and sets it complete.
: > "$CALLS"
_trello_check_item --card CARD1 --item "Tailor" > /dev/null
expect_call "PUT /cards/CARD1/checkItem/${ITEM_TAILOR} state=complete"

##- uncheck-item sets incomplete.
: > "$CALLS"
_trello_uncheck_item --card CARD1 --item "Tailor" > /dev/null
expect_call "PUT /cards/CARD1/checkItem/${ITEM_TAILOR} state=incomplete"

##- An item name that appears in two checklists fails, lists both, and does not write.
: > "$CALLS"
if _trello_check_item --card CARD1 --item "Submit" > /dev/null 2> "$ERR"; then
    fail "an item name in two checklists must fail without --checklist"
fi
grep -q "${ITEM_SUBMIT_A} (in Apply)" "$ERR" && grep -q "${ITEM_SUBMIT_B} (in Follow-up)" "$ERR" \
    || fail "ambiguous item error must list each candidate with its checklist; got: $(cat "$ERR")"
[ ! -s "$CALLS" ] || fail "an ambiguous item must not write"

##- --checklist narrows the search, by name or ID.
_trello_check_item --card CARD1 --item "Submit" --checklist "Apply" > /dev/null
expect_call "PUT /cards/CARD1/checkItem/${ITEM_SUBMIT_A} state=complete"
: > "$CALLS"
_trello_check_item --card CARD1 --item "Submit" --checklist "$CL_B" > /dev/null
expect_call "PUT /cards/CARD1/checkItem/${ITEM_SUBMIT_B} state=complete"

##- An item ID is accepted directly.
: > "$CALLS"
_trello_check_item --card CARD1 --item "$ITEM_SUBMIT_B" > /dev/null
expect_call "PUT /cards/CARD1/checkItem/${ITEM_SUBMIT_B} state=complete"

##- A missing item fails without writing.
: > "$CALLS"
if _trello_check_item --card CARD1 --item "Nope" > /dev/null 2> "$ERR"; then
    fail "a missing item must fail"
fi
[ ! -s "$CALLS" ] || fail "a missing item must not write"

##- Required options are enforced before any write.
for args in "--name X" "--card CARD1"; do
    # shellcheck disable=SC2086
    if _trello_add_checklist $args > /dev/null 2>&1; then fail "add-checklist must require --card and --name ($args)"; fi
done
if _trello_add_checklist_item --card CARD1 --checklist Apply > /dev/null 2>&1; then fail "add-checklist-item must require --text"; fi
if _trello_check_item --card CARD1 > /dev/null 2>&1; then fail "check-item must require --item"; fi
[ ! -s "$CALLS" ] || fail "a missing required option must not write"

printf 'ok: trello checklist commands\n'
