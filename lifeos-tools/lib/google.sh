#!/usr/bin/env bash
##- lifeos Google ecosystem: Calendar, Gmail, Drive, Sheets, and People, plus the shared Google OAuth and account-alias layer they all authenticate through. Includes the Google-local _urlencode helper.
##- Sourced by lifeos.sh; depends on lib/common.sh and the bootstrap vars. Large and cohesive; could be split into per-service modules later if that ever pays off.

_calendar_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-calendar-auth.py" "$@"
}

_calendar_render_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-calendar-render.py" "$@"
}

_calendar_ready() {
    _require_var GOOGLE_CALENDAR_CREDENTIALS_PATH || return 1
    _require_var GOOGLE_CALENDAR_TOKEN_PATH || return 1
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    _check_command python3 >/dev/null || { _err "python3 is required"; return 1; }
    if [ ! -f "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" ]; then
        _err "Google Calendar credentials file does not exist: $(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)"
        return 1
    fi
    return 0
}

_calendar_token_ready() {
    _calendar_ready || return 1
    if [ ! -f "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)" ]; then
        _err "Google Calendar token file does not exist: $(_path_value GOOGLE_CALENDAR_TOKEN_PATH)"
        _say "NEXT: run './lifeos.sh calendar auth'"
        return 1
    fi
    return 0
}

_calendar_auth() {
    _calendar_ready || return 1
    _calendar_helper auth "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)"
}

_calendar_access_token() {
    _calendar_token_ready || return 1
    _calendar_helper access-token "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)"
}

_calendar_get() {
    local endpoint="$1"
    local token
    shift
    token="$(_calendar_access_token)" || return 1
    curl -fsS --get "https://www.googleapis.com/calendar/v3${endpoint}" \
        -H "Authorization: Bearer ${token}" \
        "$@"
}

_calendar_write() {
    local method="$1" endpoint="$2" body="$3"
    local token
    shift 3
    token="$(_calendar_access_token)" || return 1
    curl -fsS -X "$method" "https://www.googleapis.com/calendar/v3${endpoint}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$body" \
        "$@"
}

_people_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-people.py" "$@"
}

_calendar_write_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-calendar-write.py" "$@"
}

_urlencode() {
    jq -rn --arg value "$1" '$value | @uri'
}

_google_accounts_path() {
    if _var_is_set GOOGLE_ACCOUNTS_PATH; then
        _path_value GOOGLE_ACCOUNTS_PATH
    else
        printf '%s/google-accounts.json\n' "$SECRETS_DIR"
    fi
}

_tool_path() {
    local value="$1"
    case "$value" in
        '') return 1 ;;
        /*) printf '%s\n' "$value" ;;
        ~/*) printf '%s/%s\n' "$HOME" "${value#~/}" ;;
        \$CONFIGS/*) printf '%s/%s\n' "$CONFIGS" "${value#\$CONFIGS/}" ;;
        \$HOME/*) printf '%s/%s\n' "$HOME" "${value#\$HOME/}" ;;
        *) printf '%s/%s\n' "$SECRETS_DIR" "$value" ;;
    esac
}

_google_accounts_ready() {
    local config
    config="$(_google_accounts_path)"
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    _check_command python3 >/dev/null || { _err "python3 is required"; return 1; }
    if [ ! -f "$config" ]; then
        _err "Google account config does not exist: $config"
        _say "NEXT: cp ${SECRETS_DIR}/google-accounts.example.json $config"
        return 1
    fi
    return 0
}

_google_account_exists() {
    local alias="$1"
    _google_accounts_ready || return 1
    jq -e --arg alias "$alias" 'any(.accounts[]?; .alias == $alias)' "$(_google_accounts_path)" >/dev/null
}

_google_account_value() {
    local alias="$1"
    local filter="$2"
    jq -er --arg alias "$alias" "(.accounts[]? | select(.alias == \$alias) | ${filter}) // empty" "$(_google_accounts_path)"
}

_google_account_path() {
    local alias="$1"
    local filter="$2"
    local value
    value="$(_google_account_value "$alias" "$filter")" || return 1
    _tool_path "$value"
}

_google_account_email() {
    local alias="$1"
    _google_account_value "$alias" '.email // ""' 2>/dev/null || printf ''
}

_google_accounts_list() {
    _google_accounts_ready || return 1
    jq -r '
      (.accounts // [])[] |
      "- " + (.alias // "missing-alias") +
      " | email: " + (.email // "") +
      " | gmail: " + (((.gmail.enabled // false) == true) | tostring) +
      " | gmail labels: " + (((.gmail.write_enabled // false) == true) | tostring) +
      " | drive: " + (((.drive.enabled // false) == true) | tostring)
    ' "$(_google_accounts_path)"
}

_google_enabled_aliases() {
    local service="$1"
    _google_accounts_ready || return 1
    jq -r --arg service "$service" '
      (.accounts // [])[] |
      select((.[$service].enabled // false) == true) |
      .alias
    ' "$(_google_accounts_path)"
}

_google_account_scopes() {
    local alias="$1"
    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    jq -r --arg alias "$alias" '
      (.accounts[]? | select(.alias == $alias)) as $account |
      [
        (if (($account.gmail.enabled // false) == true) then
          "https://www.googleapis.com/auth/gmail.readonly",
          (if (($account.gmail.write_enabled // false) == true) then
            "https://www.googleapis.com/auth/gmail.modify"
          else empty end)
        else empty end),
        (if (($account.drive.enabled // false) == true) then
          "https://www.googleapis.com/auth/drive.metadata.readonly",
          "https://www.googleapis.com/auth/drive.readonly",
          "https://www.googleapis.com/auth/spreadsheets.readonly",
          (if (($account.drive.write_enabled // false) == true) then
            "https://www.googleapis.com/auth/drive.file"
          else empty end)
        else empty end)
      ] | .[]
    ' "$(_google_accounts_path)"
}

_google_oauth_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-oauth.py" "$@"
}

_google_auth() {
    local alias="${1:-}" credentials_path token_path no_browser="" docs_write="" docs_comment=""
    local scopes=() scope

    [ -n "$alias" ] || { _err "google auth requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-browser) no_browser="--no-browser"; shift ;;
            --docs-write) docs_write="1"; shift ;;
            --docs-comment) docs_comment="1"; shift ;;
            *) _err "Unknown google auth option: $1"; return 1 ;;
        esac
    done

    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    credentials_path="$(_google_account_path "$alias" '.credentials_path // "google-credentials.json"')" || return 1
    token_path="$(_google_account_path "$alias" '.token_path')" || { _err "Google account '$alias' needs token_path"; return 1; }
    if [ ! -f "$credentials_path" ]; then
        _err "Google credentials file does not exist: $credentials_path"
        return 1
    fi

    while IFS= read -r scope || [ -n "$scope" ]; do
        [ -n "$scope" ] || continue
        scopes+=( "$scope" )
    done <<EOF
$(_google_account_scopes "$alias")
EOF

    if [ "$docs_write" = "1" ]; then
        scopes+=( "https://www.googleapis.com/auth/documents" )
    fi
    # Drive comments on files this app did not create need the full Drive scope; drive.file cannot reach them.
    if [ "$docs_comment" = "1" ]; then
        scopes+=( "https://www.googleapis.com/auth/drive" )
    fi

    if [ "${#scopes[@]}" -eq 0 ]; then
        _err "Google account '$alias' has no enabled Gmail or Drive scopes"
        return 1
    fi

    if [ -n "$no_browser" ]; then
        _google_oauth_helper auth "$credentials_path" "$token_path" "${scopes[@]}" "$no_browser"
    else
        _google_oauth_helper auth "$credentials_path" "$token_path" "${scopes[@]}"
    fi
}

_google_access_token() {
    local alias="$1" credentials_path token_path
    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    credentials_path="$(_google_account_path "$alias" '.credentials_path // "google-credentials.json"')" || return 1
    token_path="$(_google_account_path "$alias" '.token_path')" || { _err "Google account '$alias' needs token_path"; return 1; }
    if [ ! -f "$token_path" ]; then
        _err "Google token file does not exist for alias '$alias': $token_path"
        _say "NEXT: run './lifeos.sh google auth $alias'" >&2
        return 1
    fi
    _google_oauth_helper access-token "$credentials_path" "$token_path"
}

_google_get_url() {
    local alias="$1"
    local url="$2"
    local token
    shift 2
    token="$(_google_access_token "$alias")" || return 1
    curl -fsS --get "$url" \
        -H "Authorization: Bearer ${token}" \
        "$@"
}

_docs_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-docs.py" "$@"
}

# _docs_run SUBCOMMAND ALIAS DOC_URL_OR_ID [extra python args...]
# General-purpose Google Docs read + one-exact-replacement. Ported into
# lifeos-tools from the org repo's tool so doc editing does not require an
# Open Austin checkout (see docs/decisions/docs-editing-in-lifeos-tools.md).
_docs_run() {
    local sub="${1:-}" alias="${2:-}" raw="${3:-}" doc_id token
    [ -n "$sub" ] || { _err "docs requires a subcommand (read|replace-once|set-body|comments|comment)"; return 1; }
    [ -n "$alias" ] || { _err "docs $sub requires ALIAS"; return 1; }
    [ -n "$raw" ] || { _err "docs $sub requires DOC_URL_OR_ID"; return 1; }
    shift 3
    doc_id="$(_drive_file_id "$raw")" || return 1
    token="$(_google_access_token "$alias")" || return 1
    GOOGLE_ACCESS_TOKEN="$token" LIFEOS_DOCS_ALIAS="$alias" _docs_helper "$sub" --document-id "$doc_id" "$@"
}

_gmail_query() {
    local alias="$1"
    _google_account_value "$alias" '.gmail.query // "in:inbox newer_than:30d -label:Newsletters"' 2>/dev/null || printf 'in:inbox newer_than:30d -label:Newsletters'
}

_gmail_max_results() {
    local alias="$1"
    _google_account_value "$alias" '.gmail.max_results // 150' 2>/dev/null || printf '150'
}

_gmail_body_limit() {
    local alias="$1"
    _google_account_value "$alias" '.gmail.body_character_limit // 8000' 2>/dev/null || printf '8000'
}

_gmail_sources_dir() {
    printf '%s/gmail\n' "$(_sources_dir)"
}

_gmail_output_for_alias() {
    local alias="$1"
    local qa="$2"
    if [ "$qa" = "1" ]; then
        printf '%s/gmail-qa/%s.md\n' "$QA_DIR" "$alias"
    else
        printf '%s/%s.md\n' "$(_gmail_sources_dir)" "$alias"
    fi
}

_gmail_render_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-gmail-render.py" "$@"
}

# GET a Gmail API URL, surfacing Google's error message and backing off on rate limits. Gmail enforces a per-user query-cost quota per minute, and a full-format sync of a busy inbox can exceed it.
_gmail_get() {
    local alias="$1" url="$2" token response http_code reason message attempt=0 delay=2
    shift 2
    response="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-get.XXXXXX")" || return 1
    while :; do
        token="$(_google_access_token "$alias")" || { rm -f "$response"; return 1; }
        http_code="$(curl -sS -o "$response" -w '%{http_code}' --get "$url" -H "Authorization: Bearer ${token}" "$@")" || { rm -f "$response"; _err "Gmail request failed before receiving a response"; return 1; }
        case "$http_code" in
            2??) cat "$response"; rm -f "$response"; return 0 ;;
        esac
        reason="$(jq -r '.error.errors[0].reason // .error.status // empty' "$response" 2>/dev/null)"
        message="$(jq -r '.error.message // empty' "$response" 2>/dev/null)"
        case "$http_code:$reason" in
            429:*|403:rateLimitExceeded|403:userRateLimitExceeded)
                attempt=$((attempt + 1))
                if [ "$attempt" -le "${LIFEOS_GMAIL_MAX_RETRIES:-5}" ]; then
                    _warn "Gmail rate limit for '$alias' (HTTP $http_code); retrying in ${delay}s (attempt $attempt)"
                    sleep "$delay"
                    delay=$((delay * 2))
                    continue
                fi
                ;;
        esac
        rm -f "$response"
        _err "Gmail returned HTTP ${http_code} for '$alias'${reason:+ ($reason)}: ${message:-request failed}"
        case "$reason" in
            rateLimitExceeded|userRateLimitExceeded) _say "NEXT: wait a minute and retry, or narrow the sync with --query or --max-results" >&2 ;;
            insufficientPermissions|ACCESS_TOKEN_SCOPE_INSUFFICIENT) _say "NEXT: run 'lifeos google auth $alias' to refresh the granted scopes" >&2 ;;
        esac
        return 1
    done
}

_gmail_sync_alias() {
    local alias="$1"
    local out="$2"
    local query_override="${3:-}" max_override="${4:-}"
    local query max_results body_limit email_address refreshed
    local list_file msg_dir messages_file message_id message_file count

    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    query="${query_override:-$(_gmail_query "$alias")}"
    max_results="${max_override:-$(_gmail_max_results "$alias")}"
    body_limit="$(_gmail_body_limit "$alias")"
    email_address="$(_google_account_email "$alias")"
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    _ensure_parent_dir "$out" || return 1
    list_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-list.XXXXXX")" || return 1
    msg_dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-gmail-messages.XXXXXX")" || return 1
    messages_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-render.XXXXXX")" || return 1

    _say "Syncing Gmail: ${alias}" >&2
    _gmail_get "$alias" "https://gmail.googleapis.com/gmail/v1/users/me/messages" \
        --data-urlencode "q=${query}" \
        --data-urlencode "maxResults=${max_results}" > "$list_file" || return 1

    count=0
    for message_id in $(jq -r '.messages[]?.id' "$list_file"); do
        message_file="${msg_dir}/$(printf '%05d' "$count").json"
        _gmail_get "$alias" "https://gmail.googleapis.com/gmail/v1/users/me/messages/${message_id}" \
            --data-urlencode "format=full" > "$message_file" || return 1
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        jq -n '{messages: []}' > "$messages_file"
    else
        jq -s '{messages: .}' "${msg_dir}"/*.json > "$messages_file"
    fi

    _gmail_render_helper "$alias" "$email_address" "$query" "$max_results" "$body_limit" "$refreshed" "$messages_file" > "$out" || return 1
    _say "Updated $out"
}

_gmail_write_index() {
    local dir="$1"
    local refreshed="$2"
    shift 2
    {
        printf '# Gmail\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf '## Account Snapshots\n\n'
        for alias in "$@"; do
            printf -- '- [%s](%s.md)\n' "$alias" "$alias"
        done
    } > "${dir}/index.md"
}

_gmail_sync() {
    local all=0 qa=0 custom_out="" alias aliases="" out dir refreshed query_override="" max_override="" failed="" synced=""

    case "${1:-}" in
        --all) all=1; shift ;;
        '') _err "gmail sync requires ALIAS or --all"; return 1 ;;
        *) alias="$1"; shift ;;
    esac

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) qa=1; shift ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            --query)
                [ -n "${2:-}" ] || { _err "--query requires a Gmail search"; return 1; }
                query_override="$2"
                shift 2
                ;;
            --max-results)
                case "${2:-}" in ''|*[!0-9]*) _err "--max-results requires a positive integer"; return 1 ;; esac
                max_override="$2"
                shift 2
                ;;
            *) _err "Unknown gmail sync option: $1"; return 1 ;;
        esac
    done

    if [ "$all" -eq 1 ]; then
        [ -z "$custom_out" ] || { _err "gmail sync --all does not support --output"; return 1; }
        # The vault snapshots record the configured query; overrides are for one-off runs into --output or --qa files.
        if [ "$qa" -ne 1 ] && { [ -n "$query_override" ] || [ -n "$max_override" ]; }; then
            _err "gmail sync --all only accepts --query or --max-results together with --qa"
            return 1
        fi
        aliases="$(_google_enabled_aliases gmail)" || return 1
        [ -n "$aliases" ] || { _err "No Gmail-enabled Google aliases configured"; return 1; }
        if [ "$qa" -eq 1 ]; then
            dir="${QA_DIR}/gmail-qa"
        else
            _vault_ready || return 1
            _ensure_sources_dir || return 1
            dir="$(_gmail_sources_dir)"
        fi
        [ -d "$dir" ] || mkdir -p "$dir"
        # One failing account must not hide the others: sync each, then report every failure.
        for alias in $aliases; do
            if _gmail_sync_alias "$alias" "${dir}/${alias}.md" "$query_override" "$max_override"; then
                synced="$synced $alias"
            else
                failed="$failed $alias"
            fi
        done
        refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        _gmail_write_index "$dir" "$refreshed" $aliases
        _say "Updated ${dir}/index.md"
        if [ -n "$failed" ]; then
            _err "Gmail sync failed for:${failed} (their snapshots were left unchanged)${synced:+; synced:${synced}}"
            return 1
        fi
        return 0
    fi

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    elif [ "$qa" -eq 1 ]; then
        out="$(_gmail_output_for_alias "$alias" 1)"
    else
        if [ -n "$query_override" ] || [ -n "$max_override" ]; then
            _err "--query and --max-results are for one-off runs; combine them with --output FILE or --qa so the vault snapshot keeps its configured query"
            return 1
        fi
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_gmail_output_for_alias "$alias" 0)"
    fi
    _gmail_sync_alias "$alias" "$out" "$query_override" "$max_override"
}

##- Gmail labels and archiving. Reads (labels, list) use the read-only scope; executed changes also need gmail.write_enabled, which adds gmail.modify at the next 'lifeos google auth ALIAS'.
##- The only label changes are removing or restoring INBOX (archive and unarchive), adding or removing user labels, and moving mail out of Spam (not-spam). There is no trash, delete, report-spam, send, or mark-read command, and messages in Trash, or in Spam outside not-spam, are refused.
_GMAIL_API='https://gmail.googleapis.com/gmail/v1/users/me'

_gmail_require_enabled() {
    local alias="$1"
    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    if ! _google_account_value "$alias" '(.gmail.enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Gmail is not enabled for alias '$alias'"
        return 1
    fi
}

_gmail_require_write() {
    local alias="$1"
    if ! _google_account_value "$alias" '(.gmail.write_enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Gmail label changes are not enabled for alias '$alias'"
        _say "NEXT: set gmail.write_enabled to true for '$alias' in $(_google_accounts_path), then run 'lifeos google auth $alias' to grant gmail.modify" >&2
        return 1
    fi
}

_gmail_change_cap() {
    _google_account_value "$1" '.gmail.max_changes_per_call // 50' 2>/dev/null || printf '50'
}

# _gmail_send METHOD ALIAS URL BODY: a Gmail write that surfaces Google's error message instead of curl's bare status.
_gmail_send() {
    local method="$1" alias="$2" url="$3" body="$4" token response http_code message
    token="$(_google_access_token "$alias")" || return 1
    response="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-response.XXXXXX")" || return 1
    http_code="$(curl -sS -o "$response" -w '%{http_code}' -X "$method" "$url" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$body")" || { _err "Gmail request failed before receiving a response"; return 1; }
    case "$http_code" in
        2??) cat "$response" ;;
        *)
            message="$(jq -r '.error.message // empty' "$response" 2>/dev/null)"
            _err "Gmail returned HTTP ${http_code}: ${message:-request failed}"
            if [ "$http_code" = "403" ]; then
                _say "NEXT: if the token predates gmail.write_enabled, run 'lifeos google auth $alias' to grant gmail.modify" >&2
            fi
            return 1
            ;;
    esac
}

_gmail_labels_fetch() {
    _google_get_url "$1" "${_GMAIL_API}/labels"
}

_gmail_labels() {
    local alias="${1:-}" json_mode=0 labels
    [ -n "$alias" ] || { _err "gmail labels requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json_mode=1; shift ;;
            *) _err "Unknown gmail labels option: $1"; return 1 ;;
        esac
    done
    _gmail_require_enabled "$alias" || return 1
    labels="$(_gmail_labels_fetch "$alias")" || return 1
    if [ "$json_mode" -eq 1 ]; then
        printf '%s\n' "$labels"
    else
        printf '%s' "$labels" | jq -r '(.labels // []) | sort_by([.type != "user", (.name | ascii_downcase)]) | .[] | "- " + .name + " | id: " + .id + " | type: " + .type'
    fi
}

# Resolve SPEC (an exact label ID or a case-insensitive label name) to a user label and print it as JSON. System labels are refused; INBOX is changed only by archive and unarchive.
_gmail_resolve_user_label() {
    local labels="$1" spec="$2" match
    match="$(printf '%s' "$labels" | jq -c --arg s "$spec" '[(.labels // [])[] | select(.id == $s or ((.name | ascii_downcase) == ($s | ascii_downcase)))] | first // empty')"
    if [ -z "$match" ]; then
        _err "No Gmail label matches '$spec'. Run 'lifeos gmail labels ALIAS' to see labels, or 'lifeos gmail create-label' to make one."
        return 1
    fi
    if [ "$(printf '%s' "$match" | jq -r '.type')" != "user" ]; then
        _err "'$spec' is a Gmail system label; only user labels can be applied or removed (use gmail archive or unarchive for INBOX)"
        return 1
    fi
    printf '%s\n' "$match"
}

_gmail_list() {
    local alias="${1:-}" label_spec="" query="" limit=25 json_mode=0 labels label list dir id n=0 args=()
    [ -n "$alias" ] || { _err "gmail list requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --label) [ -n "${2:-}" ] || { _err "--label requires NAME or ID"; return 1; }; label_spec="$2"; shift 2 ;;
            --query) [ -n "${2:-}" ] || { _err "--query requires a Gmail search"; return 1; }; query="$2"; shift 2 ;;
            --limit) [ -n "${2:-}" ] || { _err "--limit requires N"; return 1; }; limit="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown gmail list option: $1"; return 1 ;;
        esac
    done
    [ -n "$label_spec" ] || [ -n "$query" ] || { _err "gmail list requires --label or --query"; return 1; }
    case "$limit" in ''|*[!0-9]*) _err "--limit must be a positive integer"; return 1 ;; esac
    [ "$limit" -ge 1 ] && [ "$limit" -le 100 ] || { _err "--limit must be between 1 and 100"; return 1; }
    _gmail_require_enabled "$alias" || return 1
    args=(--data-urlencode "maxResults=${limit}")
    if [ -n "$label_spec" ]; then
        labels="$(_gmail_labels_fetch "$alias")" || return 1
        label="$(printf '%s' "$labels" | jq -c --arg s "$label_spec" '[(.labels // [])[] | select(.id == $s or ((.name | ascii_downcase) == ($s | ascii_downcase)))] | first // empty')"
        [ -n "$label" ] || { _err "No Gmail label matches '$label_spec'. Run 'lifeos gmail labels $alias'."; return 1; }
        args+=(--data-urlencode "labelIds=$(printf '%s' "$label" | jq -r '.id')")
    fi
    [ -n "$query" ] && args+=(--data-urlencode "q=${query}")
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-gmail-list.XXXXXX")" || return 1
    list="$(_google_get_url "$alias" "${_GMAIL_API}/messages" "${args[@]}")" || return 1
    for id in $(printf '%s' "$list" | jq -r '.messages[]?.id'); do
        _google_get_url "$alias" "${_GMAIL_API}/messages/${id}" \
            --data-urlencode "format=metadata" \
            --data-urlencode "metadataHeaders=From" \
            --data-urlencode "metadataHeaders=Subject" \
            --data-urlencode "metadataHeaders=Date" > "${dir}/$(printf '%04d' "$n").json" || return 1
        n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then printf '[]\n' > "${dir}/all.json"; else jq -s '.' "${dir}"/0*.json > "${dir}/all.json"; fi
    if [ "$json_mode" -eq 1 ]; then
        cat "${dir}/all.json"
    elif [ "$n" -eq 0 ]; then
        _say "No matching Gmail messages."
    else
        jq -r '.[] |
          ((.payload.headers // []) | map({key: (.name | ascii_downcase), value: .value}) | from_entries) as $h |
          "- " + ($h.date // "") + " | from: " + ($h.from // "") + " | " + ($h.subject // "(no subject)") +
          " | labels: " + ((.labelIds // []) | join(",")) +
          "\n  message_id: " + .id + " | thread_id: " + .threadId
        ' "${dir}/all.json"
    fi
}

# Shared engine for archive, unarchive, label, and unlabel. ADD and REMOVE are JSON arrays of label IDs. PRECONDITION is "in-inbox", "not-in-inbox", or empty.
_gmail_change_run() {
    local alias="$1" action="$2" add="$3" remove="$4" precondition="$5" execute="$6" describe="$7" ids_file="$8"
    local dir cap count kind id n=0 ts failures
    _gmail_require_enabled "$alias" || return 1
    count="$(jq 'length' "$ids_file")"
    [ "$count" -gt 0 ] || { _err "gmail $action requires at least one --message ID, --thread ID, or --ids-file"; return 1; }
    cap="$(_gmail_change_cap "$alias")"
    [ "$count" -le "$cap" ] || { _err "gmail $action accepts at most $cap targets per call (got $count); split the list"; return 1; }
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-gmail-change.XXXXXX")" || return 1
    # Fetch each target so missing IDs fail up front and the plan can show what will change.
    while IFS=$'\t' read -r kind id; do
        if [ "$kind" = "thread" ]; then
            _google_get_url "$alias" "${_GMAIL_API}/threads/${id}" --data-urlencode "format=metadata" --data-urlencode "metadataHeaders=From" --data-urlencode "metadataHeaders=Subject" > "${dir}/t-${n}.json" \
                || printf '{"missing": true}\n' > "${dir}/t-${n}.json"
        else
            _google_get_url "$alias" "${_GMAIL_API}/messages/${id}" --data-urlencode "format=metadata" --data-urlencode "metadataHeaders=From" --data-urlencode "metadataHeaders=Subject" > "${dir}/t-${n}.json" \
                || printf '{"missing": true}\n' > "${dir}/t-${n}.json"
        fi
        jq -c --arg kind "$kind" --arg id "$id" '
          (if $kind == "thread" then (.messages // []) else [.] end) as $msgs |
          ($msgs[0] // {}) as $first |
          ((($first.payload.headers // []) | map({key: (.name | ascii_downcase), value: .value}) | from_entries)) as $h |
          {kind: $kind, id: $id, missing: (.missing // false),
           messageIds: [$msgs[] | .id | select(. != null)],
           labels: ([$msgs[] | (.labelIds // [])[]] | unique),
           subject: ($h.subject // "(no subject)"), from: ($h.from // ""), count: ($msgs | length)}
        ' "${dir}/t-${n}.json" >> "${dir}/targets.jsonl"
        n=$((n + 1))
    done < <(jq -r '.[] | [.kind, .id] | @tsv' "$ids_file")
    jq -s '.' "${dir}/targets.jsonl" > "${dir}/targets.json"
    if jq -e 'any(.[]; .missing)' "${dir}/targets.json" >/dev/null; then
        _err "These Gmail IDs were not found; nothing was changed:"
        jq -r '.[] | select(.missing) | "  - " + .kind + " " + .id' "${dir}/targets.json" >&2
        return 1
    fi
    # Spam is off limits except to not-spam, whose whole job is to rescue it; Trash is always off limits.
    if [ "$precondition" = "in-spam" ]; then
        if jq -e 'any(.[]; (.labels | index("TRASH")) or ((.labels | index("SPAM")) | not))' "${dir}/targets.json" >/dev/null; then
            _err "gmail $action only rescues mail that is currently in Spam (and not in Trash); nothing was changed. Out of place:"
            jq -r '.[] | select((.labels | index("TRASH")) or ((.labels | index("SPAM")) | not)) | "  - " + .subject + " | " + .kind + " " + .id' "${dir}/targets.json" >&2
            return 1
        fi
    elif jq -e 'any(.[]; (.labels | index("TRASH")) or (.labels | index("SPAM")))' "${dir}/targets.json" >/dev/null; then
        _err "Some targets are in Trash or Spam, which these commands never touch (use gmail not-spam to rescue Spam); nothing was changed:"
        jq -r '.[] | select((.labels | index("TRASH")) or (.labels | index("SPAM"))) | "  - " + .subject + " | " + .kind + " " + .id' "${dir}/targets.json" >&2
        return 1
    fi
    case "$precondition" in
        in-inbox)
            if jq -e 'any(.[]; (.labels | index("INBOX")) | not)' "${dir}/targets.json" >/dev/null; then
                _err "gmail $action only changes mail that is currently in the Inbox; nothing was changed. Not in Inbox:"
                jq -r '.[] | select((.labels | index("INBOX")) | not) | "  - " + .subject + " | " + .kind + " " + .id' "${dir}/targets.json" >&2
                return 1
            fi
            ;;
        not-in-inbox)
            if jq -e 'any(.[]; .labels | index("INBOX"))' "${dir}/targets.json" >/dev/null; then
                _err "gmail $action only restores mail that is not in the Inbox; nothing was changed. Already in Inbox:"
                jq -r '.[] | select(.labels | index("INBOX")) | "  - " + .subject + " | " + .kind + " " + .id' "${dir}/targets.json" >&2
                return 1
            fi
            ;;
    esac
    _say "Gmail $action plan:"
    _say "Account: $alias"
    _say "Change: $describe"
    _say "Targets: $count"
    jq -r '.[] | "- " + .kind + (if .kind == "thread" then " (" + (.count | tostring) + " messages)" else "" end) + " | " + .from + " | " + .subject' "${dir}/targets.json"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was changed. Re-run with --execute to apply."; return 0; fi
    _gmail_require_write "$alias" || return 1
    jq -c --argjson add "$add" --argjson remove "$remove" '{ids: [.[] | select(.kind == "message") | .id], addLabelIds: $add, removeLabelIds: $remove}' "${dir}/targets.json" > "${dir}/batch.json"
    if jq -e '.ids | length > 0' "${dir}/batch.json" >/dev/null; then
        _gmail_send POST "$alias" "${_GMAIL_API}/messages/batchModify" "$(cat "${dir}/batch.json")" >/dev/null || return 1
    fi
    for id in $(jq -r '.[] | select(.kind == "thread") | .id' "${dir}/targets.json"); do
        _gmail_send POST "$alias" "${_GMAIL_API}/threads/${id}/modify" "$(jq -cn --argjson add "$add" --argjson remove "$remove" '{addLabelIds: $add, removeLabelIds: $remove}')" >/dev/null || return 1
    done
    # Read back every affected message and confirm the added labels are present and the removed ones gone.
    : > "${dir}/readback.jsonl"
    for id in $(jq -r '.[].messageIds[]' "${dir}/targets.json"); do
        _google_get_url "$alias" "${_GMAIL_API}/messages/${id}" --data-urlencode "format=minimal" | jq -c '{id, labelIds: (.labelIds // [])}' >> "${dir}/readback.jsonl" || return 1
    done
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    jq -s --slurpfile t "${dir}/targets.json" --argjson add "$add" --argjson remove "$remove" '
      (map({key: .id, value: .labelIds}) | from_entries) as $now |
      [$t[0][] | . as $target |
        {kind, id, subject, from,
         verified: all(.messageIds[]; ($now[.] // null) as $l | $l != null and all($add[]; . as $a | $l | index($a)) and all($remove[]; . as $r | ($l | index($r)) | not))}]
    ' "${dir}/readback.jsonl" > "${dir}/results.json" || return 1
    jq -c --arg ts "$ts" --arg alias "$alias" --arg action "$action" --argjson add "$add" --argjson remove "$remove" '.[] | {ts: $ts, service: "gmail", alias: $alias, action: $action, target_kind: .kind, target_id: .id, add_labels: $add, remove_labels: $remove, sender: .from, subject: .subject, verified: .verified}' "${dir}/results.json" | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    jq -r '.[] | (if .verified then "- done: " else "- NOT CONFIRMED: " end) + .subject + " | " + .kind + " " + .id' "${dir}/results.json"
    failures="$(jq '[.[] | select(.verified | not)] | length' "${dir}/results.json")"
    if [ "$failures" -gt 0 ]; then
        _err "$failures of $count targets were not confirmed by readback"
        return 1
    fi
    _say "Applied to $count targets (confirmed by readback)."
}

# Parses shared target options into a JSON array file of {kind, id} at _GMAIL_TARGETS_FILE, plus _GMAIL_LABEL, _GMAIL_SKIP_INBOX, and _GMAIL_EXECUTE.
_gmail_change_args() {
    local command="$1" line
    shift
    _GMAIL_TARGETS_FILE="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-targets.XXXXXX")" || return 1
    _GMAIL_LABEL=""
    _GMAIL_SKIP_INBOX=0
    _GMAIL_EXECUTE=0
    : > "${_GMAIL_TARGETS_FILE}.tsv"
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --message) [ -n "${2:-}" ] || { _err "--message requires ID"; return 1; }; printf 'message\t%s\n' "$2" >> "${_GMAIL_TARGETS_FILE}.tsv"; shift 2 ;;
            --thread) [ -n "${2:-}" ] || { _err "--thread requires ID"; return 1; }; printf 'thread\t%s\n' "$2" >> "${_GMAIL_TARGETS_FILE}.tsv"; shift 2 ;;
            --ids-file)
                [ -n "${2:-}" ] || { _err "--ids-file requires FILE"; return 1; }
                _read_ids_file "$2" > /dev/null || return 1
                while IFS= read -r line; do
                    case "$line" in
                        message:*) printf 'message\t%s\n' "${line#message:}" ;;
                        thread:*) printf 'thread\t%s\n' "${line#thread:}" ;;
                        *) _err "Each --ids-file line must be message:ID or thread:ID (got '$line')"; return 1 ;;
                    esac
                done >> "${_GMAIL_TARGETS_FILE}.tsv" <<EOF
$(_read_ids_file "$2")
EOF
                shift 2
                ;;
            --label)
                case "$command" in label|unlabel) ;; *) _err "gmail $command does not take --label"; return 1 ;; esac
                [ -n "${2:-}" ] || { _err "--label requires NAME or ID"; return 1; }
                _GMAIL_LABEL="$2"; shift 2
                ;;
            --skip-inbox)
                [ "$command" = "label" ] || { _err "gmail $command does not take --skip-inbox"; return 1; }
                _GMAIL_SKIP_INBOX=1; shift
                ;;
            --execute) _GMAIL_EXECUTE=1; shift ;;
            --dry-run) _GMAIL_EXECUTE=0; shift ;;
            *) _err "Unknown gmail $command option: $1"; return 1 ;;
        esac
    done
    jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {kind: .[0], id: .[1]}) | unique_by([.kind, .id])' "${_GMAIL_TARGETS_FILE}.tsv" > "$_GMAIL_TARGETS_FILE"
}

_gmail_archive() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "gmail archive requires ALIAS"; return 1; }
    shift || true
    _gmail_change_args archive "$@" || return 1
    _gmail_change_run "$alias" archive '[]' '["INBOX"]' in-inbox "$_GMAIL_EXECUTE" "remove from Inbox (archive)" "$_GMAIL_TARGETS_FILE"
}

_gmail_unarchive() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "gmail unarchive requires ALIAS"; return 1; }
    shift || true
    _gmail_change_args unarchive "$@" || return 1
    _gmail_change_run "$alias" unarchive '["INBOX"]' '[]' not-in-inbox "$_GMAIL_EXECUTE" "return to Inbox" "$_GMAIL_TARGETS_FILE"
}

_gmail_label() {
    local alias="${1:-}" labels label label_id label_name remove='[]' describe precondition=""
    [ -n "$alias" ] || { _err "gmail label requires ALIAS"; return 1; }
    shift || true
    _gmail_change_args label "$@" || return 1
    [ -n "$_GMAIL_LABEL" ] || { _err "gmail label requires --label"; return 1; }
    _gmail_require_enabled "$alias" || return 1
    labels="$(_gmail_labels_fetch "$alias")" || return 1
    label="$(_gmail_resolve_user_label "$labels" "$_GMAIL_LABEL")" || return 1
    label_id="$(printf '%s' "$label" | jq -r '.id')"
    label_name="$(printf '%s' "$label" | jq -r '.name')"
    describe="add label '$label_name'"
    if [ "$_GMAIL_SKIP_INBOX" -eq 1 ]; then
        remove='["INBOX"]'
        describe="$describe and remove from Inbox"
    fi
    _gmail_change_run "$alias" label "$(jq -cn --arg id "$label_id" '[$id]')" "$remove" "$precondition" "$_GMAIL_EXECUTE" "$describe" "$_GMAIL_TARGETS_FILE"
}

_gmail_unlabel() {
    local alias="${1:-}" labels label label_id label_name
    [ -n "$alias" ] || { _err "gmail unlabel requires ALIAS"; return 1; }
    shift || true
    _gmail_change_args unlabel "$@" || return 1
    [ -n "$_GMAIL_LABEL" ] || { _err "gmail unlabel requires --label"; return 1; }
    _gmail_require_enabled "$alias" || return 1
    labels="$(_gmail_labels_fetch "$alias")" || return 1
    label="$(_gmail_resolve_user_label "$labels" "$_GMAIL_LABEL")" || return 1
    label_id="$(printf '%s' "$label" | jq -r '.id')"
    label_name="$(printf '%s' "$label" | jq -r '.name')"
    _gmail_change_run "$alias" unlabel '[]' "$(jq -cn --arg id "$label_id" '[$id]')" "" "$_GMAIL_EXECUTE" "remove label '$label_name'" "$_GMAIL_TARGETS_FILE"
}

# Spam review: list what Gmail filed as spam, and rescue false positives back to the Inbox. Spam is never part of gmail sync; these are for a deliberate periodic check.
_gmail_spam() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "gmail spam requires ALIAS"; return 1; }
    shift || true
    _gmail_list "$alias" --label SPAM "$@"
}

_gmail_not_spam() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "gmail not-spam requires ALIAS"; return 1; }
    shift || true
    _gmail_change_args not-spam "$@" || return 1
    _gmail_change_run "$alias" not-spam '["INBOX"]' '["SPAM"]' in-spam "$_GMAIL_EXECUTE" "remove from Spam and return to Inbox (not spam)" "$_GMAIL_TARGETS_FILE"
}

_gmail_create_label() {
    local alias="${1:-}" name="" execute=0 labels created ts
    [ -n "$alias" ] || { _err "gmail create-label requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name) [ -n "${2:-}" ] || { _err "--name requires TEXT"; return 1; }; name="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown gmail create-label option: $1"; return 1 ;;
        esac
    done
    [ -n "$name" ] || { _err "gmail create-label requires --name (use Parent/Child to nest)"; return 1; }
    _gmail_require_enabled "$alias" || return 1
    labels="$(_gmail_labels_fetch "$alias")" || return 1
    if printf '%s' "$labels" | jq -e --arg n "$name" 'any((.labels // [])[]; (.name | ascii_downcase) == ($n | ascii_downcase))' >/dev/null; then
        _err "A Gmail label named '$name' already exists"
        return 1
    fi
    _say "Gmail label create plan:"
    _say "Account: $alias"
    _say "New label: $name"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no label was created. Re-run with --execute to create it."; return 0; fi
    _gmail_require_write "$alias" || return 1
    created="$(_gmail_send POST "$alias" "${_GMAIL_API}/labels" "$(jq -cn --arg name "$name" '{name: $name, labelListVisibility: "labelShow", messageListVisibility: "show"}')")" || return 1
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '%s' "$created" | jq -c --arg ts "$ts" --arg alias "$alias" '{ts: $ts, service: "gmail", alias: $alias, action: "create-label", label_id: .id, label: .name}' | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    _say "Created label: $(printf '%s' "$created" | jq -r '.name + " | id: " + .id')"
}

_drive_accounts() {
    _google_accounts_ready || return 1
    jq -r '
      (.accounts // [])[] |
      select((.drive.enabled // false) == true) |
      "- " + (.alias // "missing-alias") + " | email: " + (.email // "")
    ' "$(_google_accounts_path)"
}

_drive_page_size() {
    local alias="$1"
    _google_account_value "$alias" '.drive.search_page_size // 20' 2>/dev/null || printf '20'
}

_drive_read_limit() {
    local alias="$1"
    _google_account_value "$alias" '.drive.read_character_limit // 20000' 2>/dev/null || printf '20000'
}

_drive_sheet_row_limit() {
    local alias="$1"
    _google_account_value "$alias" '.drive.sheet_row_limit // 200' 2>/dev/null || printf '200'
}

_drive_write_enabled() {
    local alias="$1"
    _google_account_value "$alias" '(.drive.write_enabled // false) == true' 2>/dev/null | grep -qx true
}

_drive_query_escape() {
    printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"
}

_drive_file_id() {
    local ref="$1"
    case "$ref" in
        *'/d/'*)
            ref="${ref#*/d/}"
            ref="${ref%%/*}"
            ;;
        *'id='*)
            ref="${ref#*id=}"
            ref="${ref%%&*}"
            ;;
    esac
    printf '%s\n' "$ref"
}

_drive_files_human() {
    jq -r '
      (.files // [])[] |
      "- " + (.name // "Untitled") +
      " | id: " + (.id // "") +
      " | type: " + (.mimeType // "") +
      " | modified: " + (.modifiedTime // "") +
      " | owner: " + (((.owners // []) | map(.emailAddress // .displayName // "") | map(select(. != "")) | join(", "))) +
      " | " + (.webViewLink // "")
    '
}

_drive_meta_human() {
    jq -r '
      "Name: " + (.name // "Untitled") + "\n" +
      "ID: " + (.id // "") + "\n" +
      "MIME type: " + (.mimeType // "") + "\n" +
      "Modified: " + (.modifiedTime // "") + "\n" +
      "Owners: " + (((.owners // []) | map(.emailAddress // .displayName // "") | map(select(. != "")) | join(", "))) + "\n" +
      "Parents: " + (((.parents // []) | join(", "))) + "\n" +
      "Drive ID: " + (.driveId // "") + "\n" +
      "URL: " + (.webViewLink // "")
    '
}

_drive_fetch_meta() {
    local alias="$1"
    local file_id="$2"
    _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files/${file_id}" \
        --data-urlencode "supportsAllDrives=true" \
        --data-urlencode "fields=id,name,mimeType,modifiedTime,webViewLink,owners(displayName,emailAddress),parents,driveId,size"
}

_drive_search() {
    local alias="${1:-}" query="${2:-}" json=0 page_size escaped q
    local result_file
    [ -n "$alias" ] || { _err "drive search requires ALIAS"; return 1; }
    [ -n "$query" ] || { _err "drive search requires QUERY"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown drive search option: $1"; return 1 ;;
        esac
    done
    page_size="$(_drive_page_size "$alias")"
    escaped="$(_drive_query_escape "$query")"
    q="trashed = false and (name contains '${escaped}' or fullText contains '${escaped}')"
    result_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-search.XXXXXX")" || return 1
    _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files" \
        --data-urlencode "q=${q}" \
        --data-urlencode "pageSize=${page_size}" \
        --data-urlencode "supportsAllDrives=true" \
        --data-urlencode "includeItemsFromAllDrives=true" \
        --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink,owners(displayName,emailAddress),parents,driveId),nextPageToken" > "$result_file" || return 1

    if [ "$json" -eq 1 ]; then
        cat "$result_file"
    else
        _drive_files_human < "$result_file"
    fi
}

_drive_list() {
    local alias="${1:-}" folder_id="${2:-}" json=0 q
    local result_file
    [ -n "$alias" ] || { _err "drive list requires ALIAS"; return 1; }
    [ -n "$folder_id" ] || { _err "drive list requires FOLDER_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown drive list option: $1"; return 1 ;;
        esac
    done
    q="'$(_drive_query_escape "$folder_id")' in parents and trashed = false"
    result_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-list.XXXXXX")" || return 1
    _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files" \
        --data-urlencode "q=${q}" \
        --data-urlencode "pageSize=$(_drive_page_size "$alias")" \
        --data-urlencode "supportsAllDrives=true" \
        --data-urlencode "includeItemsFromAllDrives=true" \
        --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink,owners(displayName,emailAddress),parents,driveId),nextPageToken" > "$result_file" || return 1

    if [ "$json" -eq 1 ]; then
        cat "$result_file"
    else
        _drive_files_human < "$result_file"
    fi
}

_drive_meta() {
    local alias="${1:-}" ref="${2:-}" json=0 file_id
    [ -n "$alias" ] || { _err "drive meta requires ALIAS"; return 1; }
    [ -n "$ref" ] || { _err "drive meta requires FILE_URL_OR_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown drive meta option: $1"; return 1 ;;
        esac
    done
    file_id="$(_drive_file_id "$ref")"
    if [ "$json" -eq 1 ]; then
        _drive_fetch_meta "$alias" "$file_id"
    else
        _drive_fetch_meta "$alias" "$file_id" | _drive_meta_human
    fi
}

_single_quote_sheet_name() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

_text_cap_file() {
    "$LIFEOS_PY" -c 'import sys
limit = int(sys.argv[1])
data = sys.stdin.read()
if len(data) <= limit:
    print(data, end="")
else:
    print(data[:limit].rstrip(), end="")
    print("\n\n[content truncated]")' "$1"
}

_drive_read() {
    local alias="${1:-}" ref="${2:-}" range="" file_id meta_file mime name limit content_file
    local sheet_meta_file values_file sheet_title escaped_title encoded_range
    [ -n "$alias" ] || { _err "drive read requires ALIAS"; return 1; }
    [ -n "$ref" ] || { _err "drive read requires FILE_URL_OR_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --range) [ -n "${2:-}" ] || { _err "--range requires RANGE"; return 1; }; range="$2"; shift 2 ;;
            *) _err "Unknown drive read option: $1"; return 1 ;;
        esac
    done

    file_id="$(_drive_file_id "$ref")"
    meta_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-meta.XXXXXX")" || return 1
    _drive_fetch_meta "$alias" "$file_id" > "$meta_file" || return 1
    mime="$(jq -r '.mimeType // ""' "$meta_file")"
    name="$(jq -r '.name // "Untitled"' "$meta_file")"

    case "$mime" in
        application/vnd.google-apps.document)
            content_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-doc.XXXXXX")" || return 1
            _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files/${file_id}/export" \
                --data-urlencode "mimeType=text/plain" > "$content_file" || return 1
            limit="$(_drive_read_limit "$alias")"
            printf '# Google Doc - %s\n\n' "$name"
            printf 'Account alias: `%s`\n\n' "$alias"
            printf 'File ID: `%s`\n\n' "$file_id"
            _text_cap_file "$limit" < "$content_file"
            ;;
        application/vnd.google-apps.spreadsheet)
            sheet_meta_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-sheet-meta.XXXXXX")" || return 1
            values_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-sheet-values.XXXXXX")" || return 1
            _google_get_url "$alias" "https://sheets.googleapis.com/v4/spreadsheets/${file_id}" \
                --data-urlencode "fields=properties(title),sheets(properties(sheetId,title,gridProperties(rowCount,columnCount)))" > "$sheet_meta_file" || return 1
            if [ -z "$range" ]; then
                sheet_title="$(jq -r '.sheets[0].properties.title // "Sheet1"' "$sheet_meta_file")"
                escaped_title="$(_single_quote_sheet_name "$sheet_title")"
                range="${escaped_title}!A1:Z$(_drive_sheet_row_limit "$alias")"
            fi
            encoded_range="$(_urlencode "$range")" || return 1
            _google_get_url "$alias" "https://sheets.googleapis.com/v4/spreadsheets/${file_id}/values/${encoded_range}" > "$values_file" || return 1
            "$LIFEOS_PY" "${LIB_DIR}/google-sheets-render.py" "$alias" "$file_id" "$sheet_meta_file" "$values_file"
            ;;
        *)
            _warn "Drive read supports Google Docs and Google Sheets for now. Showing metadata only."
            _drive_meta_human < "$meta_file"
            ;;
    esac
}

_drive_export_default_mime() {
    # native google mimeType -> default export mimeType (space) extension
    case "$1" in
        application/vnd.google-apps.document) printf 'application/pdf pdf' ;;
        application/vnd.google-apps.spreadsheet) printf 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet xlsx' ;;
        application/vnd.google-apps.presentation) printf 'application/pdf pdf' ;;
        application/vnd.google-apps.drawing) printf 'image/png png' ;;
        *) printf '' ;;
    esac
}

_drive_ext_for_mime() {
    case "$1" in
        application/pdf) printf 'pdf' ;;
        application/vnd.openxmlformats-officedocument.wordprocessingml.document) printf 'docx' ;;
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet) printf 'xlsx' ;;
        application/vnd.openxmlformats-officedocument.presentationml.presentation) printf 'pptx' ;;
        application/msword) printf 'doc' ;;
        application/vnd.ms-excel) printf 'xls' ;;
        text/plain) printf 'txt' ;;
        text/html) printf 'html' ;;
        text/csv) printf 'csv' ;;
        image/png) printf 'png' ;;
        image/jpeg) printf 'jpg' ;;
        image/gif) printf 'gif' ;;
        application/vnd.oasis.opendocument.text) printf 'odt' ;;
        application/zip) printf 'zip' ;;
        *) printf '' ;;
    esac
}

# drive download ALIAS FILE_URL_OR_ID [--out PATH] [--mime EXPORT_MIME] [--force]
# Binary files download byte-for-byte via alt=media; native Google files export
# (Doc->PDF, Sheet->XLSX, Slides->PDF, Drawing->PNG by default, override with --mime).
_drive_download() {
    local alias="${1:-}" ref="${2:-}" out="" export_mime="" force=0
    local file_id meta_file mime name is_native default_pair token url target dest_dir ext
    [ -n "$alias" ] || { _err "drive download requires ALIAS"; return 1; }
    [ -n "$ref" ] || { _err "drive download requires FILE_URL_OR_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --out) [ -n "${2:-}" ] || { _err "--out requires PATH"; return 1; }; out="$2"; shift 2 ;;
            --mime) [ -n "${2:-}" ] || { _err "--mime requires EXPORT_MIME"; return 1; }; export_mime="$2"; shift 2 ;;
            --force) force=1; shift ;;
            *) _err "Unknown drive download option: $1"; return 1 ;;
        esac
    done

    file_id="$(_drive_file_id "$ref")"
    meta_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-dl-meta.XXXXXX")" || return 1
    _drive_fetch_meta "$alias" "$file_id" > "$meta_file" || return 1
    mime="$(jq -r '.mimeType // ""' "$meta_file")"
    name="$(jq -r '.name // "download"' "$meta_file")"

    case "$mime" in
        application/vnd.google-apps.*) is_native=1 ;;
        *) is_native=0 ;;
    esac

    if [ "$is_native" -eq 1 ]; then
        if [ -z "$export_mime" ]; then
            default_pair="$(_drive_export_default_mime "$mime")"
            [ -n "$default_pair" ] || { _err "No default export format for Google type '$mime'. Pass --mime EXPORT_MIME."; return 1; }
            export_mime="${default_pair%% *}"
        fi
        ext="$(_drive_ext_for_mime "$export_mime")"
    else
        ext="$(_drive_ext_for_mime "$mime")"
    fi

    if [ -z "$out" ]; then
        target="./$name"
    elif [ -d "$out" ]; then
        target="${out%/}/$name"
    else
        target="$out"
    fi
    # Native exports carry the resulting format's extension when the target lacks it.
    if [ "$is_native" -eq 1 ] && [ -n "$ext" ]; then
        case "$target" in
            *.$ext) : ;;
            *) target="${target}.${ext}" ;;
        esac
    fi

    if [ -e "$target" ] && [ "$force" -ne 1 ]; then
        _err "Refusing to overwrite existing file: $target (use --force)"; return 1
    fi
    dest_dir="$(dirname "$target")"
    [ -d "$dest_dir" ] || { _err "Destination directory does not exist: $dest_dir"; return 1; }

    token="$(_google_access_token "$alias")" || return 1
    if [ "$is_native" -eq 1 ]; then
        url="https://www.googleapis.com/drive/v3/files/${file_id}/export?mimeType=$(_urlencode "$export_mime")&supportsAllDrives=true"
    else
        url="https://www.googleapis.com/drive/v3/files/${file_id}?alt=media&supportsAllDrives=true"
    fi

    if ! curl -fsSL -o "$target" "$url" -H "Authorization: Bearer ${token}"; then
        rm -f "$target"
        _err "Download failed (no access, or export unsupported for this type: $mime)"
        return 1
    fi

    _say "Downloaded: $target"
    _say "Source: $name ($mime)"
    if [ "$is_native" -eq 1 ]; then
        _say "Exported as: $export_mime"
    fi
}

##- Bounded Drive index. Orientation only, per LifeOS policy 0002 — top-level structure
##- plus recent activity, never a full mirror. `drive search` is the live lookup; this is
##- the "what is in here at all" layer that search cannot answer.
##- Excluded folders are a privacy boundary, not an omission: see the lifeos-drive skill.
##- Same shape as _m365_days_ago; kept local to this module rather than shared, since
##- the two feature modules are otherwise independent.
_drive_days_ago() {
    "$LIFEOS_PY" -c 'from datetime import datetime, timedelta, timezone; import sys; print((datetime.now(timezone.utc) - timedelta(days=int(sys.argv[1]))).replace(microsecond=0).isoformat().replace("+00:00", "Z"))' "$1"
}

_drive_sync_excludes() {
    local alias="$1"
    _google_account_value "$alias" '(.drive.index_exclude // ["journal"]) | join("\n")' 2>/dev/null || printf 'journal'
}

_drive_render_index() {
    "$LIFEOS_PY" "${LIB_DIR}/google-drive-render.py" "$@"
}

_drive_sync() {
    local alias="" custom_out="" out
    local max_folders=25 children=12 max_recent=30 recent_days=45

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) custom_out="${QA_DIR}/drive.md"; shift ;;
            --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;;
            --folders) max_folders="$2"; shift 2 ;;
            --recent) max_recent="$2"; shift 2 ;;
            --recent-days) recent_days="$2"; shift 2 ;;
            -*) _err "Unknown drive sync option: $1"; return 1 ;;
            *) alias="$1"; shift ;;
        esac
    done
    [ -n "$alias" ] || { _err "drive sync requires an account ALIAS (see: lifeos drive accounts)"; return 1; }

    local token email excludes exclude_clause folders_json recent_json payload
    token="$(_google_access_token "$alias")" || return 1
    email="$(_google_account_value "$alias" '.email // ""')"
    excludes="$(_drive_sync_excludes "$alias")"

    _say "Indexing Drive: $alias" >&2

    # Top-level folders under My Drive.
    folders_json="$(curl -sS -G "https://www.googleapis.com/drive/v3/files" \
        -H "Authorization: Bearer $token" \
        --data-urlencode "q='root' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false" \
        --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink)" \
        --data-urlencode "orderBy=name" \
        --data-urlencode "pageSize=$max_folders" 2>/dev/null | jq -c '.files // []')" || {
        _err "Drive folder listing failed for $alias"; return 1; }

    # Children of each folder, capped. Excluded folders are listed by name only.
    local enriched="[]" fid fname skipped="[]" kids kid_count
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        fid="$(printf '%s' "$row" | jq -r '.id')"
        fname="$(printf '%s' "$row" | jq -r '.name')"
        if printf '%b' "$excludes" | grep -qxF "$fname"; then
            skipped="$(printf '%s' "$skipped" | jq --arg n "$fname" '. + [$n]')"
            continue
        fi
        kids="$(curl -sS -G "https://www.googleapis.com/drive/v3/files" \
            -H "Authorization: Bearer $token" \
            --data-urlencode "q='$fid' in parents and trashed=false" \
            --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink)" \
            --data-urlencode "orderBy=folder,modifiedTime desc" \
            --data-urlencode "pageSize=$((children + 1))" 2>/dev/null | jq -c '.files // []')"
        [ -n "$kids" ] || kids="[]"
        kid_count="$(printf '%s' "$kids" | jq 'length')"
        enriched="$(printf '%s' "$enriched" | jq -c \
            --argjson f "$row" --argjson k "$kids" --argjson n "$kid_count" --argjson cap "$children" \
            '. + [$f + {children: ($k[0:$cap]), child_count: $n, child_truncated: ($n > $cap)}]')"
    done <<EOF_FOLDERS
$(printf '%s' "$folders_json" | jq -c '.[]')
EOF_FOLDERS

    # Recently modified files across the account.
    local since
    since="$(_drive_days_ago "$recent_days")"
    recent_json="$(curl -sS -G "https://www.googleapis.com/drive/v3/files" \
        -H "Authorization: Bearer $token" \
        --data-urlencode "q=modifiedTime > '${since}' and trashed=false and mimeType != 'application/vnd.google-apps.folder'" \
        --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink)" \
        --data-urlencode "orderBy=modifiedTime desc" \
        --data-urlencode "pageSize=$max_recent" 2>/dev/null | jq -c '.files // []')"
    [ -n "$recent_json" ] || recent_json="[]"

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/drive.md"
    fi
    _ensure_parent_dir "$out"

    payload="$(jq -n --arg a "$alias" --arg e "$email" \
        --argjson f "$enriched" --argjson r "$recent_json" --argjson s "$skipped" \
        --argjson mf "$max_folders" --argjson cpf "$children" --argjson mr "$max_recent" --argjson rd "$recent_days" \
        '{alias:$a, email:$e, folders:$f, recent:$r, skipped:$s,
          caps:{max_folders:$mf, children_per_folder:$cpf, max_recent:$mr, recent_days:$rd}}')"
    printf '%s' "$payload" | _drive_render_index > "$out" || return 1

    _say "  folders: $(printf '%s' "$enriched" | jq 'length') | recent: $(printf '%s' "$recent_json" | jq 'length') | skipped: $(printf '%s' "$skipped" | jq 'length')" >&2
    _say "Updated $out"
}

_drive_import_source_mime() {
    local source="$1"
    case "$source" in
        *.html|*.htm) printf 'text/html' ;;
        # Markdown gets its own type so Drive converts headings, lists, tables and emphasis into real Doc styles. Sending it as text/plain makes Google import the syntax literally, so the Doc shows "## Heading" and "**bold**" as visible characters. Confirmed against drive/v3/about?fields=importFormats, which lists text/markdown -> application/vnd.google-apps.document.
        *.md|*.markdown) printf 'text/markdown' ;;
        *.txt) printf 'text/plain' ;;
        *.rtf) printf 'application/rtf' ;;
        *.docx) printf 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ;;
        *.doc) printf 'application/msword' ;;
        *) printf 'text/plain' ;;
    esac
}

_drive_import_doc() {
    local alias="${1:-}" source_file="${2:-}" title="" folder="" execute=0
    local token metadata_file mime result_file
    [ -n "$alias" ] || { _err "drive import-doc requires ALIAS"; return 1; }
    [ -n "$source_file" ] || { _err "drive import-doc requires SOURCE_FILE"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --title) [ -n "${2:-}" ] || { _err "--title requires TITLE"; return 1; }; title="$2"; shift 2 ;;
            --folder) [ -n "${2:-}" ] || { _err "--folder requires FOLDER_ID"; return 1; }; folder="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            *) _err "Unknown drive import-doc option: $1"; return 1 ;;
        esac
    done

    [ -f "$source_file" ] || { _err "Source file does not exist: $source_file"; return 1; }
    [ -n "$title" ] || { _err "drive import-doc requires --title TITLE"; return 1; }
    _drive_write_enabled "$alias" || {
        _err "Drive import is not enabled for '$alias'. Set drive.write_enabled=true in google-accounts.json and re-run 'lifeos google auth $alias'."
        return 1
    }

    _say "Google Drive import-doc plan:"
    mime="$(_drive_import_source_mime "$source_file")"
    _say "Account: $alias"
    _say "Source: $source_file"
    _say "Upload type: $mime"
    _say "Title: $title"
    if [ -n "$folder" ]; then
        _say "Folder: $folder"
    else
        _say "Folder: <default Drive location>"
    fi

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: add --execute to create the Google Doc."
        return 0
    fi

    # BSD mktemp only substitutes X's at the very end of the template, so a trailing ".json" made this fail on macOS every time. Both files are handed to curl with an explicit content type, so the extension was never doing any work.
    metadata_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-import-meta.XXXXXX")" || return 1
    result_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-import-result.XXXXXX")" || return 1
    if [ -n "$folder" ]; then
        jq -n --arg name "$title" --arg parent "$folder" \
            '{name: $name, mimeType: "application/vnd.google-apps.document", parents: [$parent]}' > "$metadata_file" || return 1
    else
        jq -n --arg name "$title" \
            '{name: $name, mimeType: "application/vnd.google-apps.document"}' > "$metadata_file" || return 1
    fi

    token="$(_google_access_token "$alias")" || return 1
    curl -fsS -X POST "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,mimeType,webViewLink,parents,driveId" \
        -H "Authorization: Bearer ${token}" \
        -F "metadata=@${metadata_file};type=application/json;charset=UTF-8" \
        -F "file=@${source_file};type=${mime}" > "$result_file" || return 1

    jq -r '
      "Created Google Doc: " + (.webViewLink // "") + "\n" +
      "Name: " + (.name // "") + "\n" +
      "ID: " + (.id // "") + "\n" +
      "Parents: " + (((.parents // []) | join(", "))) + "\n" +
      "Drive ID: " + (.driveId // "")
    ' "$result_file"
}

_calendar_ids() {
    if _var_is_set GOOGLE_CALENDAR_IDS; then
        printf '%s' "$GOOGLE_CALENDAR_IDS"
    else
        printf 'primary'
    fi
}

_calendar_writable_ids() {
    if _var_is_set LIFEOS_CALENDAR_WRITABLE_IDS; then
        printf '%s' "$LIFEOS_CALENDAR_WRITABLE_IDS"
    else
        printf 'primary'
    fi
}

_calendar_is_writable() {
    local target="$1" id
    for id in $(printf '%s' "$(_calendar_writable_ids)" | tr ',' ' '); do
        id="$(_trim "$id")"
        [ -n "$id" ] || continue
        [ "$id" = "$target" ] && return 0
    done
    return 1
}

_people_aliases_path() {
    if _var_is_set LIFEOS_PEOPLE_ALIASES_PATH; then
        _path_value LIFEOS_PEOPLE_ALIASES_PATH
    else
        printf '%s/people-aliases.json\n' "$SECRETS_DIR"
    fi
}

# Look up a short name in the local alias map (case-insensitive). Prints the
# mapped email on a hit; non-zero with no output on a miss or missing file.
_people_alias_lookup() {
    local raw="$1" path lower email
    path="$(_people_aliases_path)"
    [ -f "$path" ] || return 1
    lower="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    email="$(jq -r --arg k "$lower" '
        (.aliases // {}) | to_entries[]
        | select((.key | ascii_downcase) == $k) | .value
    ' "$path" 2>/dev/null | head -n 1)"
    [ -n "$email" ] || return 1
    printf '%s' "$email"
}

# Resolve an attendee token to an email. Resolution order:
#   1. A value containing "@" is treated as a literal email.
#   2. The local alias map (people-aliases.json) is checked next, so frequent
#      invitees resolve deterministically regardless of Google Contacts.
#   3. Otherwise it is looked up in Google contacts via the People API: 0 or >1
#      matches is an error (caller must disambiguate), exactly 1 prints the email.
_people_resolve_attendee() {
    local raw="$1" token results count alias_email
    case "$raw" in
        *@*) printf '%s' "$raw"; return 0 ;;
    esac
    if alias_email="$(_people_alias_lookup "$raw")"; then
        printf '%s' "$alias_email"
        return 0
    fi
    token="$(_calendar_access_token)" || return 1
    results="$(_people_helper resolve "$token" "$raw")" || return 1
    count="$(printf '%s' "$results" | jq 'length')" || return 1
    if [ "$count" -eq 0 ]; then
        _err "No contact matched '$raw'. Pass a full email address instead."
        return 1
    fi
    if [ "$count" -gt 1 ]; then
        _err "Ambiguous contact '$raw'. Candidates:"
        printf '%s' "$results" | jq -r '.[] | "  - " + .name + " <" + .email + ">"' >&2
        _err "Re-run --attendee with the chosen email, or 'lifeos people add-alias $raw EMAIL' to remember it."
        return 1
    fi
    printf '%s' "$results" | jq -r '.[0].email'
}

_people_aliases_ready() {
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    return 0
}

# Preview how a name resolves, for interactive disambiguation. Prints the alias
# or literal email when one applies, otherwise the People API candidate list.
# With --json, always emits a JSON array so an agent can parse and choose.
_people_resolve() {
    local name="" json=0 token results count alias_email
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            -*) _err "Unknown people resolve option: $1"; return 1 ;;
            *) if [ -z "$name" ]; then name="$1"; shift; else _err "Unexpected argument: $1"; return 1; fi ;;
        esac
    done
    [ -n "$name" ] || { _err "people resolve requires NAME"; return 1; }
    _people_aliases_ready || return 1

    case "$name" in
        *@*)
            if [ "$json" -eq 1 ]; then
                jq -cn --arg e "$name" '[{name:"(literal)",email:$e,source:"literal"}]'
            else
                _say "$name (literal email)"
            fi
            return 0
            ;;
    esac

    if alias_email="$(_people_alias_lookup "$name")"; then
        if [ "$json" -eq 1 ]; then
            jq -cn --arg n "$name" --arg e "$alias_email" '[{name:$n,email:$e,source:"alias"}]'
        else
            _say "$name -> $alias_email (alias)"
        fi
        return 0
    fi

    _calendar_token_ready || return 1
    token="$(_calendar_access_token)" || return 1
    results="$(_people_helper resolve "$token" "$name")" || return 1
    if [ "$json" -eq 1 ]; then
        printf '%s\n' "$results"
        return 0
    fi
    count="$(printf '%s' "$results" | jq 'length')" || return 1
    if [ "$count" -eq 0 ]; then
        _say "No contact matched '$name'."
        return 0
    fi
    printf '%s' "$results" | jq -r '.[] | "  - " + .name + " <" + .email + ">"'
}

_people_list_aliases() {
    local path
    _people_aliases_ready || return 1
    path="$(_people_aliases_path)"
    if [ ! -f "$path" ]; then
        _say "No alias file yet: $path"
        _say "NEXT: cp ${SECRETS_DIR}/people-aliases.example.json $path"
        return 0
    fi
    jq -r '(.aliases // {}) | to_entries[] | "  " + .key + " -> " + .value' "$path"
}

_people_add_alias() {
    local name="${1:-}" email="${2:-}" path tmp
    [ -n "$name" ] || { _err "add-alias requires NAME"; return 1; }
    [ -n "$email" ] || { _err "add-alias requires EMAIL"; return 1; }
    case "$email" in *@*) ;; *) _err "EMAIL must look like an address: $email"; return 1 ;; esac
    _people_aliases_ready || return 1
    path="$(_people_aliases_path)"
    if [ ! -f "$path" ]; then
        printf '{\n  "aliases": {}\n}\n' > "$path" || { _err "Could not create alias file: $path"; return 1; }
        chmod 600 "$path" 2>/dev/null || true
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/lifeos-aliases.XXXXXX")" || return 1
    if jq --arg k "$name" --arg v "$email" '.aliases = ((.aliases // {}) + {($k): $v})' "$path" > "$tmp"; then
        mv "$tmp" "$path"
        _say "Saved alias: $name -> $email ($path)"
    else
        rm -f "$tmp"
        _err "Failed to update alias file: $path"
        return 1
    fi
}

# The machine's IANA zone, portably. /etc/timezone is Linux-only; macOS only has the
# /etc/localtime symlink. Never use `date +%Z` — that yields an abbreviation like CDT,
# which is not a valid IANA identifier and Google will reject it.
# This is only ever a *hint* for the error message, never a silent substitute for the
# calendar's real zone. See _calendar_default_tz.
_system_tz() {
    local target
    if [ -f /etc/timezone ]; then
        _trim "$(cat /etc/timezone)"
        return 0
    fi
    if [ -L /etc/localtime ]; then
        target="$(readlink /etc/localtime)"
        # Strip everything up to and including the zoneinfo dir, leaving e.g. America/Chicago.
        case "$target" in
            */zoneinfo/*) printf '%s' "${target##*/zoneinfo/}"; return 0 ;;
        esac
    fi
    if [ -n "${TZ:-}" ]; then
        printf '%s' "$TZ"
        return 0
    fi
    return 1
}

# Default time zone for timed events: an explicit --tz wins, else the target calendar's
# own zone. There is no third rung — if the zone cannot be read, this FAILS.
#
# Guessing is not safe here. A wrong zone still writes a real event, just at the wrong
# hour, and nothing downstream can detect it; the event looks entirely normal. That is
# silent data corruption, so the only honest options are the calendar's actual zone or a
# stop. Writing is not blocked by the stop: the error names the exact --tz value to pass,
# so the operator is one flag away from proceeding deliberately.
#
# Reads from /users/me/calendarList/{id} rather than /calendars/{id}: the latter 403s
# under the scope this token holds, and because _calendar_get is `curl -fsS` that failure
# is silent. Do not "simplify" this back to /calendars/{id} without re-verifying scope.
_calendar_default_tz() {
    local calendar_id="$1" encoded tz hint
    encoded="$(_urlencode "$calendar_id")" || return 1
    tz="$(_calendar_get "/users/me/calendarList/${encoded}" --data-urlencode "fields=timeZone" 2>/dev/null | jq -r '.timeZone // empty')"
    if [ -n "$tz" ]; then
        printf '%s' "$tz"
        return 0
    fi
    hint="$(_system_tz 2>/dev/null)" || hint=""
    _err "could not read the time zone for calendar '${calendar_id}'."
    _err "Refusing to guess: a wrong zone writes the event at the wrong hour and looks normal afterward."
    if [ -n "$hint" ]; then
        _err "Re-run with an explicit zone, e.g. --tz ${hint} (this machine's zone), or whichever zone the event belongs in."
    else
        _err "Re-run with an explicit zone, e.g. --tz America/Chicago (an IANA name, never an abbreviation like CDT)."
    fi
    _err "If this keeps happening, the calendar metadata read may be failing: check 'lifeos calendar list-calendars' and the token scope."
    return 1
}

_calendar_list_calendars() {
    _calendar_token_ready || return 1
    _calendar_get "/users/me/calendarList" \
        --data-urlencode "fields=items(id,summary,primary,selected,hidden,accessRole)" |
        jq -r '
          (.items // [])[] |
          "- " + (.summary // "Untitled calendar") +
          " | id: " + (.id // "") +
          " | primary: " + ((.primary // false) | tostring) +
          " | selected: " + ((.selected // false) | tostring) +
          " | access: " + (.accessRole // "unknown")
        '
}

_calendar_find_human() {
    jq -r '
      (.items // [])[] |
      [
        ("- " + (.summary // "Untitled event")),
        ("calendar: " + (._calendar_summary // ._calendar_id // "")),
        ("calendar_id: " + (._calendar_id // "")),
        ("event_id: " + (.id // "")),
        (if .recurringEventId then "series_id: " + .recurringEventId else empty end),
        ("start: " + (.start.dateTime // .start.date // "")),
        ("end: " + (.end.dateTime // .end.date // "")),
        (if (.location // "") != "" then "location: " + .location else empty end),
        (if (.htmlLink // "") != "" then .htmlLink else empty end)
      ] | join(" | ")
    '
}

_calendar_find() {
    local query="" calendar_ids="" calendar_id encoded_id calendar_file calendar_list_file events_file combined_file
    local window time_min time_max from="" to="" json=0 calendar_name

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --calendar)
                [ -n "${2:-}" ] || { _err "--calendar requires CALENDAR_ID"; return 1; }
                calendar_ids="$2"
                shift 2
                ;;
            --from)
                [ -n "${2:-}" ] || { _err "--from requires YYYY-MM-DD"; return 1; }
                from="$2"
                shift 2
                ;;
            --to)
                [ -n "${2:-}" ] || { _err "--to requires YYYY-MM-DD"; return 1; }
                to="$2"
                shift 2
                ;;
            --json)
                json=1
                shift
                ;;
            -*)
                _err "Unknown calendar find option: $1"
                return 1
                ;;
            *)
                if [ -z "$query" ]; then
                    query="$1"
                    shift
                else
                    _err "Unexpected calendar find argument: $1"
                    return 1
                fi
                ;;
        esac
    done

    [ -n "$query" ] || { _err "calendar find requires QUERY"; return 1; }
    _calendar_token_ready || return 1

    if [ -n "$from" ]; then
        time_min="${from}T00:00:00Z"
    else
        window="$(_calendar_window)" || return 1
        time_min="$(printf '%s\n' "$window" | sed -n '1p')"
    fi
    if [ -n "$to" ]; then
        time_max="${to}T23:59:59Z"
    else
        if [ -z "${window:-}" ]; then
            window="$(_calendar_window)" || return 1
        fi
        time_max="$(printf '%s\n' "$window" | sed -n '2p')"
    fi
    if [ -z "$calendar_ids" ]; then
        calendar_ids="$(printf '%s' "$(_calendar_ids)" | tr ',' ' ')"
    fi

    calendar_list_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-find-list.XXXXXX")" || return 1
    combined_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-find.XXXXXX")" || return 1
    jq -n '{items: []}' > "$combined_file"

    _calendar_get "/users/me/calendarList" \
        --data-urlencode "fields=items(id,summary,primary,selected,hidden,accessRole,timeZone)" > "$calendar_list_file" || return 1

    for calendar_id in $calendar_ids; do
        calendar_id="$(_trim "$calendar_id")"
        [ -n "$calendar_id" ] || continue
        encoded_id="$(_urlencode "$calendar_id")" || return 1
        calendar_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-find-meta.XXXXXX")" || return 1
        events_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-find-events.XXXXXX")" || return 1
        _calendar_write_metadata "$calendar_list_file" "$calendar_id" "$calendar_file"
        calendar_name="$(jq -r '.summary // .id // "Calendar"' "$calendar_file")"
        _say "Finding events in calendar: ${calendar_name}" >&2

        _calendar_get "/calendars/${encoded_id}/events" \
            --data-urlencode "singleEvents=true" \
            --data-urlencode "orderBy=startTime" \
            --data-urlencode "showDeleted=false" \
            --data-urlencode "timeMin=${time_min}" \
            --data-urlencode "timeMax=${time_max}" \
            --data-urlencode "q=${query}" \
            --data-urlencode "maxResults=50" \
            --data-urlencode "fields=items(id,recurringEventId,status,summary,description,location,htmlLink,start,end)" > "$events_file" || return 1

        jq -s --slurpfile meta "$calendar_file" '
          .[0] as $existing |
          .[1] as $incoming |
          $existing + {
            items: (
              ($existing.items // []) +
              (($incoming.items // []) | map(. + {
                _calendar_id: ($meta[0].id // ""),
                _calendar_summary: ($meta[0].summary // "")
              }))
            )
          }
        ' "$combined_file" "$events_file" > "${combined_file}.next" || return 1
        mv "${combined_file}.next" "$combined_file"
    done

    if [ "$json" -eq 1 ]; then
        cat "$combined_file"
    else
        if [ "$(jq '(.items // []) | length' "$combined_file")" -eq 0 ]; then
            _say "No matching events found."
            return 0
        fi
        _calendar_find_human < "$combined_file"
    fi
}

_calendar_window() {
    _calendar_helper date-window "$LIFEOS_DAYS_BACK" "$LIFEOS_DAYS_AHEAD"
}

# _calendar_add_m365 ALIAS TIME_MIN TIME_MAX TARGET_TZ
# Fetches the alias's enabled Microsoft 365 calendars in UTC, normalizes them into the Google event shape, and appends the file pairs to the caller's render_args. Prints one status line either way; returns non-zero on failure.
_calendar_add_m365() {
    local alias="$1" from="$2" to="$3" target_tz="$4" ids json outdir pairs path count=0
    if [ -z "$target_tz" ]; then
        printf -- '- %s: MISSING — the Google primary calendar time zone could not be read, so Microsoft 365 times could not be converted. This agenda does not include %s. Check `lifeos calendar list-calendars`.' "$alias" "$alias"
        return 1
    fi
    ids="$(printf '%s\n' "$(_m365_calendar_ids "$alias")" | tr '\n' ' ')"
    json="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-unified.XXXXXX")" || return 1
    outdir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-unified-out.XXXXXX")" || return 1
    if ! _m365_calendar_fetch "$alias" "$from" "$to" "$ids" "$json" "UTC" >/dev/null 2>&1; then
        printf -- '- %s: MISSING — the Microsoft 365 fetch failed, so this agenda does not include %s. Try `lifeos m365 calendar sync %s` to see the error (often an expired sign-in: `lifeos m365 auth %s`).' "$alias" "$alias" "$alias" "$alias"
        return 1
    fi
    if ! pairs="$(_m365_calendar_normalize_helper --input "$json" --timezone "$target_tz" --alias "$alias" --outdir "$outdir")"; then
        printf -- '- %s: MISSING — Microsoft 365 events could not be normalized, so this agenda does not include %s.' "$alias" "$alias"
        return 1
    fi
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        render_args+=( "$path" )
        count=$((count + 1))
    done <<EOF_PAIRS
$pairs
EOF_PAIRS
    printf -- '- %s: included (%s calendar(s), converted to %s).' "$alias" "$((count / 2))" "$target_tz"
}

_calendar_render_events() {
    _calendar_render_helper "$@"
}

_calendar_write_metadata() {
    local calendar_list_file="$1"
    local requested_id="$2"
    local out="$3"

    if ! jq -e --arg id "$requested_id" '
      if $id == "primary" then
        ((.items // []) | map(select(.primary == true)) | .[0])
      else
        ((.items // []) | map(select(.id == $id)) | .[0])
      end |
      select(. != null) |
      {
        id: (if $id == "primary" then "primary" else .id end),
        actualId: (.id // ""),
        summary: (.summary // $id),
        timeZone: (.timeZone // ""),
        primary: (.primary // false),
        selected: (.selected // false),
        accessRole: (.accessRole // "")
      }
    ' "$calendar_list_file" > "$out"; then
        jq -n --arg id "$requested_id" '{id: $id, actualId: $id, summary: $id}' > "$out"
    fi
}

_calendar_sync() {
    local out tmp_out calendar_ids calendar_id encoded_id calendar_file events_file calendar_list_file
    local refreshed window time_min time_max today calendar_name custom_out=""
    local m365_status m365_aliases m365_alias m365_line_file target_tz
    local render_args=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${QA_DIR}/calendar-qa.md"
                shift
                ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown calendar sync option: $1"; return 1 ;;
        esac
    done

    _calendar_token_ready || return 1

    if [ -n "$custom_out" ]; then
        out="$custom_out"
        _ensure_parent_dir "$out" || return 1
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/calendar.md"
    fi

    tmp_out="$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")" || return 1
    _register_temp_file "$tmp_out"
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    window="$(_calendar_window)" || return 1
    time_min="$(printf '%s\n' "$window" | sed -n '1p')"
    time_max="$(printf '%s\n' "$window" | sed -n '2p')"
    today="$(printf '%s\n' "$window" | sed -n '3p')"

    {
        printf '# Google Calendar\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf 'Today: %s\n\n' "$today"
        printf 'Window: %s to %s\n\n' "$time_min" "$time_max"
        printf 'Calendar IDs: `%s`\n\n' "$(_calendar_ids)"
    } > "$tmp_out"

    calendar_list_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-list.XXXXXX")" || return 1
    _calendar_get "/users/me/calendarList" \
        --data-urlencode "fields=items(id,summary,primary,selected,hidden,accessRole,timeZone)" > "$calendar_list_file" || return 1

    calendar_ids="$(printf '%s' "$(_calendar_ids)" | tr ',' ' ')"
    for calendar_id in $calendar_ids; do
        calendar_id="$(_trim "$calendar_id")"
        [ -n "$calendar_id" ] || continue
        encoded_id="$(_urlencode "$calendar_id")" || return 1
        calendar_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar.XXXXXX")" || return 1
        events_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-events.XXXXXX")" || return 1

        _calendar_write_metadata "$calendar_list_file" "$calendar_id" "$calendar_file"

        calendar_name="$(jq -r '.summary // .id // "Calendar"' "$calendar_file")"
        _say "Syncing calendar: ${calendar_name}" >&2

        _calendar_fetch_events "$encoded_id" "$time_min" "$time_max" "$events_file" \
            "items(id,iCalUID,status,summary,description,location,htmlLink,hangoutLink,conferenceData(entryPoints(entryPointType,label,uri)),start,end),nextPageToken" || return 1

        render_args+=( "$calendar_file" "$events_file" )
    done

    # Microsoft 365 calendars join the same agenda. A failure is stated in the file, never silently dropped.
    m365_status=""
    if [ "${LIFEOS_CALENDAR_GOOGLE_ONLY:-0}" != "1" ]; then
        m365_aliases="$(_m365_calendar_enabled_aliases 2>/dev/null || true)"
        if [ -n "$m365_aliases" ]; then
            m365_line_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-status.XXXXXX")" || return 1
            target_tz="$(jq -r '(.items // [])[] | select(.primary == true) | .timeZone // empty' "$calendar_list_file" | head -n 1)"
            while IFS= read -r m365_alias; do
                [ -n "$m365_alias" ] || continue
                # Called without command substitution so its additions to render_args stay in this shell.
                _calendar_add_m365 "$m365_alias" "$time_min" "$time_max" "$target_tz" > "$m365_line_file" || true
                m365_status="${m365_status}$(cat "$m365_line_file")"$'\n'
            done <<EOF_M365
$m365_aliases
EOF_M365
        fi
    fi
    if [ -n "$m365_status" ]; then
        { printf 'Microsoft 365 calendars:\n\n'; printf '%s\n' "$m365_status"; } >> "$tmp_out"
    fi

    if [ "${#render_args[@]}" -eq 0 ]; then
        _warn "No Google Calendar IDs were configured."
    else
        _calendar_render_events "${render_args[@]}" >> "$tmp_out" || return 1
    fi

    mv "$tmp_out" "$out"
    _say "Updated $out"

    _calendar_sync_long_horizon "$out" "$time_max" "$calendar_list_file" "$calendar_ids" || return 1
}

# _calendar_fetch_events ENCODED_CALENDAR_ID TIME_MIN TIME_MAX OUT FIELDS
# Fetches every page of expanded events into one {"items": [...]} file. A cap on pages turns a runaway window into a loud error rather than a silently truncated agenda.
_calendar_fetch_events() {
    local encoded_id="$1" from="$2" to="$3" out="$4" fields="$5" page_token="" page=0 dir page_file
    local max_pages="${LIFEOS_CALENDAR_MAX_PAGES:-40}"
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-events-pages.XXXXXX")" || return 1
    while :; do
        page=$((page + 1))
        if [ "$page" -gt "$max_pages" ]; then
            _err "Calendar fetch exceeded ${max_pages} pages for one calendar; refusing to write a truncated agenda. Narrow the window or raise LIFEOS_CALENDAR_MAX_PAGES."
            return 1
        fi
        page_file="${dir}/page-${page}.json"
        if [ -n "$page_token" ]; then
            _calendar_get "/calendars/${encoded_id}/events" \
                --data-urlencode "singleEvents=true" --data-urlencode "orderBy=startTime" --data-urlencode "showDeleted=false" \
                --data-urlencode "timeMin=${from}" --data-urlencode "timeMax=${to}" --data-urlencode "maxResults=2500" \
                --data-urlencode "fields=${fields}" --data-urlencode "pageToken=${page_token}" > "$page_file" || return 1
        else
            _calendar_get "/calendars/${encoded_id}/events" \
                --data-urlencode "singleEvents=true" --data-urlencode "orderBy=startTime" --data-urlencode "showDeleted=false" \
                --data-urlencode "timeMin=${from}" --data-urlencode "timeMax=${to}" --data-urlencode "maxResults=2500" \
                --data-urlencode "fields=${fields}" > "$page_file" || return 1
        fi
        page_token="$(jq -r '.nextPageToken // empty' "$page_file")"
        [ -n "$page_token" ] || break
    done
    jq -s '{items: (map(.items // []) | add)}' "$dir"/page-*.json > "$out"
}

# _calendar_long_horizon_path NEAR_OUT
_calendar_long_horizon_path() {
    local near="$1"
    case "$near" in
        */calendar.md) printf '%s/calendar-long-horizon.md\n' "$(dirname "$near")" ;;
        *.md) printf '%s-long-horizon.md\n' "${near%.md}" ;;
        *) printf '%s-long-horizon.md\n' "$near" ;;
    esac
}

# _calendar_sync_long_horizon NEAR_OUT BOUNDARY CALENDAR_LIST_FILE CALENDAR_IDS
# Writes a compact one-line-per-event agenda starting where the near-term window ends (BOUNDARY) and running LIFEOS_LONG_HORIZON_DAYS from today. Same calendars as the near-term file, no overlap with it.
_calendar_sync_long_horizon() {
    local near="$1" boundary="$2" calendar_list_file="$3" calendar_ids="$4"
    local out tmp_out window far refreshed target_tz calendar_id encoded_id calendar_file events_file m365_aliases m365_alias m365_line_file m365_status=""
    local render_args=()
    out="$(_calendar_long_horizon_path "$near")"
    tmp_out="$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")" || return 1
    _register_temp_file "$tmp_out"
    window="$(_calendar_helper date-window 0 "$LIFEOS_LONG_HORIZON_DAYS")" || return 1
    far="$(printf '%s\n' "$window" | sed -n '2p')"
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    target_tz="$(jq -r '(.items // [])[] | select(.primary == true) | .timeZone // empty' "$calendar_list_file" | head -n 1)"
    {
        printf '# Google Calendar — Long Horizon\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf 'Window: %s to %s\n\n' "$boundary" "$far"
        printf 'One line per event, no descriptions. Events before %s are in [%s](%s), which has full detail; nothing appears in both files.\n\n' "$boundary" "$(basename "$near")" "$(basename "$near")"
    } > "$tmp_out"
    if [ -z "$target_tz" ]; then
        printf 'MISSING: the Google primary calendar time zone could not be read, so this file was not built. Check `lifeos calendar list-calendars`.\n' >> "$tmp_out"
        mv "$tmp_out" "$out"
        _warn "Long-horizon agenda not built: primary calendar time zone unknown."
        return 1
    fi
    for calendar_id in $calendar_ids; do
        calendar_id="$(_trim "$calendar_id")"
        [ -n "$calendar_id" ] || continue
        encoded_id="$(_urlencode "$calendar_id")" || return 1
        calendar_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-lh.XXXXXX")" || return 1
        events_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-events-lh.XXXXXX")" || return 1
        _calendar_write_metadata "$calendar_list_file" "$calendar_id" "$calendar_file"
        _calendar_fetch_events "$encoded_id" "$boundary" "$far" "$events_file" "items(id,iCalUID,recurringEventId,status,summary,start,end),nextPageToken" || return 1
        render_args+=( "$calendar_file" "$events_file" )
    done
    if [ "${LIFEOS_CALENDAR_GOOGLE_ONLY:-0}" != "1" ]; then
        m365_aliases="$(_m365_calendar_enabled_aliases 2>/dev/null || true)"
        if [ -n "$m365_aliases" ]; then
            m365_line_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-status.XXXXXX")" || return 1
            while IFS= read -r m365_alias; do
                [ -n "$m365_alias" ] || continue
                _calendar_add_m365 "$m365_alias" "$boundary" "$far" "$target_tz" > "$m365_line_file" || true
                m365_status="${m365_status}$(cat "$m365_line_file")"$'\n'
            done <<EOF_M365_LH
$m365_aliases
EOF_M365_LH
        fi
    fi
    if [ -n "$m365_status" ]; then
        { printf 'Microsoft 365 calendars:\n\n'; printf '%s\n' "$m365_status"; } >> "$tmp_out"
    fi
    if [ "${#render_args[@]}" -gt 0 ]; then
        _calendar_render_events --compact --start-at "$boundary" --tz "$target_tz" "${render_args[@]}" >> "$tmp_out" || return 1
    fi
    mv "$tmp_out" "$out"
    _say "Updated $out"
}

# Shared attendee resolution: turns the raw --attendee tokens (names or emails)
# into resolved emails, populating two parallel arrays by name convention:
#   _RESOLVED_EMAILS  – emails to send to the API
#   _RESOLVED_DISPLAY – "raw -> email" lines for the dry-run plan
_calendar_resolve_attendees() {
    local raw email
    _RESOLVED_EMAILS=()
    _RESOLVED_DISPLAY=()
    for raw in "$@"; do
        email="$(_people_resolve_attendee "$raw")" || return 1
        _RESOLVED_EMAILS+=("$email")
        if [ "$raw" = "$email" ]; then
            _RESOLVED_DISPLAY+=("$email")
        else
            _RESOLVED_DISPLAY+=("$raw -> $email")
        fi
    done
    return 0
}

_calendar_create_event() {
    local calendar_id="primary" title="" start="" end="" tz="" location="" desc="" desc_file=""
    local notify=0 execute=0 encoded body send_updates created
    local attendees_raw=() build_args=() recurrence_rules=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; shift 2 ;;
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires CALENDAR_ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --start) [ -n "${2:-}" ] || { _err "--start requires DATE or DATETIME"; return 1; }; start="$2"; shift 2 ;;
            --end) [ -n "${2:-}" ] || { _err "--end requires DATE or DATETIME"; return 1; }; end="$2"; shift 2 ;;
            --tz) [ -n "${2:-}" ] || { _err "--tz requires ZONE"; return 1; }; tz="$2"; shift 2 ;;
            --location) [ -n "${2+x}" ] || { _err "--location requires TEXT"; return 1; }; location="$2"; shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; shift 2 ;;
            --attendee) [ -n "${2:-}" ] || { _err "--attendee requires NAME or EMAIL"; return 1; }; attendees_raw+=("$2"); shift 2 ;;
            --recurrence) [ -n "${2:-}" ] || { _err "--recurrence requires an RRULE line"; return 1; }; recurrence_rules+=("$2"); shift 2 ;;
            --notify) notify=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown calendar create-event option: $1"; return 1 ;;
        esac
    done

    _calendar_token_ready || return 1
    [ -n "$title" ] || { _err "create-event requires --title"; return 1; }
    [ -n "$start" ] || { _err "create-event requires --start"; return 1; }
    if ! _calendar_is_writable "$calendar_id"; then
        _err "Calendar '$calendar_id' is not writable. Allowed: $(_calendar_writable_ids)"
        _say "NEXT: add it to LIFEOS_CALENDAR_WRITABLE_IDS in .env if you intend to write there."
        return 1
    fi
    if [ -n "$desc_file" ]; then
        [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }
        desc="$(cat "$desc_file")"
    fi

    # Timed events (start contains a time component) need a time zone.
    case "$start" in
        *T*) [ -n "$tz" ] || tz="$(_calendar_default_tz "$calendar_id")" || return 1 ;;
    esac

    if [ "${#attendees_raw[@]}" -gt 0 ]; then
        _calendar_resolve_attendees "${attendees_raw[@]}" || return 1
    else
        _RESOLVED_EMAILS=()
        _RESOLVED_DISPLAY=()
    fi

    build_args=(build-event --title "$title" --start "$start")
    [ -n "$end" ] && build_args+=(--end "$end")
    [ -n "$tz" ] && build_args+=(--tz "$tz")
    [ -n "$location" ] && build_args+=(--location "$location")
    [ -n "$desc" ] && build_args+=(--description "$desc")
    local email rule
    for email in "${_RESOLVED_EMAILS[@]}"; do
        build_args+=(--attendee "$email")
    done
    for rule in "${recurrence_rules[@]}"; do
        build_args+=(--recurrence "$rule")
    done

    body="$(_calendar_write_helper "${build_args[@]}")" || return 1

    if [ "$notify" -eq 1 ]; then send_updates="all"; else send_updates="none"; fi

    _say "Calendar event create plan:"
    _say "Calendar: $calendar_id"
    _say "Title: $title"
    _say "Start: $start"
    _say "End: ${end:-<default>}"
    [ -n "$tz" ] && _say "Time zone: $tz"
    _say "Location: ${location:-<none>}"
    if [ "${#recurrence_rules[@]}" -gt 0 ]; then
        _say "Recurrence: ${recurrence_rules[*]}"
    fi
    if [ "${#_RESOLVED_DISPLAY[@]}" -gt 0 ]; then
        _say "Attendees: ${_RESOLVED_DISPLAY[*]}"
    else
        _say "Attendees: <none>"
    fi
    _say "Notify attendees: $([ "$notify" -eq 1 ] && echo "YES (email invites)" || echo "no")"

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no event was created. Re-run with --execute to create it."
        return 0
    fi

    encoded="$(_urlencode "$calendar_id")" || return 1
    created="$(_calendar_write POST "/calendars/${encoded}/events?sendUpdates=${send_updates}" "$body")" || return 1
    _say "Created event: $(printf '%s' "$created" | jq -r '.htmlLink // .id // "(unknown)"')"
}

_calendar_update_event() {
    local calendar_id="primary" event_id="" title="" start="" end="" tz="" location="" desc="" desc_file=""
    local notify=0 execute=0 replace_attendees=0 set_title=0 set_location=0 set_desc=0 scope_series=0
    local encoded event_encoded target_id target_encoded body send_updates current scope_label updated
    local attendees_raw=() build_args=() final_emails=() recurrence_rules=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --event) [ -n "${2:-}" ] || { _err "--event requires EVENT_ID"; return 1; }; event_id="$2"; shift 2 ;;
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires CALENDAR_ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; set_title=1; shift 2 ;;
            --start) [ -n "${2:-}" ] || { _err "--start requires DATE or DATETIME"; return 1; }; start="$2"; shift 2 ;;
            --end) [ -n "${2:-}" ] || { _err "--end requires DATE or DATETIME"; return 1; }; end="$2"; shift 2 ;;
            --tz) [ -n "${2:-}" ] || { _err "--tz requires ZONE"; return 1; }; tz="$2"; shift 2 ;;
            --location) [ -n "${2+x}" ] || { _err "--location requires TEXT"; return 1; }; location="$2"; set_location=1; shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; set_desc=1; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; set_desc=1; shift 2 ;;
            --attendee) [ -n "${2:-}" ] || { _err "--attendee requires NAME or EMAIL"; return 1; }; attendees_raw+=("$2"); shift 2 ;;
            --recurrence) [ -n "${2:-}" ] || { _err "--recurrence requires an RRULE line"; return 1; }; recurrence_rules+=("$2"); shift 2 ;;
            --replace-attendees) replace_attendees=1; shift ;;
            --series) scope_series=1; shift ;;
            --instance) scope_series=0; shift ;;
            --notify) notify=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown calendar update-event option: $1"; return 1 ;;
        esac
    done

    _calendar_token_ready || return 1
    [ -n "$event_id" ] || { _err "update-event requires --event"; return 1; }
    if ! _calendar_is_writable "$calendar_id"; then
        _err "Calendar '$calendar_id' is not writable. Allowed: $(_calendar_writable_ids)"
        return 1
    fi
    if [ "${#recurrence_rules[@]}" -gt 0 ] && [ "$scope_series" -ne 1 ]; then
        _err "--recurrence changes the recurrence rule, which only applies to the series. Re-run with --series."
        return 1
    fi
    if [ -n "$desc_file" ]; then
        [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }
        desc="$(cat "$desc_file")"
    fi

    encoded="$(_urlencode "$calendar_id")" || return 1
    event_encoded="$(_urlencode "$event_id")" || return 1
    current="$(_calendar_get "/calendars/${encoded}/events/${event_encoded}")" || {
        _err "Could not fetch event '$event_id' on calendar '$calendar_id'."
        return 1
    }

    # Default target is the event ID as passed (a single instance for recurring
    # events). --series retargets the parent series master so the edit applies to
    # every occurrence; re-fetch it so the plan and attendee merge use its state.
    if [ "$scope_series" -eq 1 ]; then
        target_id="$(printf '%s' "$current" | jq -r '.recurringEventId // .id')"
        target_encoded="$(_urlencode "$target_id")" || return 1
        if [ "$target_id" != "$event_id" ]; then
            current="$(_calendar_get "/calendars/${encoded}/events/${target_encoded}")" || {
                _err "Could not fetch series master '$target_id'."
                return 1
            }
        fi
        scope_label="entire series ($target_id)"
    else
        target_id="$event_id"
        target_encoded="$event_encoded"
        if printf '%s' "$current" | jq -e '.recurringEventId' >/dev/null 2>&1; then
            scope_label="single occurrence (pass --series to edit all)"
        else
            scope_label="single event"
        fi
    fi

    case "$start" in
        *T*) [ -n "$tz" ] || tz="$(_calendar_default_tz "$calendar_id")" || return 1 ;;
    esac

    # Attendee handling: PATCH replaces the whole attendees array, so to ADD we
    # merge the existing list with the new one unless --replace-attendees is set.
    if [ "${#attendees_raw[@]}" -gt 0 ] || [ "$replace_attendees" -eq 1 ]; then
        if [ "${#attendees_raw[@]}" -gt 0 ]; then
            _calendar_resolve_attendees "${attendees_raw[@]}" || return 1
        else
            _RESOLVED_EMAILS=()
            _RESOLVED_DISPLAY=()
        fi
        if [ "$replace_attendees" -eq 1 ]; then
            final_emails=("${_RESOLVED_EMAILS[@]}")
        else
            local existing
            while IFS= read -r existing || [ -n "$existing" ]; do
                [ -n "$existing" ] || continue
                final_emails+=("$existing")
            done <<EOF
$(printf '%s' "$current" | jq -r '(.attendees // [])[] | .email // empty')
EOF
            final_emails+=("${_RESOLVED_EMAILS[@]}")
        fi
    fi

    build_args=(build-event)
    [ "$set_title" -eq 1 ] && build_args+=(--title "$title")
    [ -n "$start" ] && build_args+=(--start "$start")
    [ -n "$end" ] && build_args+=(--end "$end")
    [ -n "$tz" ] && build_args+=(--tz "$tz")
    [ "$set_location" -eq 1 ] && build_args+=(--location "$location")
    [ "$set_desc" -eq 1 ] && build_args+=(--description "$desc")
    local email rule
    for email in "${final_emails[@]}"; do
        build_args+=(--attendee "$email")
    done
    for rule in "${recurrence_rules[@]}"; do
        build_args+=(--recurrence "$rule")
    done

    body="$(_calendar_write_helper "${build_args[@]}")" || return 1

    if [ "$notify" -eq 1 ]; then send_updates="all"; else send_updates="none"; fi

    _say "Calendar event update plan:"
    _say "Calendar: $calendar_id"
    _say "Event: $event_id"
    _say "Scope: $scope_label"
    _say "Current title: $(printf '%s' "$current" | jq -r '.summary // "(none)"')"
    _say "Changes:"
    printf '%s' "$body" | jq .
    if [ "${#final_emails[@]}" -gt 0 ]; then
        _say "Final attendees: ${final_emails[*]}"
    fi
    _say "Notify attendees: $([ "$notify" -eq 1 ] && echo "YES (email invites)" || echo "no")"

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no event was updated. Re-run with --execute to apply."
        return 0
    fi

    updated="$(_calendar_write PATCH "/calendars/${encoded}/events/${target_encoded}?sendUpdates=${send_updates}" "$body")" || return 1
    _say "Updated event: $(printf '%s' "$updated" | jq -r '.htmlLink // .id // "(unknown)"')"
}
