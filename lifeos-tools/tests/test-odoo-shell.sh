#!/usr/bin/env bash
##- Test the bounded Odoo command surface without network access.

set -eu

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${TEST_DIR}/.." && pwd)"
SCRIPT_DIR="$TOOL_DIR"
CONFIGS="$(cd "${TOOL_DIR}/.." && pwd)"
LIB_DIR="${TOOL_DIR}/lib"
SECRETS_DIR="${TOOL_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"
ODOO_ACCOUNTS_PATH="${SECRETS_DIR}/odoo-accounts.example.json"
ODOO_API_KEY="synthetic-test-key"
ODOO_MIN_REQUEST_INTERVAL_SECONDS=0
ODOO_REQUEST_STATE_PATH="${TMPDIR:-/tmp}/odoo-test-last-request"
export ODOO_ACCOUNTS_PATH ODOO_API_KEY ODOO_MIN_REQUEST_INTERVAL_SECONDS ODOO_REQUEST_STATE_PATH

. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/odoo.sh"

PROJECTS_OUT="${TMPDIR:-/tmp}/odoo-projects-test.txt"
STAGES_OUT="${TMPDIR:-/tmp}/odoo-stages-test.txt"
TASKS_OUT="${TMPDIR:-/tmp}/odoo-tasks-test.txt"
BODY_OUT="${TMPDIR:-/tmp}/odoo-body-test.json"

_odoo_http() {
    printf '%s' "$3" > "$BODY_OUT"
    case "$2" in
        */project.project/search_read) cat "${TEST_DIR}/fixtures/odoo-projects.json" ;;
        */project.task.type/search_read) cat "${TEST_DIR}/fixtures/odoo-stages.json" ;;
        */project.task/search_read|*/project.task/read) cat "${TEST_DIR}/fixtures/odoo-tasks.json" ;;
        */mail.message/search_read) cat "${TEST_DIR}/fixtures/odoo-comments.json" ;;
        */project.task/create) printf '%s' "$3" > "${BODY_OUT}.create"; printf '[42]\n' ;;
        */project.task/write) printf '%s' "$3" > "${BODY_OUT}.write"; printf 'true\n' ;;
        */project.task/message_post) printf '%s' "$3" > "${BODY_OUT}.comment"; printf '{"id":99}\n' ;;
        *) return 1 ;;
    esac
}

_odoo_projects_list example > "$PROJECTS_OUT"
grep -F -- "project_id: 1" "$PROJECTS_OUT" >/dev/null
grep -F -- "owner: Ada Lovelace" "$PROJECTS_OUT" >/dev/null

_odoo_stages_list example --project 1 > "$STAGES_OUT"
grep -F -- "stage_id: 10" "$STAGES_OUT" >/dev/null
jq -e '.domain == ["|", ["project_ids", "=", false], ["project_ids", "in", [1]]]' "$BODY_OUT" >/dev/null

_odoo_tasks_list example --project 1 --stage 10 --limit 25 > "$TASKS_OUT"
grep -F -- "task_id: 42" "$TASKS_OUT" >/dev/null
grep -F -- "stage: Backlog" "$TASKS_OUT" >/dev/null
jq -e '.domain == [["project_id", "=", 1], ["stage_id", "=", 10]] and .limit == 25' "$BODY_OUT" >/dev/null

_odoo_tasks_find example brief --project 1 > "$TASKS_OUT"
jq -e '.domain == [["project_id", "=", 1], ["name", "ilike", "brief"]]' "$BODY_OUT" >/dev/null

_odoo_tasks_get example 42 --json > "$TASKS_OUT"
jq -e '.[0].id == 42' "$TASKS_OUT" >/dev/null
jq -e '.ids == [42]' "$BODY_OUT" >/dev/null

_odoo_tasks_comments example 42 --limit 5 > "$TASKS_OUT"
grep -F -- "comment_id: 99" "$TASKS_OUT" >/dev/null
grep -F -- "body: Progress note" "$TASKS_OUT" >/dev/null
jq -e '.domain == [["model", "=", "project.task"], ["res_id", "=", 42], ["message_type", "=", "comment"]] and .limit == 5' "$BODY_OUT" >/dev/null

_odoo_tasks_create example --project 1 --name "Draft task" --stage 10 --assignee 7 --deadline 2026-10-01 --json > "$TASKS_OUT"
jq -e '.action == "create task" and .account == "example" and .values.project_id == 1 and .values.stage_id == 10 and .values.user_ids == [[6,0,[7]]] and .values.date_deadline == "2026-10-01"' "$TASKS_OUT" >/dev/null
_odoo_tasks_create example --project 1 --name "Created task" --description "Bounded context" --execute --json > "$TASKS_OUT"
jq -e '.vals_list == [{name: "Created task", project_id: 1, description: "Bounded context"}]' "${BODY_OUT}.create" >/dev/null
jq -e '.[0].id == 42' "$TASKS_OUT" >/dev/null

_odoo_tasks_update example 42 --stage 11 --clear-assignees --clear-deadline --json > "$TASKS_OUT"
jq -e '.action == "update task" and .task_id == 42 and .values == {stage_id: 11, user_ids: [[6,0,[]]], date_deadline: false}' "$TASKS_OUT" >/dev/null
_odoo_tasks_update example 42 --name "Updated task" --execute --json > "$TASKS_OUT"
jq -e '.ids == [42] and .vals == {name: "Updated task"}' "${BODY_OUT}.write" >/dev/null
jq -e '.[0].id == 42' "$TASKS_OUT" >/dev/null
if _odoo_tasks_update example 42 --assignee 7 --clear-assignees >/dev/null 2>&1; then
    printf 'expected conflicting assignee options to fail\n' >&2
    exit 1
fi
if _odoo_tasks_update example 42 --deadline 2026-10-01 --clear-deadline >/dev/null 2>&1; then
    printf 'expected conflicting deadline options to fail\n' >&2
    exit 1
fi

_odoo_tasks_comment example 42 --body "Progress note" --json > "$TASKS_OUT"
jq -e '.action == "comment on task" and .task_id == 42 and .body == "Progress note"' "$TASKS_OUT" >/dev/null
_odoo_tasks_comment example 42 --body "Progress note" --execute --json > "$TASKS_OUT"
jq -e '.ids == [42] and .body == "Progress note" and .body_is_html == false and .message_type == "comment" and .subtype_xmlid == "mail.mt_comment"' "${BODY_OUT}.comment" >/dev/null
jq -e '.[0].id == 42' "$TASKS_OUT" >/dev/null

if _odoo_tasks_get example not-a-number >/dev/null 2>&1; then
    printf 'expected non-numeric task id to fail\n' >&2
    exit 1
fi

ODOO_MIN_REQUEST_INTERVAL_SECONDS=invalid
if _odoo_projects_list example >/dev/null 2>&1; then
    printf 'expected invalid request interval to fail\n' >&2
    exit 1
fi

printf 'odoo shell read fixtures passed\n'
