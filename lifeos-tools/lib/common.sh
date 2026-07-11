#!/usr/bin/env bash
##- lifeos common helpers: output, string, env loading, and var/path primitives.
##- Sourced by lifeos.sh after the bootstrap vars (SCRIPT_DIR, CONFIGS, ENV_FILE) are set, and before the feature modules, which depend on these functions.
##- Feature-agnostic: no Trello, Google, or vault specifics belong here.

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

_load_env() {
    local line key value is_set

    [ -f "$ENV_FILE" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
            export\ *) line="${line#export }" ;;
        esac

        case "$line" in
            *=*) ;;
            *) continue ;;
        esac

        key="$(_trim "${line%%=*}")"
        value="${line#*=}"

        case "$key" in
            ''|*[!A-Za-z0-9_]*) continue ;;
        esac

        eval "is_set=\${${key}+x}"
        if [ -z "$is_set" ]; then
            eval "export ${key}=${value}"
        fi
    done < "$ENV_FILE"

    LIFEOS_DAYS_BACK="${LIFEOS_DAYS_BACK:-14}"
    LIFEOS_DAYS_AHEAD="${LIFEOS_DAYS_AHEAD:-30}"
    export LIFEOS_DAYS_BACK LIFEOS_DAYS_AHEAD
}

_var_is_set() {
    local value
    eval "value=\${$1:-}"
    [ -n "$value" ]
}

_require_var() {
    if ! _var_is_set "$1"; then
        _err "$1 is not set"
        return 1
    fi
    return 0
}

_redacted_status() {
    if _var_is_set "$1"; then
        _say "OK: $1 is set (redacted)"
    else
        _say "MISSING: $1"
        return 1
    fi
}

_path_value() {
    local value
    eval "value=\${$1:-}"
    printf '%s\n' "$value"
}

_real_dir() {
    [ -d "$1" ] || return 1
    (cd "$1" && pwd -P)
}
