#!/usr/bin/env bash
##- Small compatibility helpers. Provider skills own configuration, runtimes, and audit handling.

_say() {
    printf '%s\n' "$*"
}

_warn() {
    printf 'WARN: %s\n' "$*" >&2
}

_err() {
    printf 'ERROR: %s\n' "$*" >&2
}

_trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

_LIFEOS_TEMP_FILES=()

_register_temp_file() {
    _LIFEOS_TEMP_FILES+=("$1")
    trap '_cleanup_temp_files' EXIT HUP INT TERM
}

_cleanup_temp_files() {
    local f
    for f in "${_LIFEOS_TEMP_FILES[@]}"; do
        [ -f "$f" ] && rm -f "$f" || true
    done
    return 0
}

_ensure_parent_dir() {
    local dir
    dir="$(dirname "$1")"
    [ -d "$dir" ] || mkdir -p "$dir"
}

_check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        _say "OK: command '$1' found"
        return 0
    fi
    _say "MISSING: command '$1'"
    return 1
}
