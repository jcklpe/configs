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
M365_PLANNER_AUDIT_LOG="${WORK}/audit.jsonl"
export M365_PLANNER_AUDIT_LOG

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
jq -e 'select(.action == "update-task") | .verified == true and .service == "m365-planner"' "$M365_PLANNER_AUDIT_LOG" >/dev/null

# A readback that does not match fails loudly.
: > "${WORK}/calls"
CURRENT_AFTER="$CURRENT"
refute _m365_planner_update ut --task task-1 --progress done --execute >/dev/null 2>&1

# Experimental moves use a single beta PATCH and preserve the task, rather than copying it.
jq '(.accounts[] | select(.alias == "ut") | .planner.plans) += [{id:"plan-2",name:"Destination"}]' "${WORK}/write.json" > "${WORK}/move.json"
M365_ACCOUNTS_PATH="${WORK}/move.json"
MOVE_CURRENT="$CURRENT"
MOVE_GROUP="group-1"
MOVE_BUCKET_PLAN="plan-2"
MOVE_FAIL=0
MOVE_LOSS=0
MOVE_READ_FAIL=0
MOVE_DETAILS='{"description":"notes","checklist":{"c1":{"title":"step","isChecked":false}},"references":{"https%3A//example.org":{"alias":"source"}}}'
_m365_get() {
    case "$2" in
        */beta/planner/tasks/task-1)
            if [ -f "${WORK}/moved" ]; then
                [ "$MOVE_READ_FAIL" -eq 0 ] || return 1
                printf '%s' "$MOVE_CURRENT" | jq --argjson loss "$MOVE_LOSS" '.planId="plan-2" | .bucketId="b2" | if $loss == 1 then .assignments={} else . end'
            else printf '%s\n' "$MOVE_CURRENT"; fi ;;
        */beta/planner/tasks/task-1/details) printf '%s\n' "$MOVE_DETAILS" ;;
        */beta/planner/plans/plan-1) printf '%s\n' '{"id":"plan-1","title":"Source","container":{"type":"group","containerId":"group-1"}}' ;;
        */beta/planner/plans/plan-2) jq -nc --arg g "$MOVE_GROUP" '{id:"plan-2",title:"Destination",container:{type:"group",containerId:$g}}' ;;
        */beta/planner/buckets/b2) jq -nc --arg p "$MOVE_BUCKET_PLAN" '{id:"b2",name:"To do",planId:$p}' ;;
        *) return 1 ;;
    esac
}
_m365_http() {
    printf '%s %s %s %s\n' "$1" "$3" "$4" "${6:-}" >> "${WORK}/move-writes.log"
    [ "$MOVE_FAIL" -eq 0 ] || return 1
    touch "${WORK}/moved"
}
# Dry run, argument validation, both allowlists, bucket ownership, group, and ETag gates.
out="$(_m365_planner_dispatch move-task ut --task task-1 --plan plan-2 --bucket b2)"
printf '%s\n' "$out" | grep -F 'DRY RUN: nothing was moved' >/dev/null
refute _m365_planner_move ut --task task-1 --plan plan-2 >/dev/null 2>&1
refute _m365_planner_move ut --task task-1 --plan plan-3 --bucket b2 >/dev/null 2>&1
MOVE_CURRENT="$(printf '%s' "$CURRENT" | jq '.planId="unlisted"')"
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 >/dev/null 2>&1
MOVE_CURRENT="$CURRENT"
MOVE_BUCKET_PLAN="plan-1"
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 >/dev/null 2>&1
MOVE_BUCKET_PLAN="plan-2"
MOVE_GROUP="other-group"
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 >/dev/null 2>&1
MOVE_GROUP="group-1"
for field in 'del(."@odata.etag")' '.appliedCategories={category1:true}' '.recurrence={}' '.creationSource={}' '.planId="plan-2"'; do
    MOVE_CURRENT="$(printf '%s' "$CURRENT" | jq "$field")"
    refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 >/dev/null 2>&1
done
MOVE_CURRENT="$CURRENT"
jq '(.accounts[] | select(.alias == "ut") | .planner.write_enabled)=false' "${WORK}/move.json" > "${WORK}/move-read.json"
M365_ACCOUNTS_PATH="${WORK}/move-read.json"
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 --execute >/dev/null 2>&1
[ ! -f "${WORK}/move-writes.log" ]
M365_ACCOUNTS_PATH="${WORK}/move.json"
out="$(_m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 --execute)"
printf '%s\n' "$out" | grep -F 'Moved task (confirmed by readback)' >/dev/null
[ "$(wc -l < "${WORK}/move-writes.log" | tr -d ' ')" = 1 ]
grep -F 'PATCH https://graph.microsoft.com/beta/planner/tasks/task-1 {"planId":"plan-2","bucketId":"b2"} If-Match: W/"etag-1"' "${WORK}/move-writes.log" >/dev/null
jq -se 'any(.[]; .action == "move-task" and .verified == true and .changes.from.planId == "plan-1")' "$M365_PLANNER_AUDIT_LOG" >/dev/null
# Refused/ambiguous writes never retry; data loss and unavailable readback never report success.
rm "${WORK}/moved"
MOVE_FAIL=1
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 --execute >/dev/null 2>&1
[ "$(wc -l < "${WORK}/move-writes.log" | tr -d ' ')" = 2 ]
MOVE_FAIL=0
MOVE_LOSS=1
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 --execute >/dev/null 2>&1
jq -se 'any(.[]; .action == "move-task" and .verified == false)' "$M365_PLANNER_AUDIT_LOG" >/dev/null
rm "${WORK}/moved"
MOVE_LOSS=0
MOVE_READ_FAIL=1
refute _m365_planner_move ut --task task-1 --plan plan-2 --bucket b2 --execute >/dev/null 2>&1
# Existing label names, merged state, concurrency and failure handling use no network.
M365_ACCOUNTS_PATH="${WORK}/write.json"
LABELS='{"categoryDescriptions":{"category1":"Urgent","category2":"Blocked","category3":null,"@odata.type":"ignored"}}'
LABEL_CURRENT='{"id":"task-1","planId":"plan-1","title":"Mine open","bucketId":"b1","percentComplete":0,"assignments":{"user-me":{}},"appliedCategories":{"category1":true},"@odata.etag":"W/\"label-etag\""}'
LABEL_FAIL=0 LABEL_LOSS=0 LABEL_READ_FAIL=0 LABEL_RENAME=0
_m365_get() {
    case "$2" in
        */planner/tasks/task-1)
            if [ -f "${WORK}/label-written" ]; then
                [ "$LABEL_READ_FAIL" -eq 0 ] || return 1
                jq --argjson b "$LABEL_CURRENT" --argjson loss "$LABEL_LOSS" '$b + . + {"@odata.etag":"new"} | if $loss == 1 then .bucketId="lost" else . end | .appliedCategories |= with_entries(select(.value == true))' "${WORK}/label-patch"
            else printf '%s\n' "$LABEL_CURRENT"; fi ;;
        */planner/plans/plan-1/details)
            printf 'x\n' >> "${WORK}/label-name-reads"
            if [ "$LABEL_RENAME" -eq 1 ] && [ "$(wc -l < "${WORK}/label-name-reads")" -gt 1 ]; then printf '%s' "$LABELS" | jq '.categoryDescriptions.category2="Renamed"'; else printf '%s\n' "$LABELS"; fi ;;
        *) return 1 ;;
    esac
}
_m365_http() {
    printf '%s %s %s %s\n' "$1" "$3" "$4" "${6:-}" >> "${WORK}/label-writes"
    [ "$LABEL_FAIL" -eq 0 ] || return 1
    printf '%s' "$4" > "${WORK}/label-patch"
    touch "${WORK}/label-written"
}
reset_labels() { rm -f "${WORK}/label-written" "${WORK}/label-patch" "${WORK}/label-writes"; : > "${WORK}/label-name-reads"; }
reset_labels
out="$(_m365_planner_dispatch labels ut --plan plan-1 --json)"
printf '%s' "$out" | jq -e 'length == 2 and .[1] == {id:"category2",name:"Blocked"}' >/dev/null
refute _m365_planner_dispatch labels ut --json >/dev/null 2>&1
refute _m365_planner_dispatch label ut --task task-1 >/dev/null 2>&1
refute _m365_planner_dispatch label ut --task task-1 --label Missing --execute >/dev/null 2>&1
LABELS_DUP="$LABELS"
LABELS="$(printf '%s' "$LABELS" | jq '.categoryDescriptions.category3="BLOCKED"')"
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
LABELS="$LABELS_DUP"
[ ! -f "${WORK}/label-writes" ]
out="$(_m365_planner_dispatch label ut --task task-1 --label blocked)"
printf '%s' "$out" | grep -F 'DRY RUN' >/dev/null
[ ! -f "${WORK}/label-writes" ]
M365_ACCOUNTS_PATH="${WORK}/read.json"
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
M365_ACCOUNTS_PATH="${WORK}/write.json"
LABEL_SAVED="$LABEL_CURRENT"
LABEL_CURRENT="$(printf '%s' "$LABEL_CURRENT" | jq '.planId="not-allowed"')"
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
LABEL_CURRENT="$LABEL_SAVED"
reset_labels
LABEL_RENAME=1
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
[ ! -f "${WORK}/label-writes" ]
LABEL_RENAME=0
reset_labels
out="$(_m365_planner_dispatch label ut --task task-1 --label Blocked --execute)"
printf '%s' "$out" | grep -F 'confirmed by readback' >/dev/null
jq -e '. == {appliedCategories:{category1:true,category2:true}}' "${WORK}/label-patch" >/dev/null
grep -F 'If-Match: W/"label-etag"' "${WORK}/label-writes" >/dev/null
[ "$(wc -l < "${WORK}/label-writes" | tr -d ' ')" = 1 ]
jq -se 'any(.[]; .action == "label" and .verified == true)' "$M365_PLANNER_AUDIT_LOG" >/dev/null
# Duplicate application reads current state and performs no second PATCH.
out="$(_m365_planner_dispatch label ut --task task-1 --label Blocked --execute)"
printf '%s' "$out" | grep -F 'No change' >/dev/null
[ "$(wc -l < "${WORK}/label-writes" | tr -d ' ')" = 1 ]
# Removing one label preserves all other labels; omitted false readback is valid.
LABEL_CURRENT="$(printf '%s' "$LABEL_CURRENT" | jq '.appliedCategories.category2=true')"
reset_labels
_m365_planner_dispatch unlabel ut --task task-1 --label Blocked --execute >/dev/null
jq -e '. == {appliedCategories:{category1:true,category2:false}}' "${WORK}/label-patch" >/dev/null
LABEL_CURRENT="$LABEL_SAVED"
reset_labels
LABEL_FAIL=1
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
[ "$(wc -l < "${WORK}/label-writes" | tr -d ' ')" = 1 ]
LABEL_FAIL=0
reset_labels
LABEL_LOSS=1
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
LABEL_LOSS=0
reset_labels
LABEL_READ_FAIL=1
refute _m365_planner_dispatch label ut --task task-1 --label Blocked --execute >/dev/null 2>&1
LABEL_READ_FAIL=0
reset_labels
# Label support does not add group-conversation permissions to configured scope requests.
lacks "$(_m365_scopes ut)" 'Group.'
lacks "$(_m365_scopes ut)" 'Group-Conversation.'
[ ! -f "${WORK}/label-writes" ]

printf 'm365 planner tests passed\n'
