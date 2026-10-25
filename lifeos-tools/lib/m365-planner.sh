#!/usr/bin/env bash
##- Compatibility entry; configuration, audit, recovery, and exports belong to the provider/capability owners.
if ! command -v _m365_error >/dev/null 2>&1; then
    source "${LIB_DIR}/../../agent-hands/skills/authorize-microsoft/scripts/client.sh"
fi
source "${LIB_DIR}/../../agent-hands/skills/use-planner/scripts/operations.sh"
_m365_planner_sync() { _m365_planner_export "$@"; }

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
