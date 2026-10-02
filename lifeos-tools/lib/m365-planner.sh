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

_m365_planner_dispatch() {
    case "${1:-}" in
        plans) shift; _m365_planner_plans "$@" ;;
        buckets) shift; _m365_planner_buckets "$@" ;;
        tasks) shift; _m365_planner_tasks "$@" ;;
        task) shift; _m365_planner_task "$@" ;;
        sync) shift; _m365_planner_sync "$@" ;;
        create-task) shift; _m365_planner_create "$@" ;;
        update-task) shift; _m365_planner_update "$@" ;;
        *) _err "Unknown m365 planner command: ${1:-}"; return 1 ;;
    esac
}
