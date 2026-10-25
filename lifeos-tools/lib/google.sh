#!/usr/bin/env bash
##- lifeos Google ecosystem: Calendar, Gmail, Drive, Sheets, and People, plus the shared Google OAuth and account-alias layer they all authenticate through. Includes the Google-local _urlencode helper.
##- Compatibility caller: retains existing credential routing while delegating service operations to Agent Hands.

# Portable mechanics load first; legacy configuration and credential routing override their hooks below.
source "${LIB_DIR}/../../agent-hands/skills/authorize-google/scripts/client.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-google-calendar/scripts/operations.sh"
_calendar_max_pages() { printf '%s' "${LIFEOS_CALENDAR_MAX_PAGES:-40}"; }
_calendar_system_tz() { _system_tz; }

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
    local command="$1" token="$2"
    shift 2
    GOOGLE_ACCESS_TOKEN="$token" "$LIFEOS_PY" "${LIB_DIR}/../../agent-hands/skills/use-google-contacts/scripts/contacts.py" "$command" "$@"
}

_calendar_write_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/google-calendar-write.py" "$@"
}

_urlencode() {
    jq -rn --arg value "$1" '$value | @uri'
}

# The shared provider was loaded above; this caller retains its private configuration locations.
_google_accounts_path() {
    if _var_is_set GOOGLE_ACCOUNTS_PATH; then _path_value GOOGLE_ACCOUNTS_PATH
    else printf '%s/google-accounts.json\n' "$SECRETS_DIR"
    fi
}
_google_python() { shift; "$LIFEOS_PY" "$@"; }
_google_config_path() {
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


_docs_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/../../agent-hands/skills/use-google-docs/scripts/docs.py" "$@"
}

# Legacy Docs route retains the existing arguments and account settings.
_docs_run() {
    local sub="${1:-}" alias="${2:-}" raw="${3:-}" doc_id token
    [ -n "$sub" ] || { _err "docs requires a subcommand (read|replace-once|set-body|comments|comment)"; return 1; }
    [ -n "$alias" ] || { _err "docs $sub requires ALIAS"; return 1; }
    [ -n "$raw" ] || { _err "docs $sub requires DOC_URL_OR_ID"; return 1; }
    shift 3
    doc_id="$(_drive_file_id "$raw")" || return 1
    token="$(_google_access_token "$alias")" || return 1
    GOOGLE_ACCESS_TOKEN="$token" GOOGLE_DOCS_ALIAS="$alias" _docs_helper "$sub" --document-id "$doc_id" "$@"
}

# Portable Gmail mechanics; aggregate snapshots and private defaults remain in this caller.
source "${LIB_DIR}/../../agent-hands/skills/use-gmail/scripts/operations.sh"
_gmail_query() {
    _google_account_value "$1" '.gmail.query // "in:inbox newer_than:30d -label:Newsletters"' 2>/dev/null || printf 'in:inbox newer_than:30d -label:Newsletters'
}
_gmail_retry_cap() { printf '%s' "${LIFEOS_GMAIL_MAX_RETRIES:-5}"; }
_gmail_audit_log_path() { _mail_audit_log_path; }
_gmail_audit_append() { _mail_audit_append; }
_gmail_sync_alias() { GOOGLE_GMAIL_MAX_RETRIES="${LIFEOS_GMAIL_MAX_RETRIES:-5}" _gmail_export_alias "$@"; }

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

# Portable Drive mechanics; legacy callers must declare exclusions rather than inherit a private default.
source "${LIB_DIR}/../../agent-hands/skills/use-google-drive/scripts/operations.sh"
_drive_sync() {
    local alias="" out="" explicit_exclusion=0 exclusion_type arguments=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) out="${QA_DIR}/drive.md"; shift ;;
            --output) [ -n "${2:-}" ] || return 1; out="$2"; shift 2 ;;
            --exclude-folder) [ -n "${2:-}" ] || { _err '--exclude-folder requires NAME'; return 1; }; explicit_exclusion=1; arguments+=( "$1" "$2" ); shift 2 ;;
            --folders|--recent|--recent-days) [ -n "${2:-}" ] || return 1; arguments+=( "$1" "$2" ); shift 2 ;;
            -*) _err "Unknown drive sync option: $1"; return 1 ;;
            *) alias="$1"; shift ;;
        esac
    done
    [ -n "$alias" ] || { _err 'drive sync requires ALIAS'; return 1; }
    if [ "$explicit_exclusion" -eq 0 ]; then
        exclusion_type="$(_google_account_value "$alias" '.drive.index_exclude | type')" || return 1
        [ "$exclusion_type" = array ] || { _err 'Legacy implicit exclusions are retired: supply --exclude-folder NAME or configure drive.index_exclude explicitly (an empty array deliberately permits all child samples).'; return 1; }
    fi
    if [ -z "$out" ]; then _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_sources_dir)/drive.md"; fi
    if [ "${#arguments[@]}" -gt 0 ]; then _drive_export_index "$alias" --output "$out" "${arguments[@]}"
    else _drive_export_index "$alias" --output "$out"
    fi
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


# Compatibility credential routing for explicit provider exports; composition belongs to the caller.
_calendar_export_data() (
    GOOGLE_CALENDAR_ALIAS="${1:-}"
    [ -n "$GOOGLE_CALENDAR_ALIAS" ] || { _err "export-data requires SOURCE_LABEL"; return 1; }
    shift
    _calendar_export --data "$@"
)

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

# Verify only explicitly requested availability/reminder fields after a successful write. A failed check must not invite an automatic repeat of an accepted write.
