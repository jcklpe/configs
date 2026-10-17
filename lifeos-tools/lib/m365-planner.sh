#!/usr/bin/env bash
##- LifeOS Microsoft 365 Planner: list plans, buckets, and tasks, snapshot configured plans into the vault, and make dry-run-gated task creates and updates on allowlisted plans (never delete).
##- Sourced by lifeos.sh after m365.sh; reuses its Graph transport, batching, and account config. Decision record: docs/decisions/0008-lifeos-m365-planner.md.

_m365_planner_max_tasks() {
    _m365_account_value "$1" '.planner.max_tasks // 500' 2>/dev/null || printf '500'
}

_m365_planner_configured_ids() {
    _m365_account_value "$1" '(.planner.plans // [])[] | .id' 2>/dev/null || true
}

_m365_planner_require_plan_allowed() {
    local alias="$1" plan_id="$2"
    if ! _m365_planner_configured_ids "$alias" | grep -qxF -- "$plan_id"; then
        _err "Plan $plan_id is not in planner.plans for alias '$alias'; writes are limited to configured plans"
        _say "NEXT: add {\"id\": \"$plan_id\", \"name\": \"...\"} to planner.plans in $(_m365_accounts_path)" >&2
        return 1
    fi
}

_m365_planner_require_write() {
    local alias="$1"
    if ! _m365_account_value "$alias" '(.planner.write_enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Microsoft 365 Planner writes are not enabled for alias '$alias'"
        _say "NEXT: set planner.write_enabled to true for '$alias' in $(_m365_accounts_path), (the session already requests Tasks.ReadWrite)" >&2
        return 1
    fi
}

_m365_planner_url() {
    printf '%s/%s\n' "$(_m365_graph_base "$1")" "$2"
}

_m365_planner_my_id() {
    _m365_profile_json "$1" | jq -r '.id // empty'
}

# Resolve an assignee argument to a Graph user ID: "me", a user ID (GUID), or an email/UPN looked up exactly.
_m365_planner_resolve_user() {
    local alias="$1" who="$2" user
    case "$who" in
        me) _m365_planner_my_id "$alias"; return ;;
        *@*)
            user="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "users/$(_m365_uri_encode "$who")")" --data-urlencode '$select=id,displayName')" || { _err "No user found for $who"; return 1; }
            printf '%s' "$user" | jq -r '.id'
            ;;
        *)
            if printf '%s' "$who" | grep -Eqi '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
                printf '%s\n' "$who"
            else
                _err "Assignee must be 'me', an email address, or a Graph user ID (got: $who)"
                return 1
            fi
            ;;
    esac
}

_m365_planner_plans() {
    local alias="${1:-}" json_mode=0 data
    [ -n "$alias" ] || { _err "m365 planner plans requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --json) json_mode=1; shift ;; *) _err "Unknown m365 planner plans option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" planner || return 1
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-planner-plans.XXXXXX")" || return 1
    _m365_get_paginated "$alias" 200 "$data" "$(_m365_planner_url "$alias" "me/planner/plans")" || return 1
    if [ "$json_mode" -eq 1 ]; then cat "$data"; return 0; fi
    jq -r --argjson configured "$(_m365_planner_configured_ids "$alias" | jq -R . | jq -sc .)" '
      (.value // [])[] |
      "- " + (.title // "(untitled plan)") + " | plan_id: " + (.id // "") + " | group: " + (.container.containerId // .owner // "") + (.id as $id | if ($configured | index($id)) then " | configured" else "" end)
    ' "$data"
}

_m365_planner_buckets() {
    local alias="${1:-}" plan_id="" json_mode=0 data
    [ -n "$alias" ] || { _err "m365 planner buckets requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --plan) [ -n "${2:-}" ] || { _err "--plan requires ID"; return 1; }; plan_id="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 planner buckets option: $1"; return 1 ;;
        esac
    done
    [ -n "$plan_id" ] || { _err "m365 planner buckets requires --plan ID"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-planner-buckets.XXXXXX")" || return 1
    _m365_get_paginated "$alias" 200 "$data" "$(_m365_planner_url "$alias" "planner/plans/$(_m365_uri_encode "$plan_id")/buckets")" || return 1
    if [ "$json_mode" -eq 1 ]; then cat "$data"; return 0; fi
    jq -r '(.value // []) | sort_by(.orderHint // "")[] | "- " + (.name // "(unnamed bucket)") + " | bucket_id: " + (.id // "")' "$data"
}

# Write one plan's plan, details, buckets, tasks, and task details to OUT as a single JSON object.
_m365_planner_fetch_plan() {
    local alias="$1" plan_id="$2" out="$3" dir encoded max
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-planner-plan.XXXXXX")" || return 1
    encoded="$(_m365_uri_encode "$plan_id")"
    max="$(_m365_planner_max_tasks "$alias")"
    _m365_get "$alias" "$(_m365_planner_url "$alias" "planner/plans/${encoded}")" > "${dir}/plan.json" || return 1
    _m365_get "$alias" "$(_m365_planner_url "$alias" "planner/plans/${encoded}/details")" > "${dir}/details.json" || return 1
    _m365_get_paginated "$alias" 200 "${dir}/buckets.json" "$(_m365_planner_url "$alias" "planner/plans/${encoded}/buckets")" || return 1
    _m365_get_paginated "$alias" "$max" "${dir}/tasks.json" "$(_m365_planner_url "$alias" "planner/plans/${encoded}/tasks")" || return 1
    # Details (description, checklist) cost one request per task, so only tasks that have them are fetched, 20 per batch.
    jq '[(.value // [])[] | select((.hasDescription // false) or ((.checklistItemCount // 0) > 0)) | {method: "GET", url: ("/planner/tasks/" + (.id | @uri) + "/details")}]' "${dir}/tasks.json" > "${dir}/detail-requests.json" || return 1
    _m365_batch "$alias" "${dir}/detail-requests.json" "${dir}/detail-responses.json" || return 1
    jq -n \
        --slurpfile plan "${dir}/plan.json" \
        --slurpfile details "${dir}/details.json" \
        --slurpfile buckets "${dir}/buckets.json" \
        --slurpfile tasks "${dir}/tasks.json" \
        --slurpfile taskDetails "${dir}/detail-responses.json" \
        '{plan: $plan[0], details: $details[0], buckets: ($buckets[0].value // []), tasks: ($tasks[0].value // []),
          taskDetails: ([$taskDetails[0][] | select(.status == 200) | {key: .body.id, value: .body}] | from_entries)}' > "$out"
}

# Write {userId: {displayName, mail}} for every user named in the plans' assignments, creators, and completers.
_m365_planner_fetch_users() {
    local alias="$1" plans_file="$2" out="$3" dir
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-planner-users.XXXXXX")" || return 1
    jq '[.[] | .tasks[] | ((.assignments // {}) | keys[]), (.createdBy.user.id // empty), (.completedBy.user.id // empty)] | unique | map({method: "GET", url: ("/users/" + (. | @uri) + "?$select=id,displayName,mail")})' "$plans_file" > "${dir}/requests.json" || return 1
    _m365_batch "$alias" "${dir}/requests.json" "${dir}/responses.json" || return 1
    jq '[.[] | select(.status == 200) | {key: .body.id, value: {displayName: .body.displayName, mail: .body.mail}}] | from_entries' "${dir}/responses.json" > "$out"
}

_m365_planner_tasks() {
    local alias="${1:-}" plan_id="" bucket="" mine=0 open_only=0 json_mode=0 dir me
    [ -n "$alias" ] || { _err "m365 planner tasks requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --plan) [ -n "${2:-}" ] || { _err "--plan requires ID"; return 1; }; plan_id="$2"; shift 2 ;;
            --bucket) [ -n "${2:-}" ] || { _err "--bucket requires ID"; return 1; }; bucket="$2"; shift 2 ;;
            --mine) mine=1; shift ;;
            --open) open_only=1; shift ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 planner tasks option: $1"; return 1 ;;
        esac
    done
    [ -n "$plan_id" ] || { _err "m365 planner tasks requires --plan ID"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-planner-tasks.XXXXXX")" || return 1
    _m365_get_paginated "$alias" "$(_m365_planner_max_tasks "$alias")" "${dir}/tasks.json" "$(_m365_planner_url "$alias" "planner/plans/$(_m365_uri_encode "$plan_id")/tasks")" || return 1
    _m365_get_paginated "$alias" 200 "${dir}/buckets.json" "$(_m365_planner_url "$alias" "planner/plans/$(_m365_uri_encode "$plan_id")/buckets")" || return 1
    me=""
    [ "$mine" -eq 1 ] && { me="$(_m365_planner_my_id "$alias")" || return 1; }
    jq --arg bucket "$bucket" --arg me "$me" --argjson open "$open_only" '
      {value: [(.value // [])[] |
        select($bucket == "" or .bucketId == $bucket) |
        select($me == "" or ((.assignments // {}) | has($me))) |
        select($open == 0 or ((.percentComplete // 0) < 100))]}
    ' "${dir}/tasks.json" > "${dir}/filtered.json" || return 1
    if [ "$json_mode" -eq 1 ]; then cat "${dir}/filtered.json"; return 0; fi
    if [ "$(jq '.value | length' "${dir}/filtered.json")" -eq 0 ]; then _say "No matching Planner tasks."; return 0; fi
    jq -r --slurpfile b "${dir}/buckets.json" '
      ([$b[0].value[]? | {key: .id, value: .name}] | from_entries) as $names |
      .value | sort_by(.dueDateTime // "9999") [] |
      "- " + (.title // "(untitled task)") +
      " | " + (if (.percentComplete // 0) >= 100 then "done" elif (.percentComplete // 0) > 0 then "in progress" else "not started" end) +
      " | bucket: " + ($names[.bucketId] // .bucketId // "") +
      (if .dueDateTime then " | due: " + (.dueDateTime | .[0:10]) else "" end) +
      " | assignees: " + (((.assignments // {}) | keys | length) | tostring) +
      " | task_id: " + (.id // "")
    ' "${dir}/filtered.json"
}

_m365_planner_task() {
    local alias="${1:-}" task_id="" json_mode=0 task details encoded
    [ -n "$alias" ] || { _err "m365 planner task requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --task) [ -n "${2:-}" ] || { _err "--task requires ID"; return 1; }; task_id="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 planner task option: $1"; return 1 ;;
        esac
    done
    [ -n "$task_id" ] || { _err "m365 planner task requires --task ID"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    encoded="$(_m365_uri_encode "$task_id")"
    task="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}")")" || return 1
    details="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}/details")")" || return 1
    if [ "$json_mode" -eq 1 ]; then
        jq -n --argjson task "$task" --argjson details "$details" '{task: $task, details: $details}'
        return 0
    fi
    jq -rn --argjson t "$task" --argjson d "$details" '
      "Title: " + ($t.title // ""),
      "Task ID: " + ($t.id // ""),
      "Plan ID: " + ($t.planId // ""),
      "Bucket ID: " + ($t.bucketId // ""),
      "Progress: " + (($t.percentComplete // 0) | tostring) + "%",
      "Priority: " + (($t.priority // 5) | tostring),
      "Start: " + ($t.startDateTime // ""),
      "Due: " + ($t.dueDateTime // ""),
      "Assignee IDs: " + ((($t.assignments // {}) | keys) | join(", ")),
      "Created: " + ($t.createdDateTime // ""),
      "Description:",
      ($d.description // ""),
      (if (($d.checklist // {}) | length) > 0 then "Checklist:", ($d.checklist | to_entries | sort_by(.value.orderHint // "")[] | "- [" + (if .value.isChecked then "x" else " " end) + "] " + (.value.title // "")) else empty end)
    '
}

_m365_planner_sync() {
    local alias="${1:-}" qa=0 custom_out="" out tmp dir plan_id email me refreshed limit dirout
    [ -n "$alias" ] || { _err "m365 planner sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --qa) qa=1; shift ;; --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;; *) _err "Unknown m365 planner sync option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" planner || return 1
    if [ -z "$(_m365_planner_configured_ids "$alias")" ]; then
        _err "No plans are configured in planner.plans for alias '$alias'"
        _say "NEXT: run 'lifeos m365 planner plans $alias' and add the plan IDs to snapshot" >&2
        return 1
    fi
    if [ -n "$custom_out" ]; then out="$custom_out"; elif [ "$qa" -eq 1 ]; then out="$(_m365_output "$alias" planner 1)"; else _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_m365_output "$alias" planner 0)"; fi
    _ensure_parent_dir "$out" || return 1
    tmp="$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")" || return 1
    _register_temp_file "$tmp"
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-planner-sync.XXXXXX")" || return 1
    _say "Syncing Microsoft 365 Planner: $alias" >&2
    local n=0 files=()
    while IFS= read -r plan_id || [ -n "$plan_id" ]; do
        [ -n "$plan_id" ] || continue
        _m365_planner_fetch_plan "$alias" "$plan_id" "${dir}/plan-${n}.json" || return 1
        jq --arg id "$plan_id" --argjson cfg "$(_m365_account_value "$alias" '(.planner.plans // [])' | jq -c --arg id "$plan_id" '[.[] | select(.id == $id)][0] // {}')" '. + {config: $cfg}' "${dir}/plan-${n}.json" > "${dir}/plan-${n}.cfg.json" || return 1
        files+=("${dir}/plan-${n}.cfg.json")
        n=$((n + 1))
    done <<EOF
$(_m365_planner_configured_ids "$alias")
EOF
    jq -s '.' "${files[@]}" > "${dir}/plans.json" || return 1
    _m365_planner_fetch_users "$alias" "${dir}/plans.json" "${dir}/users.json" || return 1
    jq -n --slurpfile plans "${dir}/plans.json" --slurpfile users "${dir}/users.json" '{plans: $plans[0], users: $users[0]}' > "${dir}/render.json" || return 1
    email="$(_m365_profile_email "$alias")" || return 1
    me="$(_m365_planner_my_id "$alias")" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    limit="$(_m365_account_value "$alias" '.planner.description_character_limit // 2000')" || limit=2000
    _m365_render_helper planner --alias "$alias" --email "$email" --me "$me" --refreshed "$refreshed" --description-limit "$limit" --input "${dir}/render.json" > "$tmp" || return 1
    mv "$tmp" "$out"
    dirout="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dirout" "$refreshed" ;; esac
    _say "Updated $out"
}

# Planner stores due dates as datetimes; noon UTC keeps the same calendar date across US time zones.
_m365_planner_due() {
    case "$1" in
        none) printf 'null\n' ;;
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) printf '"%sT12:00:00Z"\n' "$1" ;;
        *) _err "--due must be YYYY-MM-DD or 'none' (got: $1)"; return 1 ;;
    esac
}

_m365_planner_progress() {
    case "$1" in
        not-started) printf '0\n' ;;
        in-progress) printf '50\n' ;;
        done) printf '100\n' ;;
        *) _err "--progress must be not-started, in-progress, or done (got: $1)"; return 1 ;;
    esac
}

_m365_planner_audit() {
    local alias="$1" action="$2" task_id="$3" title="$4" verified="$5" changes="$6"
    jq -nc --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg alias "$alias" --arg action "$action" --arg task "$task_id" --arg title "$title" --argjson verified "$verified" --argjson changes "$changes" \
        '{ts: $ts, service: "m365-planner", alias: $alias, action: $action, task_id: $task, title: $title, changes: $changes, verified: $verified}' | _mail_audit_append || _warn "Could not append to the audit log: $(_mail_audit_log_path)"
}

_m365_planner_create() {
    local alias="${1:-}" plan_id="" bucket="" title="" due="" progress="" desc="" desc_file="" execute=0 body created task_id details readback ok who uid
    local assignees=()
    [ -n "$alias" ] || { _err "m365 planner create-task requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --plan) [ -n "${2:-}" ] || { _err "--plan requires ID"; return 1; }; plan_id="$2"; shift 2 ;;
            --bucket) [ -n "${2:-}" ] || { _err "--bucket requires ID"; return 1; }; bucket="$2"; shift 2 ;;
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; shift 2 ;;
            --due) [ -n "${2:-}" ] || { _err "--due requires YYYY-MM-DD"; return 1; }; due="$2"; shift 2 ;;
            --progress) [ -n "${2:-}" ] || { _err "--progress requires a value"; return 1; }; progress="$2"; shift 2 ;;
            --assign) [ -n "${2:-}" ] || { _err "--assign requires me, an email, or a user ID"; return 1; }; assignees+=("$2"); shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 planner create-task option: $1"; return 1 ;;
        esac
    done
    [ -n "$plan_id" ] && [ -n "$bucket" ] && [ -n "$title" ] || { _err "create-task requires --plan, --bucket, and --title"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    _m365_planner_require_plan_allowed "$alias" "$plan_id" || return 1
    if [ -n "$desc_file" ]; then [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }; desc="$(cat "$desc_file")"; fi
    body="$(jq -nc --arg plan "$plan_id" --arg bucket "$bucket" --arg title "$title" '{planId: $plan, bucketId: $bucket, title: $title}')"
    if [ -n "$due" ]; then body="$(printf '%s' "$body" | jq -c --argjson due "$(_m365_planner_due "$due")" '. + {dueDateTime: $due}')" || return 1; fi
    if [ -n "$progress" ]; then body="$(printf '%s' "$body" | jq -c --argjson p "$(_m365_planner_progress "$progress")" '. + {percentComplete: $p}')" || return 1; fi
    for who in "${assignees[@]+"${assignees[@]}"}"; do
        uid="$(_m365_planner_resolve_user "$alias" "$who")" || return 1
        body="$(printf '%s' "$body" | jq -c --arg u "$uid" '.assignments = ((.assignments // {}) + {($u): {"@odata.type": "#microsoft.graph.plannerAssignment", orderHint: " !"}})')"
    done
    _say "Microsoft 365 Planner create-task plan:"
    _say "Account: $alias"
    printf '%s' "$body" | jq .
    [ -n "$desc" ] && { _say "Description:"; printf '%s\n' "$desc"; }
    _say "Note: this plan is shared; the new task is visible to everyone on it."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no task was created. Re-run with --execute to create it."; return 0; fi
    _m365_planner_require_write "$alias" || return 1
    created="$(_m365_write POST "$alias" "$(_m365_planner_url "$alias" "planner/tasks")" "$body")" || return 1
    task_id="$(printf '%s' "$created" | jq -r '.id // empty')"
    [ -n "$task_id" ] || { _err "Graph did not return a task ID"; return 1; }
    if [ -n "$desc" ]; then
        details="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")/details")")" || return 1
        _m365_http PATCH "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")/details")" "$(jq -nc --arg d "$desc" '{description: $d}')" -H "If-Match: $(printf '%s' "$details" | jq -r '."@odata.etag"')" >/dev/null || { _err "Task $task_id was created, but setting its description failed"; return 1; }
    fi
    readback="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")")" || return 1
    ok="$(jq -n --argjson want "$body" --argjson got "$readback" '($got.title == $want.title) and ($got.bucketId == $want.bucketId) and (($want.assignments // {}) | keys | all(. as $k | ($got.assignments // {}) | has($k)))')"
    _m365_planner_audit "$alias" create-task "$task_id" "$title" "$ok" "$body"
    [ "$ok" = true ] || { _err "Created task $task_id but readback did not match the request"; return 1; }
    _say "Created task (confirmed by readback): $title | task_id: $task_id"
}

_m365_planner_update() {
    local alias="${1:-}" task_id="" title="" bucket="" due="" progress="" desc="" desc_file="" set_desc=0 execute=0
    local encoded current details patch="{}" who uid ok readback after_details
    local assign=() unassign=()
    [ -n "$alias" ] || { _err "m365 planner update-task requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --task) [ -n "${2:-}" ] || { _err "--task requires ID"; return 1; }; task_id="$2"; shift 2 ;;
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; shift 2 ;;
            --bucket) [ -n "${2:-}" ] || { _err "--bucket requires ID"; return 1; }; bucket="$2"; shift 2 ;;
            --due) [ -n "${2:-}" ] || { _err "--due requires YYYY-MM-DD or none"; return 1; }; due="$2"; shift 2 ;;
            --progress) [ -n "${2:-}" ] || { _err "--progress requires a value"; return 1; }; progress="$2"; shift 2 ;;
            --assign) [ -n "${2:-}" ] || { _err "--assign requires me, an email, or a user ID"; return 1; }; assign+=("$2"); shift 2 ;;
            --unassign) [ -n "${2:-}" ] || { _err "--unassign requires me, an email, or a user ID"; return 1; }; unassign+=("$2"); shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; set_desc=1; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; set_desc=1; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 planner update-task option: $1"; return 1 ;;
        esac
    done
    [ -n "$task_id" ] || { _err "update-task requires --task ID"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    if [ -n "$desc_file" ]; then [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }; desc="$(cat "$desc_file")"; fi
    encoded="$(_m365_uri_encode "$task_id")"
    current="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}")")" || return 1
    _m365_planner_require_plan_allowed "$alias" "$(printf '%s' "$current" | jq -r '.planId')" || return 1
    [ -n "$title" ] && patch="$(printf '%s' "$patch" | jq -c --arg v "$title" '. + {title: $v}')"
    [ -n "$bucket" ] && patch="$(printf '%s' "$patch" | jq -c --arg v "$bucket" '. + {bucketId: $v}')"
    if [ -n "$due" ]; then patch="$(printf '%s' "$patch" | jq -c --argjson v "$(_m365_planner_due "$due")" '. + {dueDateTime: $v}')" || return 1; fi
    if [ -n "$progress" ]; then patch="$(printf '%s' "$patch" | jq -c --argjson v "$(_m365_planner_progress "$progress")" '. + {percentComplete: $v}')" || return 1; fi
    for who in "${assign[@]+"${assign[@]}"}"; do
        uid="$(_m365_planner_resolve_user "$alias" "$who")" || return 1
        patch="$(printf '%s' "$patch" | jq -c --arg u "$uid" '.assignments = ((.assignments // {}) + {($u): {"@odata.type": "#microsoft.graph.plannerAssignment", orderHint: " !"}})')"
    done
    for who in "${unassign[@]+"${unassign[@]}"}"; do
        uid="$(_m365_planner_resolve_user "$alias" "$who")" || return 1
        printf '%s' "$current" | jq -e --arg u "$uid" '(.assignments // {}) | has($u)' >/dev/null || { _err "User $uid is not assigned to this task"; return 1; }
        patch="$(printf '%s' "$patch" | jq -c --arg u "$uid" '.assignments = ((.assignments // {}) + {($u): null})')"
    done
    if [ "$patch" = "{}" ] && [ "$set_desc" -eq 0 ]; then _err "update-task needs at least one change"; return 1; fi
    _say "Microsoft 365 Planner update-task plan:"
    _say "Account: $alias"
    printf '%s' "$current" | jq -r '"Task: " + (.title // "") + " | task_id: " + .id, "Now: progress " + ((.percentComplete // 0) | tostring) + "% | bucket " + (.bucketId // "") + " | due " + (.dueDateTime // "none") + " | assignees " + (((.assignments // {}) | keys) | join(", "))'
    [ "$patch" != "{}" ] && { _say "Task changes:"; printf '%s' "$patch" | jq .; }
    [ "$set_desc" -eq 1 ] && { _say "New description (replaces the whole description):"; printf '%s\n' "$desc"; }
    _say "Note: this plan is shared; changes are visible to everyone on it."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was changed. Re-run with --execute to apply."; return 0; fi
    _m365_planner_require_write "$alias" || return 1
    # If-Match carries the etag read at the start of this run, so a task someone changed in the meantime is refused rather than overwritten.
    if [ "$patch" != "{}" ]; then
        _m365_http PATCH "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}")" "$patch" -H "If-Match: $(printf '%s' "$current" | jq -r '."@odata.etag"')" >/dev/null || { _err "Update refused or failed; the task may have changed since it was read. Re-run to see its current state."; return 1; }
    fi
    if [ "$set_desc" -eq 1 ]; then
        details="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}/details")")" || return 1
        _m365_http PATCH "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}/details")" "$(jq -nc --arg d "$desc" '{description: $d}')" -H "If-Match: $(printf '%s' "$details" | jq -r '."@odata.etag"')" >/dev/null || { _err "Description update refused or failed"; return 1; }
    fi
    readback="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}")")" || return 1
    after_details='{}'
    [ "$set_desc" -eq 1 ] && { after_details="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/${encoded}/details")")" || return 1; }
    ok="$(jq -n --argjson p "$patch" --argjson got "$readback" --argjson d "$after_details" --arg desc "$desc" --argjson setdesc "$set_desc" '
      (($p.title == null) or ($got.title == $p.title)) and
      (($p.bucketId == null) or ($got.bucketId == $p.bucketId)) and
      (($p | has("percentComplete") | not) or ($got.percentComplete == $p.percentComplete)) and
      (($p | has("dueDateTime") | not) or (($got.dueDateTime // null | if . then .[0:10] else null end) == ($p.dueDateTime | if . then .[0:10] else null end))) and
      ((($p.assignments // {}) | to_entries) | all(if .value == null then (($got.assignments // {}) | has(.key) | not) else (($got.assignments // {}) | has(.key)) end)) and
      ($setdesc == 0 or ($d.description == $desc))
    ')"
    _m365_planner_audit "$alias" update-task "$task_id" "$(printf '%s' "$readback" | jq -r '.title // ""')" "$ok" "$(printf '%s' "$patch" | jq -c --argjson s "$set_desc" 'if $s == 1 then . + {description: "(replaced)"} else . end')"
    [ "$ok" = true ] || { _err "Update was sent but readback did not match the requested changes"; return 1; }
    _say "Updated task (confirmed by readback): $(printf '%s' "$readback" | jq -r '.title') | task_id: $task_id"
}

# Experimental beta move: one conditional PATCH, never clone/delete or retry an ambiguous write.
_m365_planner_move() {
    local alias="${1:-}" task_id="" plan_id="" bucket="" execute=0 base url current details source target destination source_id etag patch changes after after_details ok
    [ -n "$alias" ] || { _err "m365 planner move-task requires ALIAS"; return 1; }
    shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --task|--plan|--bucket)
                [ -n "${2:-}" ] || { _err "$1 requires ID"; return 1; }
                case "$1" in --task) task_id="$2" ;; --plan) plan_id="$2" ;; --bucket) bucket="$2" ;; esac
                shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 planner move-task option: $1"; return 1 ;;
        esac
    done
    [ -n "$task_id" ] && [ -n "$plan_id" ] && [ -n "$bucket" ] || { _err "move-task requires --task, --plan, and --bucket"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    _m365_planner_require_plan_allowed "$alias" "$plan_id" || return 1
    base="$(_m365_graph_base "$alias")" || return 1
    base="${base%/}"
    case "$base" in */v1.0) base="${base%/v1.0}/beta" ;; */beta) ;; *) _err "Cannot derive beta Graph endpoint from graph_base"; return 1 ;; esac
    url="$base/planner/tasks/$(_m365_uri_encode "$task_id")"
    current="$(_m365_get "$alias" "$url")" || return 1
    source_id="$(printf '%s' "$current" | jq -er '.planId | select(type == "string" and length > 0)')" || return 1
    _m365_planner_require_plan_allowed "$alias" "$source_id" || return 1
    [ "$source_id" != "$plan_id" ] || { _err "Task is already in the destination plan; use update-task for a bucket change"; return 1; }
    etag="$(printf '%s' "$current" | jq -er '."@odata.etag" | select(type == "string" and length > 0 and . != "*")')" || { _err "Task has no usable ETag"; return 1; }
    details="$(_m365_get "$alias" "$url/details")" || return 1
    source="$(_m365_get "$alias" "$base/planner/plans/$(_m365_uri_encode "$source_id")")" || return 1
    target="$(_m365_get "$alias" "$base/planner/plans/$(_m365_uri_encode "$plan_id")")" || return 1
    destination="$(_m365_get "$alias" "$base/planner/buckets/$(_m365_uri_encode "$bucket")")" || return 1
    printf '%s' "$destination" | jq -e --arg p "$plan_id" --arg b "$bucket" '.planId == $p and .id == $b' >/dev/null || { _err "Destination bucket does not belong to the destination plan"; return 1; }
    # Cross-container moves can drop assignees and group conversations; defer them until preservation is supported.
    jq -en --argjson s "$source" --argjson t "$target" '
      ($s.container.type == "group") and ($t.container.type == "group") and
      (($s.container.containerId // "") != "") and ($s.container.containerId == $t.container.containerId)
    ' >/dev/null || { _err "Experimental move-task currently requires plans in the same Microsoft 365 group"; return 1; }
    printf '%s' "$current" | jq -e '
      ([((.appliedCategories // {}) | .[])] | any(. == true) | not) and
      (.recurrence == null) and (.creationSource == null)
    ' >/dev/null || { _err "Move refused: labels, recurrence, or externally sourced tasks need separate review"; return 1; }
    patch="$(jq -nc --arg p "$plan_id" --arg b "$bucket" '{planId:$p,bucketId:$b}')" || return 1
    changes="$(jq -nc --argjson c "$current" --argjson p "$patch" '{from:{planId:$c.planId,bucketId:$c.bucketId},to:$p,api:"beta"}')" || return 1
    _say "Microsoft 365 Planner move-task (experimental Graph beta):"
    _say "Account: $alias | Task: $task_id"
    printf '%s' "$current" | jq '{title,planId,bucketId,percentComplete,dueDateTime,assignments}'
    _say "Destination plan and bucket:"
    jq -n --argjson p "$target" --argjson b "$destination" '{plan:$p.title,planId:$p.id,bucket:$b.name,bucketId:$b.id}'
    _say "Same-group move; description, checklist, references, dates, progress, priority, assignees, and conversation link will be checked after the PATCH. Plan-specific goals, custom columns, and linked meeting notes are not supported or verified."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was moved. Re-run with --execute to apply."; return 0; fi
    _m365_planner_require_write "$alias" || return 1
    # Audit the attempt before dispatch so transport failures and failed readbacks leave a trace.
    _m365_planner_audit "$alias" move-task-attempt "$task_id" "$(printf '%s' "$current" | jq -r '.title')" false "$changes"
    _m365_http PATCH "$alias" "$url" "$patch" -H "If-Match: $etag" >/dev/null || { _err "Move failed or outcome is uncertain; inspect the task before retrying. No automatic retry was made."; return 1; }
    after="$(_m365_get "$alias" "$url")" && after_details="$(_m365_get "$alias" "$url/details")" || { _err "Move was sent but readback failed; inspect the task before retrying"; return 1; }
    ok="$(jq -n --argjson before "$current" --argjson after "$after" --argjson d "$details" --argjson a "$after_details" --arg p "$plan_id" --arg b "$bucket" '
      def stable: {id,title,percentComplete,priority,startDateTime,dueDateTime,conversationThreadId,assignees:((.assignments // {}) | keys)};
      def content: {description:(.description // ""),checklist:(.checklist // {}),references:(.references // {})};
      ($after.planId == $p and $after.bucketId == $b) and
      (($before | stable) == ($after | stable)) and (($d | content) == ($a | content))
    ')" || return 1
    _m365_planner_audit "$alias" move-task "$task_id" "$(printf '%s' "$current" | jq -r '.title')" "$ok" "$changes"
    [ "$ok" = true ] || { _err "Move was sent but preservation/readback checks failed; inspect the task before retrying"; return 1; }
    _say "Moved task (confirmed by readback): $task_id | plan_id: $plan_id | bucket_id: $bucket"
}

##- Existing plan labels: names are resolved uniquely, never created or renamed.
_m365_planner_labels() {
    local alias="${1:-}" plan_id="" json_mode=0 details labels
    [ -n "$alias" ] || { _err "m365 planner labels requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --plan) [ -n "${2:-}" ] || { _err "--plan requires ID"; return 1; }; plan_id="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 planner labels option: $1"; return 1 ;;
        esac
    done
    [ -n "$plan_id" ] || { _err "labels requires --plan ID"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    details="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/plans/$(_m365_uri_encode "$plan_id")/details")")" || return 1
    labels="$(printf '%s' "$details" | jq -c '[((.categoryDescriptions // {}) | to_entries[]) | select(.key | test("^category[1-9][0-9]*$")) | select(.value | type == "string" and length > 0) | {id: .key, name: .value}]')" || return 1
    if [ "$json_mode" -eq 1 ]; then printf '%s\n' "$labels"; else printf '%s' "$labels" | jq -r '.[] | "- " + .name + " | label_id: " + .id'; fi
}

_m365_planner_label() {
    local action="$1" alias="${2:-}" task_id="" label="" execute=0 current labels matches key wanted patch expected after ok
    [ -n "$alias" ] || { _err "m365 planner $action requires ALIAS"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --task) [ -n "${2:-}" ] || { _err "--task requires ID"; return 1; }; task_id="$2"; shift 2 ;;
            --label) [ -n "${2:-}" ] || { _err "--label requires NAME"; return 1; }; label="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 planner $action option: $1"; return 1 ;;
        esac
    done
    [ -n "$task_id" ] && [ -n "$label" ] || { _err "$action requires --task ID and --label NAME"; return 1; }
    _m365_require_enabled "$alias" planner || return 1
    current="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")")" || return 1
    _m365_planner_require_plan_allowed "$alias" "$(printf '%s' "$current" | jq -r '.planId')" || return 1
    labels="$(_m365_planner_labels "$alias" --plan "$(printf '%s' "$current" | jq -r '.planId')" --json)" || return 1
    matches="$(printf '%s' "$labels" | jq -c --arg n "$label" '[.[] | select((.name | ascii_downcase) == ($n | ascii_downcase))]')" || return 1
    [ "$(printf '%s' "$matches" | jq length)" -eq 1 ] || { _err "Label '$label' must match exactly one existing plan label (case-insensitive); use planner labels to inspect names"; return 1; }
    key="$(printf '%s' "$matches" | jq -r '.[0].id')"
    wanted=true
    [ "$action" = unlabel ] && wanted=false
    expected="$(printf '%s' "$current" | jq -c --arg k "$key" --argjson v "$wanted" '(.appliedCategories // {}) | with_entries(select(.key | test("^category[1-9][0-9]*$"))) | . + {($k): $v}')" || return 1
    _say "Microsoft 365 Planner $action plan: $alias | task_id: $task_id | $(printf '%s' "$current" | jq -r '.title')"
    _say "Label: $(printf '%s' "$matches" | jq -r '.[0].name') ($key) -> $wanted; other labels and task fields are preserved."
    _say "Note: this plan is shared; changes are visible to everyone on it."
    if [ "$(printf '%s' "$current" | jq -r --arg k "$key" '.appliedCategories[$k] // false')" = "$wanted" ]; then
        _say "No change: label already has the requested state."
        return 0
    fi
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was changed. Re-run with --execute to apply."; return 0; fi
    _m365_planner_require_write "$alias" || return 1
    # Recheck the name binding before the conditional task write; plan label names have a separate ETag and cannot be guarded atomically with the task.
    labels="$(_m365_planner_labels "$alias" --plan "$(printf '%s' "$current" | jq -r '.planId')" --json)" || return 1
    printf '%s' "$labels" | jq -e --arg n "$label" --arg k "$key" '[.[] | select((.name | ascii_downcase) == ($n | ascii_downcase))] | length == 1 and .[0].id == $k' >/dev/null || { _err "Plan label names changed; inspect before retrying"; return 1; }
    patch="$(jq -nc --argjson c "$expected" '{appliedCategories: $c}')" || return 1
    _m365_planner_audit "$alias" "$action-attempt" "$task_id" "$(printf '%s' "$current" | jq -r '.title')" false "$patch" || return 1
    _m365_http PATCH "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")" "$patch" -H "If-Match: $(printf '%s' "$current" | jq -r '."@odata.etag"')" >/dev/null || { _err "Label write refused or failed; outcome may be uncertain. Read the task before retrying; no automatic retry was made."; return 1; }
    after="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")")" || { _err "Label write sent but readback failed; inspect the task before retrying"; return 1; }
    # Graph can omit false categories; compare active sets and every other task property except the server ETag.
    ok="$(jq -n --argjson e "$expected" --argjson b "$current" --argjson a "$after" 'def active: with_entries(select(.key | test("^category[1-9][0-9]*$"))) | with_entries(select(.value == true)); (($a.appliedCategories // {} | active) == ($e | active)) and (($a | del(."@odata.etag", .appliedCategories)) == ($b | del(."@odata.etag", .appliedCategories)))')" || return 1
    _m365_planner_audit "$alias" "$action" "$task_id" "$(printf '%s' "$current" | jq -r '.title')" "$ok" "$patch" || return 1
    [ "$ok" = true ] || { _err "Label write sent but readback or preserved task fields did not match; inspect before retrying"; return 1; }
    _say "Updated label (confirmed by readback): $label | task_id: $task_id"
}

##- Task-scoped group conversation comments; never request broader OAuth scopes.
_m365_planner_comment_access() {
    local alias="$1" access="$2" context
    [ "$(_m365_auth_provider "$alias")" = graph-powershell ] || { _err "Comment scope inspection currently supports graph-powershell only; no authorization was changed"; return 1; }
    context="$(_m365_powershell_auth "$alias" "")" || return 1
    printf '%s' "$context" | jq -e --arg access "$access" '(.effective_scopes // []) as $s | if $access == "write" then ($s | index("Group.ReadWrite.All")) != null else any($s[]; . == "Group.Read.All" or . == "Group.ReadWrite.All" or . == "Group-Conversation.Read.All" or . == "Group-Conversation.ReadWrite.All") end' >/dev/null || { _err "Comments need existing group-conversation permission (read: Group-Conversation.Read.All or documented higher; write: Group.ReadWrite.All). Stop for approval; no permission was requested."; return 1; }
}

_m365_planner_comment_posts() {
    local alias="$1" group="$2" thread="$3" url root page merged='{"value":[]}' count=0
    root="$(_m365_planner_url "$alias" "groups/$(_m365_uri_encode "$group")/threads/$(_m365_uri_encode "$thread")/posts")"
    url="$root"
    while [ -n "$url" ]; do
        count=$((count + 1))
        [ "$count" -le 20 ] || { _err "Comment pagination exceeds 20 pages; refusing incomplete duplicate check"; return 1; }
        case "$url" in "$root"|"$root"\?*) ;; *) _err "Unexpected comment pagination target"; return 1 ;; esac
        page="$(_m365_get "$alias" "$url")" || return 1
        printf '%s' "$page" | jq -e '.value | type == "array"' >/dev/null || return 1
        merged="$(jq -nc --argjson a "$merged" --argjson b "$page" '{value: ($a.value + $b.value)}')" || return 1
        [ "$(printf '%s' "$merged" | jq '.value | length')" -le 1000 ] || { _err "More than 1000 comments; refusing incomplete duplicate check"; return 1; }
        url="$(printf '%s' "$page" | jq -r '."@odata.nextLink" // empty')"
    done
    printf '%s\n' "$merged"
}

_m365_planner_comment_journal() {
    local dest="$1" state="$2" thread="$3" hash="$4" tmp
    tmp="$(mktemp "${dest}.XXXXXX")" || return 1
    jq -nc --arg state "$state" --arg thread "$thread" --arg hash "$hash" '{state:$state,thread:$thread,hash:$hash}' > "$tmp" && mv "$tmp" "$dest"
}

_m365_planner_comments() (
    local mode="$1" alias="${2:-}" task_id="" file="" execute=0 json_mode=0 current plan group thread posts matches text hash recovery lock journal state saved_thread created patch after ok action
    [ -n "$alias" ] || { _err "planner $mode requires ALIAS"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --task) [ -n "${2:-}" ] || { _err "--task requires ID"; return 1; }; task_id="$2"; shift 2 ;;
            --file) [ -n "${2:-}" ] || { _err "--file requires PATH"; return 1; }; file="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown planner $mode option: $1"; return 1 ;;
        esac
    done
    [ -n "$task_id" ] || { _err "$mode requires --task ID"; return 1; }
    if [ "$mode" = comments ]; then
        [ -z "$file" ] && [ "$execute" -eq 0 ] || { _err "comments is read-only"; return 1; }
    else
        [ -f "$file" ] || { _err "comment requires --file PATH"; return 1; }
        text="$(cat "$file")"
        printf '%s' "$text" | grep -q '[^[:space:]]' || { _err "Comment must not be blank"; return 1; }
        [ -n "$text" ] && [ "${#text}" -le 10000 ] || { _err "Comment must contain 1–10000 characters"; return 1; }
    fi
    _m365_require_enabled "$alias" planner || return 1
    current="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")")" || return 1
    _m365_planner_require_plan_allowed "$alias" "$(printf '%s' "$current" | jq -r '.planId')" || return 1
    action=read
    [ "$mode" = comment ] && action=write
    _m365_planner_comment_access "$alias" "$action" || return 1
    plan="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/plans/$(printf '%s' "$current" | jq -r '.planId | @uri')")")" || return 1
    group="$(printf '%s' "$plan" | jq -r 'if .container.type == "group" then .container.containerId elif (.container == null and .owner != null) then .owner else empty end')"
    [ -n "$group" ] || { _err "Comments require a group-backed plan"; return 1; }
    thread="$(printf '%s' "$current" | jq -r '.conversationThreadId // empty')"
    if [ "$mode" = comments ]; then
        posts='{"value":[]}'
        [ -z "$thread" ] || posts="$(_m365_planner_comment_posts "$alias" "$group" "$thread")" || return 1
        if [ "$json_mode" -eq 1 ]; then jq -n --arg task "$task_id" --arg thread "$thread" --argjson p "$posts" '{task_id:$task,thread_id:(if $thread == "" then null else $thread end),posts:$p.value}'; else printf '%s' "$posts" | "$LIFEOS_PY" "${LIB_DIR}/m365-planner-comments.py" render; fi
        return
    fi
    umask 077
    hash="$(printf '%s' "$text" | "$LIFEOS_PY" -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())')" || return 1
    recovery="$(dirname "$(_mail_audit_log_path)")/planner-comments"
    mkdir -p "$recovery" || return 1
    journal="$recovery/$(printf '%s' "$alias/$task_id" | "$LIFEOS_PY" -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())').json"
    lock="${journal}.lock"
    mkdir "$lock" 2>/dev/null || { _err "Comment operation locked: $lock; inspect any running or interrupted operation before retrying"; return 1; }
    trap 'rmdir "$lock"' EXIT
    state="" saved_thread=""
    if [ -f "$journal" ]; then
        if [ -z "$thread" ] && [ "$(jq -r '(.state == "verified") and (.thread != "")' "$journal")" = true ]; then _err "Task lost its previously verified conversation link; inspect $journal before creating another thread"; return 1; fi
        state="$(jq -r '.state' "$journal")" || return 1
        if [ "$state" != verified ]; then
            [ "$(jq -r '.hash' "$journal")" = "$hash" ] || { _err "Unresolved prior comment attempt: $journal; inspect before posting different text"; return 1; }
            saved_thread="$(jq -r '.thread' "$journal")"
            [ -n "$saved_thread" ] || { _err "Prior thread creation outcome is uncertain: $journal. Do not retry creation; inspect the group conversation first."; return 1; }
            [ -z "$thread" ] || [ "$thread" = "$saved_thread" ] || { _err "Task thread changed during pending recovery: $journal"; return 1; }
            thread="$saved_thread"
        fi
    fi
    posts='{"value":[]}' matches='[]'
    if [ -n "$thread" ]; then
        posts="$(_m365_planner_comment_posts "$alias" "$group" "$thread")" || return 1
        matches="$(printf '%s' "$posts" | "$LIFEOS_PY" "${LIB_DIR}/m365-planner-comments.py" match "$file")" || return 1
    fi
    if [ "$state" = pending-link ] && [ "$(printf '%s' "$matches" | jq length)" -eq 0 ]; then _err "Created thread post remains unverified: $journal; no additional post was sent"; return 1; fi
    if [ "$state" = pending-reply ] && [ "$(printf '%s' "$matches" | jq length)" -eq 0 ]; then _err "Prior reply outcome remains uncertain: $journal. No retry was sent."; return 1; fi
    if [ "$(printf '%s' "$matches" | jq length)" -gt 0 ] && [ "$(printf '%s' "$current" | jq -r '.conversationThreadId // empty')" = "$thread" ]; then
        [ "$execute" -eq 0 ] || _m365_planner_comment_journal "$journal" verified "$thread" "$hash" || return 1
        _say "No change: matching comment already exists in the task thread."
        return 0
    fi
    _say "Planner comment plan: $alias | task_id: $task_id | $(printf '%s' "$current" | jq -r '.title')"
    _say "Group conversation: $group | thread: ${thread:-new, to be linked to this task}"
    _say "This shared group post may trigger Microsoft 365 group notifications. Exact text:"
    printf '%s\n' "$text"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no comment or task link was written."; return 0; fi
    _m365_planner_require_write "$alias" || return 1
    if [ -z "$thread" ]; then
        _m365_planner_comment_journal "$journal" pending-create "" "$hash" || return 1
        _m365_planner_audit "$alias" comment-create-attempt "$task_id" "$(printf '%s' "$current" | jq -r '.title')" false "$(jq -nc --arg h "$hash" '{text_sha256:$h}')"
        created="$(_m365_write POST "$alias" "$(_m365_planner_url "$alias" "groups/$(_m365_uri_encode "$group")/threads")" "$(jq -nc --arg topic "Planner task [$task_id]" --arg t "$text" '{topic:$topic,posts:[{body:{contentType:"text",content:$t}}]}')")" || { _err "Thread creation failed or is uncertain: $journal. Inspect before retrying; no automatic retry."; return 1; }
        thread="$(printf '%s' "$created" | jq -r '.id // empty')"
        [ -n "$thread" ] || { _err "Thread creation returned no ID; outcome uncertain: $journal"; return 1; }
        _m365_planner_comment_journal "$journal" pending-link "$thread" "$hash" || return 1
    elif [ "$(printf '%s' "$matches" | jq length)" -eq 0 ]; then
        _m365_planner_comment_journal "$journal" pending-reply "$thread" "$hash" || return 1
        _m365_planner_audit "$alias" comment-reply-attempt "$task_id" "$(printf '%s' "$current" | jq -r '.title')" false "$(jq -nc --arg h "$hash" --arg t "$thread" '{text_sha256:$h,thread:$t}')"
        _m365_write POST "$alias" "$(_m365_planner_url "$alias" "groups/$(_m365_uri_encode "$group")/threads/$(_m365_uri_encode "$thread")/reply")" "$(jq -nc --arg t "$text" '{post:{body:{contentType:"text",content:$t}}}')" >/dev/null || { _err "Reply failed or is uncertain: $journal. Read comments before retrying; no automatic retry."; return 1; }
    fi
    posts="$(_m365_planner_comment_posts "$alias" "$group" "$thread")" || { _err "Comment sent but readback failed: $journal"; return 1; }
    matches="$(printf '%s' "$posts" | "$LIFEOS_PY" "${LIB_DIR}/m365-planner-comments.py" match "$file")" || return 1
    [ "$(printf '%s' "$matches" | jq length)" -gt 0 ] || { _err "Comment not yet verified in thread; inspect before retrying: $journal"; return 1; }
    patch="$(jq -nc --arg t "$thread" '{conversationThreadId:$t}')"
    if [ "$(printf '%s' "$current" | jq -r '.conversationThreadId // empty')" != "$thread" ]; then
        _m365_http PATCH "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")" "$patch" -H "If-Match: $(printf '%s' "$current" | jq -r '."@odata.etag"')" >/dev/null || { _err "Comment exists but linking failed or is uncertain; preserve thread $thread and inspect: $journal"; return 1; }
    fi
    after="$(_m365_get "$alias" "$(_m365_planner_url "$alias" "planner/tasks/$(_m365_uri_encode "$task_id")")")" || return 1
    ok="$(jq -n --argjson a "$after" --argjson b "$current" --arg t "$thread" '$a.conversationThreadId == $t and (($a | del(."@odata.etag",.conversationThreadId)) == ($b | del(."@odata.etag",.conversationThreadId)))')" || return 1
    _m365_planner_audit "$alias" comment "$task_id" "$(printf '%s' "$current" | jq -r '.title')" "$ok" "$(jq -nc --arg h "$hash" --arg t "$thread" --argjson p "$matches" '{text_sha256:$h,thread:$t,post_ids:$p}')"
    [ "$ok" = true ] || { _err "Comment exists but task link or unrelated fields failed verification: $journal"; return 1; }
    _m365_planner_comment_journal "$journal" verified "$thread" "$hash" || return 1
    _say "Comment and task link confirmed by readback | task_id: $task_id | post_ids: $matches"
)

_m365_planner_dispatch() {
    case "${1:-}" in
        plans) shift; _m365_planner_plans "$@" ;;
        comments|comment) _m365_planner_comments "$@" ;;
        labels) shift; _m365_planner_labels "$@" ;;
        label|unlabel) _m365_planner_label "$@" ;;
        buckets) shift; _m365_planner_buckets "$@" ;;
        tasks) shift; _m365_planner_tasks "$@" ;;
        task) shift; _m365_planner_task "$@" ;;
        sync) shift; _m365_planner_sync "$@" ;;
        create-task) shift; _m365_planner_create "$@" ;;
        update-task) shift; _m365_planner_update "$@" ;;
        move-task) shift; _m365_planner_move "$@" ;;
        *) _err "Unknown m365 planner command: ${1:-}"; return 1 ;;
    esac
}
