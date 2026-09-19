#!/usr/bin/env bash
##- Bounded Odoo JSON-2 client for project and task reads.

_odoo_accounts_path() {
    if _var_is_set ODOO_ACCOUNTS_PATH; then
        _path_value ODOO_ACCOUNTS_PATH
    else
        printf '%s/odoo-accounts.json\n' "$SECRETS_DIR"
    fi
}

_odoo_accounts_ready() {
    local config
    config="$(_odoo_accounts_path)"
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    if [ ! -f "$config" ]; then
        _err "Odoo account config does not exist: $config"
        _say "NEXT: cp ${SECRETS_DIR}/odoo-accounts.example.json $config"
        return 1
    fi
    jq -e '.accounts | type == "array"' "$config" >/dev/null 2>&1 || { _err "Odoo account config must contain an accounts array"; return 1; }
}

_odoo_account_exists() {
    local alias="$1"
    _odoo_accounts_ready || return 1
    jq -e --arg alias "$alias" 'any(.accounts[]?; .alias == $alias)' "$(_odoo_accounts_path)" >/dev/null
}

_odoo_account_value() {
    local alias="$1" filter="$2"
    jq -er --arg alias "$alias" "(.accounts[]? | select(.alias == \$alias) | ${filter}) // empty" "$(_odoo_accounts_path)"
}

_odoo_accounts_list() {
    _odoo_accounts_ready || return 1
    jq -r '(.accounts // [])[] | "- " + (.alias // "missing-alias") + " | url: " + (.base_url // "missing-url") + " | database: " + (.database // "(host-routed)") + " | key env: " + (.api_key_env // "missing")' "$(_odoo_accounts_path)"
}

_odoo_base_url() {
    local alias="$1" value
    value="$(_odoo_account_value "$alias" '.base_url')" || { _err "Odoo alias '$alias' needs base_url"; return 1; }
    case "$value" in https://*) ;; *) _err "Odoo base_url must use https://"; return 1 ;; esac
    printf '%s\n' "${value%/}"
}

_odoo_api_key() {
    local alias="$1" key_env value
    key_env="$(_odoo_account_value "$alias" '.api_key_env')" || { _err "Odoo alias '$alias' needs api_key_env"; return 1; }
    case "$key_env" in ''|*[!A-Za-z0-9_]*) _err "Invalid Odoo api_key_env for alias '$alias'"; return 1 ;; esac
    eval "value=\${${key_env}:-}"
    [ -n "$value" ] || { _err "$key_env is not set"; return 1; }
    printf '%s' "$value"
}

_odoo_http() {
    local alias="$1" path="$2" body="$3" base key database response http_code message
    _odoo_account_exists "$alias" || { _err "Unknown Odoo account alias: $alias"; return 1; }
    base="$(_odoo_base_url "$alias")" || return 1
    key="$(_odoo_api_key "$alias")" || return 1
    database="$(_odoo_account_value "$alias" '.database')" || database=""
    response="$(mktemp "${TMPDIR:-/tmp}/odoo-response.XXXXXX")" || return 1
    if [ -n "$database" ]; then
        http_code="$(curl -sS -o "$response" -w '%{http_code}' -X POST "${base}${path}" -H "Authorization: bearer ${key}" -H 'Content-Type: application/json; charset=utf-8' -H "X-Odoo-Database: ${database}" -H 'User-Agent: bounded-odoo-cli/1.0' --data-binary "$body")" || { rm -f "$response"; _err "Odoo request failed before receiving a response"; return 1; }
    else
        http_code="$(curl -sS -o "$response" -w '%{http_code}' -X POST "${base}${path}" -H "Authorization: bearer ${key}" -H 'Content-Type: application/json; charset=utf-8' -H 'User-Agent: bounded-odoo-cli/1.0' --data-binary "$body")" || { rm -f "$response"; _err "Odoo request failed before receiving a response"; return 1; }
    fi
    case "$http_code" in
        2??) cat "$response"; rm -f "$response" ;;
        *)
            message="$(jq -r '.message // .error.message // .error.data.message // empty' "$response" 2>/dev/null)"
            [ -n "$message" ] || message="Odoo returned HTTP $http_code"
            rm -f "$response"
            _err "$message"
            return 1
            ;;
    esac
}

_odoo_call() {
    local alias="$1" model="$2" method="$3" body="$4"
    _odoo_http "$alias" "/json/2/${model}/${method}" "$body"
}

_odoo_relation_label_filter='def relation_label: if . == null or . == false then "" elif type == "array" then ((.[1] // .[0] // "") | tostring) elif type == "object" then ((.display_name // .name // .id // "") | tostring) else tostring end;'

_odoo_render_projects() {
    jq -r "${_odoo_relation_label_filter} .[] | \"- \" + (.name // \"(unnamed)\") + \"\\n  project_id: \" + (.id | tostring) + \"\\n  visibility: \" + (.privacy_visibility // \"?\") + \"\\n  owner: \" + (.user_id | relation_label)"
}

_odoo_render_stages() {
    jq -r '.[] | "- " + (.name // "(unnamed)") + "\n  stage_id: " + (.id | tostring) + "\n  sequence: " + ((.sequence // 0) | tostring) + "\n  folded: " + ((.fold // false) | tostring)'
}

_odoo_render_tasks() {
    jq -r "${_odoo_relation_label_filter} .[] | \"- \" + (.name // \"(unnamed)\") + \"\\n  task_id: \" + (.id | tostring) + \"\\n  project: \" + (.project_id | relation_label) + \"\\n  stage: \" + (.stage_id | relation_label) + \"\\n  assignees: \" + ((.user_ids // []) | map(tostring) | join(\", \")) + \"\\n  deadline: \" + (.date_deadline // \"\") + \"\\n  updated: \" + (.write_date // \"\")"
}

_odoo_projects_list() {
    local alias="${1:-}" json=0 response body
    [ -n "$alias" ] || { _err "odoo projects list requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --json) json=1; shift ;; *) _err "Unknown projects list option: $1"; return 1 ;; esac; done
    body="$(jq -cn '{domain: [["active", "=", true]], fields: ["id", "name", "privacy_visibility", "user_id"], limit: 100, order: "name"}')" || return 1
    response="$(_odoo_call "$alias" project.project search_read "$body")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _odoo_render_projects; fi
}

_odoo_stages_list() {
    local alias="${1:-}" project="" json=0 response body
    [ -n "$alias" ] || { _err "odoo stages list requires ALIAS --project PROJECT_ID"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --project) [ -n "${2:-}" ] || { _err "--project requires PROJECT_ID"; return 1; }; project="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) _err "Unknown stages list option: $1"; return 1 ;;
        esac
    done
    case "$project" in ''|*[!0-9]*) _err "stages list requires a numeric --project PROJECT_ID"; return 1 ;; esac
    body="$(jq -cn --argjson project "$project" '{domain: ["|", ["project_ids", "=", false], ["project_ids", "in", [$project]]], fields: ["id", "name", "sequence", "fold"], limit: 100, order: "sequence,id"}')" || return 1
    response="$(_odoo_call "$alias" project.task.type search_read "$body")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _odoo_render_stages; fi
}

_odoo_task_fields_json() {
    printf '%s\n' '["id","name","project_id","stage_id","user_ids","date_deadline","description","active","write_date"]'
}

_odoo_tasks_list() {
    local alias="${1:-}" project="" stage="" limit=100 json=0 response body fields
    [ -n "$alias" ] || { _err "odoo tasks list requires ALIAS --project PROJECT_ID"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --project) [ -n "${2:-}" ] || { _err "--project requires PROJECT_ID"; return 1; }; project="$2"; shift 2 ;;
            --stage) [ -n "${2:-}" ] || { _err "--stage requires STAGE_ID"; return 1; }; stage="$2"; shift 2 ;;
            --limit) [ -n "${2:-}" ] || { _err "--limit requires COUNT"; return 1; }; limit="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) _err "Unknown tasks list option: $1"; return 1 ;;
        esac
    done
    case "$project" in ''|*[!0-9]*) _err "tasks list requires a numeric --project PROJECT_ID"; return 1 ;; esac
    case "$limit" in ''|*[!0-9]*) _err "--limit requires a positive integer"; return 1 ;; esac
    [ "$limit" -gt 0 ] && [ "$limit" -le 500 ] || { _err "--limit must be between 1 and 500"; return 1; }
    fields="$(_odoo_task_fields_json)"
    if [ -n "$stage" ]; then
        case "$stage" in *[!0-9]*) _err "--stage requires a numeric STAGE_ID"; return 1 ;; esac
        body="$(jq -cn --argjson project "$project" --argjson stage "$stage" --argjson limit "$limit" --argjson fields "$fields" '{domain: [["project_id", "=", $project], ["stage_id", "=", $stage]], fields: $fields, limit: $limit, order: "sequence,id"}')" || return 1
    else
        body="$(jq -cn --argjson project "$project" --argjson limit "$limit" --argjson fields "$fields" '{domain: [["project_id", "=", $project]], fields: $fields, limit: $limit, order: "sequence,id"}')" || return 1
    fi
    response="$(_odoo_call "$alias" project.task search_read "$body")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _odoo_render_tasks; fi
}

_odoo_tasks_find() {
    local alias="${1:-}" query="${2:-}" project="" json=0 response body fields
    [ -n "$alias" ] && [ -n "$query" ] || { _err "odoo tasks find requires ALIAS QUERY --project PROJECT_ID"; return 1; }
    shift 2 || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --project) [ -n "${2:-}" ] || { _err "--project requires PROJECT_ID"; return 1; }; project="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) _err "Unknown tasks find option: $1"; return 1 ;;
        esac
    done
    case "$project" in ''|*[!0-9]*) _err "tasks find requires a numeric --project PROJECT_ID"; return 1 ;; esac
    fields="$(_odoo_task_fields_json)"
    body="$(jq -cn --argjson project "$project" --arg query "$query" --argjson fields "$fields" '{domain: [["project_id", "=", $project], ["name", "ilike", $query]], fields: $fields, limit: 50, order: "name,id"}')" || return 1
    response="$(_odoo_call "$alias" project.task search_read "$body")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _odoo_render_tasks; fi
}

_odoo_tasks_get() {
    local alias="${1:-}" task="${2:-}" json=0 response body fields
    [ -n "$alias" ] && [ -n "$task" ] || { _err "odoo tasks get requires ALIAS TASK_ID"; return 1; }
    shift 2 || true
    while [ "$#" -gt 0 ]; do case "$1" in --json) json=1; shift ;; *) _err "Unknown tasks get option: $1"; return 1 ;; esac; done
    case "$task" in *[!0-9]*) _err "TASK_ID must be numeric"; return 1 ;; esac
    fields="$(_odoo_task_fields_json)"
    body="$(jq -cn --argjson task "$task" --argjson fields "$fields" '{ids: [$task], fields: $fields}')" || return 1
    response="$(_odoo_call "$alias" project.task read "$body")" || return 1
    [ "$(printf '%s' "$response" | jq 'length')" -eq 1 ] || { _err "Odoo task not found: $task"; return 1; }
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _odoo_render_tasks; fi
}

_odoo_dispatch() {
    case "${1:-}" in
        accounts) shift; _odoo_accounts_list "$@" ;;
        projects)
            case "${2:-}" in list) shift 2; _odoo_projects_list "$@" ;; *) _err "Unknown odoo projects command: ${2:-}"; return 1 ;; esac
            ;;
        stages)
            case "${2:-}" in list) shift 2; _odoo_stages_list "$@" ;; *) _err "Unknown odoo stages command: ${2:-}"; return 1 ;; esac
            ;;
        tasks)
            case "${2:-}" in
                list) shift 2; _odoo_tasks_list "$@" ;;
                find) shift 2; _odoo_tasks_find "$@" ;;
                get) shift 2; _odoo_tasks_get "$@" ;;
                *) _err "Unknown odoo tasks command: ${2:-}"; return 1 ;;
            esac
            ;;
        *) _err "Unknown odoo command: ${1:-}"; return 1 ;;
    esac
}
