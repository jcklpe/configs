#!/usr/bin/env bash
##- Slack as the user's own account: thin wrapper over lib/slack.py.

_slack_dispatch() {
    if [ "${1:-}" = "sync" ]; then
        shift
        _slack_sync "$@"
        return
    fi
    SECRETS_DIR="$SECRETS_DIR" "$LIFEOS_PY" "${LIB_DIR}/slack.py" "$@"
}

##- Snapshot each account's configured Slack Lists into sources/slack/<alias>/list-<name>.md.
_slack_sync() {
    local custom_out="" only_alias="" dest

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) custom_out="${QA_DIR}/slack-qa"; shift ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires DIR"; return 1; }
                custom_out="$2"; shift 2 ;;
            -*) _err "Unknown slack sync option: $1"; return 1 ;;
            *) only_alias="$1"; shift ;;
        esac
    done

    if [ -n "$custom_out" ]; then
        dest="$custom_out"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        dest="$(_sources_dir)/slack"
    fi
    mkdir -p "$dest" || return 1

    if [ -n "$only_alias" ]; then
        SECRETS_DIR="$SECRETS_DIR" "$LIFEOS_PY" "${LIB_DIR}/slack.py" sync "$only_alias" --output "$dest"
    else
        SECRETS_DIR="$SECRETS_DIR" "$LIFEOS_PY" "${LIB_DIR}/slack.py" sync --output "$dest"
    fi
}
