#!/usr/bin/env bash
##- Test Microsoft 365 Planner commands with Graph calls mocked: scopes, filters, allowlist, write gating, dry-run plans, If-Match, and readback.

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
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-planner-test.XXXXXX")"
LIFEOS_MAIL_AUDIT_LOG="${WORK}/audit.jsonl"
export LIFEOS_MAIL_AUDIT_LOG

. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"
. "${LIB_DIR}/m365-planner.sh"

# `! cmd` never trips `set -e`, so negative assertions go through refute, which fails the test when the command succeeds.
refute() { if "$@"; then printf 'FAIL: expected failure: %s\n' "$*" >&2; exit 1; fi; }
lacks() { if printf '%s\n' "$1" | grep -F -- "$2" >/dev/null; then printf 'FAIL: unexpected %s\n' "$2" >&2; exit 1; fi; }

# Planner enabled for reads only, with one allowlisted plan.
jq '(.accounts[] | select(.alias == "ut") | .planner) = {enabled: true, write_enabled: false, plans: [{id: "plan-1", name: "Project Tracker"}]}' "${SECRETS_DIR}/m365-accounts.example.json" > "${WORK}/read.json"
M365_ACCOUNTS_PATH="${WORK}/read.json"
export M365_ACCOUNTS_PATH

_m365_scopes ut 2>/dev/null | grep -qx 'Tasks.ReadWrite'
_m365_scopes ut 2>/dev/null | grep -qx 'User.ReadBasic.All'
refute sh -c "printf '%s\n' \"\$1\" | grep -qx Tasks.Read" _ "$(_m365_scopes ut)"

_m365_profile_json() { printf '%s\n' '{"id":"user-me","mail":"student@my.example.edu"}'; }

TASKS='{"value":[
 {"id":"task-1","title":"Mine open","bucketId":"b1","percentComplete":50,"assignments":{"user-me":{}},"dueDateTime":"2026-10-09T12:00:00Z"},
 {"id":"task-2","title":"Mine done","bucketId":"b1","percentComplete":100,"assignments":{"user-me":{}}},
 {"id":"task-3","title":"Someone else","bucketId":"b2","percentComplete":0,"assignments":{"user-x":{}}}]}'
_m365_get_paginated() {
    case "$4" in
        */tasks) printf '%s\n' "$TASKS" > "$3" ;;
        */buckets) printf '%s\n' '{"value":[{"id":"b1","name":"To Do","orderHint":"2"},{"id":"b2","name":"LMS Build","orderHint":"1"}]}' > "$3" ;;
        */me/planner/plans) printf '%s\n' '{"value":[{"id":"plan-1","title":"Project Tracker","container":{"containerId":"group-1"}},{"id":"plan-2","title":"Other"}]}' > "$3" ;;
        *) return 1 ;;
    esac
}

out="$(_m365_planner_tasks ut --plan plan-1 --mine --open)"
printf '%s\n' "$out" | grep -F -- "Mine open | in progress | bucket: To Do | due: 2026-10-09" >/dev/null
lacks "$out" "Mine done"
lacks "$out" "Someone else"

out="$(_m365_planner_plans ut)"
printf '%s\n' "$out" | grep -F -- "Project Tracker | plan_id: plan-1 | group: group-1 | configured" >/dev/null
printf '%s\n' "$out" | grep -F -- "Other | plan_id: plan-2" >/dev/null
lacks "$(printf '%s\n' "$out" | grep -F -- "Other")" "configured"

out="$(_m365_planner_buckets ut --plan plan-1)"
[ "$(printf '%s\n' "$out" | head -1)" = "- LMS Build | bucket_id: b2" ]

[ "$(_m365_planner_due 2026-10-09)" = '"2026-10-09T12:00:00Z"' ]
[ "$(_m365_planner_due none)" = 'null' ]
refute _m365_planner_due 10/09 2>/dev/null
[ "$(_m365_planner_progress done)" = 100 ]
refute _m365_planner_progress half 2>/dev/null

# Writes: mock single-object GETs and record every write.
CURRENT='{"id":"task-1","planId":"plan-1","title":"Mine open","bucketId":"b1","percentComplete":50,"assignments":{"user-me":{}},"@odata.etag":"W/\"etag-1\""}'
_m365_get() {
    case "$2" in
        */planner/tasks/task-1) printf '%s\n' "$CURRENT" ;;
        */planner/tasks/task-9) printf '%s\n' '{"id":"task-9","planId":"plan-2","title":"Elsewhere","@odata.etag":"W/\"e9\""}' ;;
        */planner/tasks/task-1/details) printf '%s\n' '{"id":"task-1","description":"old","@odata.etag":"W/\"detail-1\""}' ;;
        *) return 1 ;;
    esac
}
_m365_http() { printf '%s %s %s %s\n' "$1" "$3" "$4" "${6:-}" >> "${WORK}/writes.log"; printf '{}\n'; }
_m365_write() { printf '%s %s %s\n' "$1" "$3" "$4" >> "${WORK}/writes.log"; printf '%s\n' '{"id":"task-new"}'; }

# Dry run shows the plan and writes nothing.
out="$(_m365_planner_update ut --task task-1 --progress done --due 2026-10-16)"
printf '%s\n' "$out" | grep -F -- "DRY RUN: nothing was changed" >/dev/null
printf '%s\n' "$out" | grep -F -- '"percentComplete": 100' >/dev/null
[ ! -f "${WORK}/writes.log" ]

# A plan outside planner.plans is refused even on dry run.
refute _m365_planner_update ut --task task-9 --progress done >/dev/null 2>&1
refute _m365_planner_create ut --plan plan-2 --bucket b1 --title "x" >/dev/null 2>&1

# Execute is refused while planner.write_enabled is false.
refute _m365_planner_update ut --task task-1 --progress done --execute >/dev/null 2>&1
[ ! -f "${WORK}/writes.log" ]

# With writes enabled, the PATCH carries the etag read in this run and readback confirms it.
jq '(.accounts[] | select(.alias == "ut") | .planner.write_enabled) = true' "${WORK}/read.json" > "${WORK}/write.json"
M365_ACCOUNTS_PATH="${WORK}/write.json"
_m365_scopes ut 2>/dev/null | grep -qx 'Tasks.ReadWrite'
CURRENT_AFTER='{"id":"task-1","planId":"plan-1","title":"Mine open","bucketId":"b1","percentComplete":100,"dueDateTime":"2026-10-16T12:00:00Z","assignments":{"user-me":{}},"@odata.etag":"W/\"etag-2\""}'
# Each Graph call runs in a command-substitution subshell, so the call count lives in a file.
: > "${WORK}/calls"
_m365_get() {
    case "$2" in
        */planner/tasks/task-1)
            printf 'x\n' >> "${WORK}/calls"
            if [ "$(wc -l < "${WORK}/calls")" -eq 1 ]; then printf '%s\n' "$CURRENT"; else printf '%s\n' "$CURRENT_AFTER"; fi ;;
        *) return 1 ;;
    esac
}
out="$(_m365_planner_update ut --task task-1 --progress done --due 2026-10-16 --execute)"
printf '%s\n' "$out" | grep -F -- "Updated task (confirmed by readback): Mine open" >/dev/null
grep -F -- 'PATCH' "${WORK}/writes.log" | grep -F -- 'If-Match: W/"etag-1"' >/dev/null
jq -e 'select(.action == "update-task") | .verified == true and .service == "m365-planner"' "$LIFEOS_MAIL_AUDIT_LOG" >/dev/null

# A readback that does not match fails loudly.
: > "${WORK}/calls"
CURRENT_AFTER="$CURRENT"
refute _m365_planner_update ut --task task-1 --progress done --execute >/dev/null 2>&1

printf 'm365 planner tests passed\n'
