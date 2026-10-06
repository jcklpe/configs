#!/usr/bin/env bash
##- Experimental Loop browser adapter. Each account uses a dedicated profile; ordinary commands are headless. No CDP attachment, clipboard access, or generic browser command.

_m365_loop_dispatch() {
    local action="${1:-}" alias="${2:-}" arg
    case "$action" in
        help|--help|'') "$LIFEOS_PY" "${LIB_DIR}/m365-loop.py" --help; return $? ;;
        login|status|read|append) ;;
        *) _err "Unknown m365 loop command: $action"; return 1 ;;
    esac
    [ -n "$alias" ] || { _err "m365 loop $action requires ALIAS"; return 1; }
    _m365_require_enabled "$alias" files || return 1
    if [ "$action" = append ]; then
        for arg in "$@"; do
            if [ "$arg" = --execute ]; then _m365_files_require_write "$alias" || return 1; fi
        done
    fi
    "$LIFEOS_PY" "${LIB_DIR}/m365-loop.py" "$@"
}
