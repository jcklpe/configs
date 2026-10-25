#!/usr/bin/env bash
##- Compatibility entry; private snapshot, audit, and recovery routing remain here.
if ! command -v _m365_error >/dev/null 2>&1; then
    source "${LIB_DIR}/../../agent-hands/skills/authorize-microsoft/scripts/client.sh"
fi
source "${LIB_DIR}/../../agent-hands/skills/use-planner/scripts/operations.sh"
_m365_planner_python() { "${LIFEOS_PY:-python3}" "$@"; }
_m365_planner_audit_path() { _mail_audit_log_path; }
_m365_planner_audit_append() { _mail_audit_append; }
_m365_planner_recovery_dir() { printf '%s/planner-comments\n' "$(dirname "$(_mail_audit_log_path)")"; }

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
    _m365_planner_export "$alias" --output "$out" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    dirout="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dirout" "$refreshed" ;; esac
}

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
