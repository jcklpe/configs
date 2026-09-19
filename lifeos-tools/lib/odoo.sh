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

_odoo_request_state_path() {
    if _var_is_set ODOO_REQUEST_STATE_PATH; then
        _path_value ODOO_REQUEST_STATE_PATH
    else
        printf '%s/cache/odoo-last-request\n' "$SECRETS_DIR"
    fi
}

_odoo_wait_for_request_slot() {
    local interval="${ODOO_MIN_REQUEST_INTERVAL_SECONDS:-5}" state now last elapsed wait_seconds state_dir
    case "$interval" in ''|*[!0-9]*) _err "ODOO_MIN_REQUEST_INTERVAL_SECONDS must be a non-negative integer"; return 1 ;; esac
    [ "$interval" -le 300 ] || { _err "ODOO_MIN_REQUEST_INTERVAL_SECONDS must not exceed 300"; return 1; }
    [ "$interval" -gt 0 ] || return 0

    state="$(_odoo_request_state_path)" || return 1
    state_dir="${state%/*}"
    [ "$state_dir" = "$state" ] || mkdir -p "$state_dir" || return 1
    now="$(date +%s)" || return 1
    if [ -f "$state" ]; then
        IFS= read -r last < "$state" || last=""
        case "$last" in
            ''|*[!0-9]*) ;;
            *)
                elapsed=$((now - last))
                if [ "$elapsed" -lt "$interval" ]; then
                    wait_seconds=$((interval - elapsed))
                    sleep "$wait_seconds" || return 1
                fi
                ;;
        esac
    fi
    date +%s > "$state"
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
    _odoo_wait_for_request_slot || return 1
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

_odoo_validate_date() {
    jq -en --arg value "$1" '$value | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")' >/dev/null || { _err "Date must use YYYY-MM-DD: $1"; return 1; }
}

_odoo_task_read_json() {
    local alias="$1" task="$2" fields body
    fields="$(_odoo_task_fields_json)"
    body="$(jq -cn --argjson task "$task" --argjson fields "$fields" '{ids: [$task], fields: $fields}')" || return 1
    _odoo_call "$alias" project.task read "$body"
}

_odoo_write_plan() {
    local plan="$1" json="$2"
    if [ "$json" -eq 1 ]; then
        printf '%s\n' "$plan"
    else
        _say "DRY RUN: no Odoo changes made"
        printf '%s\n' "$plan" | jq '.'
        _say "NEXT: review the exact IDs and fields, then rerun with --execute"
    fi
}

_odoo_tasks_create() {
    local alias="${1:-}" project="" name="" description="" description_file="" stage="" deadline="" assignees='[]' execute=0 json=0 vals plan body response task readback
    [ -n "$alias" ] || { _err "odoo tasks create requires ALIAS --project PROJECT_ID --name NAME"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --project) [ -n "${2:-}" ] || { _err "--project requires PROJECT_ID"; return 1; }; project="$2"; shift 2 ;;
            --name) [ -n "${2:-}" ] || { _err "--name requires NAME"; return 1; }; name="$2"; shift 2 ;;
            --description) [ -n "${2:-}" ] || { _err "--description requires TEXT"; return 1; }; description="$2"; shift 2 ;;
            --description-file) [ -n "${2:-}" ] || { _err "--description-file requires FILE"; return 1; }; description_file="$2"; shift 2 ;;
            --stage) [ -n "${2:-}" ] || { _err "--stage requires STAGE_ID"; return 1; }; stage="$2"; shift 2 ;;
            --assignee) [ -n "${2:-}" ] || { _err "--assignee requires USER_ID"; return 1; }; case "$2" in *[!0-9]*) _err "--assignee requires a numeric USER_ID"; return 1 ;; esac; assignees="$(printf '%s' "$assignees" | jq -c --argjson id "$2" '. + [$id] | unique')" || return 1; shift 2 ;;
            --deadline) [ -n "${2:-}" ] || { _err "--deadline requires YYYY-MM-DD"; return 1; }; deadline="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --json) json=1; shift ;;
            *) _err "Unknown tasks create option: $1"; return 1 ;;
        esac
    done
    case "$project" in ''|*[!0-9]*) _err "tasks create requires a numeric --project PROJECT_ID"; return 1 ;; esac
    [ -n "$name" ] || { _err "tasks create requires --name NAME"; return 1; }
    [ -z "$description_file" ] || [ -z "$description" ] || { _err "Use only one of --description or --description-file"; return 1; }
    if [ -n "$description_file" ]; then [ -f "$description_file" ] || { _err "Description file does not exist: $description_file"; return 1; }; description="$(cat "$description_file")"; fi
    case "$stage" in *[!0-9]*) _err "--stage requires a numeric STAGE_ID"; return 1 ;; esac
    [ -z "$deadline" ] || _odoo_validate_date "$deadline" || return 1
    vals="$(jq -cn --arg name "$name" --arg description "$description" --arg stage "$stage" --arg deadline "$deadline" --argjson project "$project" --argjson assignees "$assignees" '{name: $name, project_id: $project} + (if $description != "" then {description: $description} else {} end) + (if $stage != "" then {stage_id: ($stage | tonumber)} else {} end) + (if ($assignees | length) > 0 then {user_ids: [[6, 0, $assignees]]} else {} end) + (if $deadline != "" then {date_deadline: $deadline} else {} end)')" || return 1
    plan="$(jq -cn --arg alias "$alias" --argjson vals "$vals" '{action: "create task", account: $alias, values: $vals}')" || return 1
    if [ "$execute" -eq 0 ]; then _odoo_write_plan "$plan" "$json"; return; fi
    body="$(jq -cn --argjson vals "$vals" '{vals_list: [$vals]}')" || return 1
    response="$(_odoo_call "$alias" project.task create "$body")" || return 1
    task="$(printf '%s' "$response" | jq -er 'if type == "array" and length == 1 and (.[0] | type == "number") then .[0] else error("unexpected create response") end')" || { _err "Odoo returned an unexpected task-create response"; return 1; }
    readback="$(_odoo_task_read_json "$alias" "$task")" || return 1
    [ "$(printf '%s' "$readback" | jq 'length')" -eq 1 ] || { _err "Created task could not be read back: $task"; return 1; }
    if [ "$json" -eq 1 ]; then printf '%s\n' "$readback"; else printf '%s' "$readback" | _odoo_render_tasks; fi
}

_odoo_tasks_update() {
    local alias="${1:-}" task="${2:-}" name="" description="" description_file="" stage="" deadline="" assignees='[]' set_name=0 set_description=0 set_stage=0 set_deadline=0 set_assignees=0 clear_assignees=0 execute=0 json=0 vals plan body response readback
    [ -n "$alias" ] && [ -n "$task" ] || { _err "odoo tasks update requires ALIAS TASK_ID and at least one field"; return 1; }
    shift 2 || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name) [ -n "${2:-}" ] || { _err "--name requires NAME"; return 1; }; name="$2"; set_name=1; shift 2 ;;
            --description) [ -n "${2:-}" ] || { _err "--description requires TEXT"; return 1; }; description="$2"; set_description=1; shift 2 ;;
            --description-file) [ -n "${2:-}" ] || { _err "--description-file requires FILE"; return 1; }; description_file="$2"; set_description=1; shift 2 ;;
            --stage) [ -n "${2:-}" ] || { _err "--stage requires STAGE_ID"; return 1; }; stage="$2"; set_stage=1; shift 2 ;;
            --assignee) [ "$clear_assignees" -eq 0 ] || { _err "Use --assignee or --clear-assignees, not both"; return 1; }; [ -n "${2:-}" ] || { _err "--assignee requires USER_ID"; return 1; }; case "$2" in *[!0-9]*) _err "--assignee requires a numeric USER_ID"; return 1 ;; esac; assignees="$(printf '%s' "$assignees" | jq -c --argjson id "$2" '. + [$id] | unique')" || return 1; set_assignees=1; shift 2 ;;
            --clear-assignees) [ "$set_assignees" -eq 0 ] || { _err "Use --assignee or --clear-assignees, not both"; return 1; }; assignees='[]'; set_assignees=1; clear_assignees=1; shift ;;
            --deadline) [ "$set_deadline" -eq 0 ] || { _err "Use --deadline or --clear-deadline, not both"; return 1; }; [ -n "${2:-}" ] || { _err "--deadline requires YYYY-MM-DD"; return 1; }; deadline="$2"; set_deadline=1; shift 2 ;;
            --clear-deadline) [ "$set_deadline" -eq 0 ] || { _err "Use --deadline or --clear-deadline, not both"; return 1; }; deadline=false; set_deadline=1; shift ;;
            --execute) execute=1; shift ;;
            --json) json=1; shift ;;
            *) _err "Unknown tasks update option: $1"; return 1 ;;
        esac
    done
    case "$task" in ''|*[!0-9]*) _err "TASK_ID must be numeric"; return 1 ;; esac
    [ -z "$description_file" ] || [ -z "$description" ] || { _err "Use only one of --description or --description-file"; return 1; }
    if [ -n "$description_file" ]; then [ -f "$description_file" ] || { _err "Description file does not exist: $description_file"; return 1; }; description="$(cat "$description_file")"; fi
    if [ "$set_stage" -eq 1 ]; then case "$stage" in ''|*[!0-9]*) _err "--stage requires a numeric STAGE_ID"; return 1 ;; esac; fi
    if [ "$set_deadline" -eq 1 ] && [ "$deadline" != false ]; then _odoo_validate_date "$deadline" || return 1; fi
    [ $((set_name + set_description + set_stage + set_deadline + set_assignees)) -gt 0 ] || { _err "tasks update requires at least one changed field"; return 1; }
    vals="$(jq -cn --arg name "$name" --arg description "$description" --arg stage "$stage" --arg deadline "$deadline" --argjson assignees "$assignees" --argjson set_name "$set_name" --argjson set_description "$set_description" --argjson set_stage "$set_stage" --argjson set_deadline "$set_deadline" --argjson set_assignees "$set_assignees" '(if $set_name == 1 then {name: $name} else {} end) + (if $set_description == 1 then {description: $description} else {} end) + (if $set_stage == 1 then {stage_id: ($stage | tonumber)} else {} end) + (if $set_assignees == 1 then {user_ids: [[6, 0, $assignees]]} else {} end) + (if $set_deadline == 1 then {date_deadline: (if $deadline == "false" then false else $deadline end)} else {} end)')" || return 1
    plan="$(jq -cn --arg alias "$alias" --argjson task "$task" --argjson vals "$vals" '{action: "update task", account: $alias, task_id: $task, values: $vals}')" || return 1
    if [ "$execute" -eq 0 ]; then _odoo_write_plan "$plan" "$json"; return; fi
    body="$(jq -cn --argjson task "$task" --argjson vals "$vals" '{ids: [$task], vals: $vals}')" || return 1
    response="$(_odoo_call "$alias" project.task write "$body")" || return 1
    [ "$(printf '%s' "$response" | jq -r '.')" = true ] || { _err "Odoo did not confirm the task update"; return 1; }
    readback="$(_odoo_task_read_json "$alias" "$task")" || return 1
    [ "$(printf '%s' "$readback" | jq 'length')" -eq 1 ] || { _err "Updated task could not be read back: $task"; return 1; }
    if [ "$json" -eq 1 ]; then printf '%s\n' "$readback"; else printf '%s' "$readback" | _odoo_render_tasks; fi
}

_odoo_tasks_comment() {
    local alias="${1:-}" task="${2:-}" body_text="" body_file="" execute=0 json=0 plan body response readback
    [ -n "$alias" ] && [ -n "$task" ] || { _err "odoo tasks comment requires ALIAS TASK_ID --body TEXT"; return 1; }
    shift 2 || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --body) [ -n "${2:-}" ] || { _err "--body requires TEXT"; return 1; }; body_text="$2"; shift 2 ;;
            --body-file) [ -n "${2:-}" ] || { _err "--body-file requires FILE"; return 1; }; body_file="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --json) json=1; shift ;;
            *) _err "Unknown tasks comment option: $1"; return 1 ;;
        esac
    done
    case "$task" in ''|*[!0-9]*) _err "TASK_ID must be numeric"; return 1 ;; esac
    [ -z "$body_file" ] || [ -z "$body_text" ] || { _err "Use only one of --body or --body-file"; return 1; }
    if [ -n "$body_file" ]; then [ -f "$body_file" ] || { _err "Body file does not exist: $body_file"; return 1; }; body_text="$(cat "$body_file")"; fi
    [ -n "$body_text" ] || { _err "tasks comment requires --body TEXT or --body-file FILE"; return 1; }
    plan="$(jq -cn --arg alias "$alias" --argjson task "$task" --arg body "$body_text" '{action: "comment on task", account: $alias, task_id: $task, body: $body}')" || return 1
    if [ "$execute" -eq 0 ]; then _odoo_write_plan "$plan" "$json"; return; fi
    body="$(jq -cn --argjson task "$task" --arg body "$body_text" '{ids: [$task], body: $body, body_is_html: false, message_type: "comment", subtype_xmlid: "mail.mt_comment"}')" || return 1
    response="$(_odoo_call "$alias" project.task message_post "$body")" || return 1
    printf '%s' "$response" | jq -e '.' >/dev/null || { _err "Odoo returned an unexpected comment response"; return 1; }
    readback="$(_odoo_task_read_json "$alias" "$task")" || return 1
    [ "$(printf '%s' "$readback" | jq 'length')" -eq 1 ] || { _err "Commented task could not be read back: $task"; return 1; }
    if [ "$json" -eq 1 ]; then printf '%s\n' "$readback"; else printf '%s' "$readback" | _odoo_render_tasks; fi
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
                create) shift 2; _odoo_tasks_create "$@" ;;
                update) shift 2; _odoo_tasks_update "$@" ;;
                comment) shift 2; _odoo_tasks_comment "$@" ;;
                *) _err "Unknown odoo tasks command: ${2:-}"; return 1 ;;
            esac
            ;;
        *) _err "Unknown odoo command: ${1:-}"; return 1 ;;
    esac
}
