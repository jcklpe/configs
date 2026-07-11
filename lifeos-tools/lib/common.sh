#!/usr/bin/env bash
##- lifeos common helpers: generic primitives plus the shared LifeOS runtime infrastructure used by every feature module.
##- Sourced by lifeos.sh after the bootstrap vars (SCRIPT_DIR, CONFIGS, ENV_FILE) are set, and before the feature modules, which depend on these functions.
##- Generic primitives (output, string, env, var, path) come first; shared infrastructure (vault access, source-snapshot dirs, command checks) follows.

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

##- Shared LifeOS infrastructure.
_vault_path() {
    _path_value LIFEOS_VAULT_PATH
}

_vault_ready() {
    local vault repo

    _require_var LIFEOS_VAULT_PATH || return 1
    vault="$(_vault_path)"

    if [ ! -d "$vault" ]; then
        _err "LIFEOS_VAULT_PATH does not exist: $vault"
        return 1
    fi

    vault="$(_real_dir "$vault")" || return 1
    repo="$(_real_dir "$CONFIGS")" || return 1

    case "$vault" in
        "$repo"|"$repo"/*)
            _err "LIFEOS_VAULT_PATH points inside this configs repo: $vault"
            return 1
            ;;
    esac

    return 0
}

_sources_dir() {
    printf '%s/sources\n' "$(_vault_path)"
}

_ensure_sources_dir() {
    local dir
    dir="$(_sources_dir)"
    [ -d "$dir" ] || mkdir -p "$dir"
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

