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
ODOO_EXAMPLE_API_KEY="synthetic-test-key"
export ODOO_ACCOUNTS_PATH ODOO_EXAMPLE_API_KEY

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

if _odoo_tasks_get example not-a-number >/dev/null 2>&1; then
    printf 'expected non-numeric task id to fail\n' >&2
    exit 1
fi

printf 'odoo shell read fixtures passed\n'
