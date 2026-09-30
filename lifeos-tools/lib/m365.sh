#!/usr/bin/env bash
##- LifeOS Microsoft 365: delegated auth plus bounded mail, calendar, and Outlook contact reads and gated writes, including opt-in mail moves between folders (never delete).
##- Sourced by lifeos.sh after common.sh and google.sh; uses the shared people alias map for deterministic attendee resolution.

_m365_accounts_path() {
    if _var_is_set M365_ACCOUNTS_PATH; then
        _path_value M365_ACCOUNTS_PATH
    else
        printf '%s/m365-accounts.json\n' "$SECRETS_DIR"
    fi
}

_m365_path() {
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

_m365_accounts_ready() {
    local config
    config="$(_m365_accounts_path)"
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    if [ ! -f "$config" ]; then
        _err "Microsoft 365 account config does not exist: $config"
        _say "NEXT: cp ${SECRETS_DIR}/m365-accounts.example.json $config"
        return 1
    fi
    return 0
}

_m365_account_exists() {
    local alias="$1"
    _m365_accounts_ready || return 1
    jq -e --arg alias "$alias" 'any(.accounts[]?; .alias == $alias)' "$(_m365_accounts_path)" >/dev/null
}

_m365_account_value() {
    local alias="$1" filter="$2"
    jq -er --arg alias "$alias" "(.accounts[]? | select(.alias == \$alias) | ${filter}) // empty" "$(_m365_accounts_path)"
}

_m365_auth_provider() {
    _m365_account_value "$1" '.auth_provider // "msal"'
}

_m365_account_path() {
    local alias="$1" filter="$2" value
    value="$(_m365_account_value "$alias" "$filter")" || return 1
    _m365_path "$value"
}

_m365_require_enabled() {
    local alias="$1" service="$2"
    _m365_account_exists "$alias" || { _err "Unknown Microsoft 365 account alias: $alias"; return 1; }
    if ! _m365_account_value "$alias" "(.${service}.enabled // false) == true" 2>/dev/null | grep -qx true; then
        _err "Microsoft 365 ${service} is not enabled for alias '$alias'"
        return 1
    fi
}

_m365_accounts_list() {
    _m365_accounts_ready || return 1
    jq -r '
      (.accounts // [])[] |
      "- " + (.alias // "missing-alias") +
      " | auth: " + (.auth_provider // "msal") +
      " | tenant: " + (.tenant // "organizations") +
      " | mail: " + (((.mail.enabled // false) == true) | tostring) +
      " | mail moves: " + (((.mail.write_enabled // false) == true) | tostring) +
      " | calendar: " + (((.calendar.enabled // false) == true) | tostring) +
      " | contacts: " + (((.contacts.enabled // false) == true) | tostring) +
      " | files: " + (((.files.enabled // false) == true) | tostring)
    ' "$(_m365_accounts_path)"
}

_m365_scopes() {
    local alias="$1"
    _m365_account_exists "$alias" || return 1
    printf 'User.Read\n'
    # Mail.ReadWrite replaces Mail.Read only when the alias opts into mail moves; there is still no send or delete command.
    if _m365_account_value "$alias" '(.mail.enabled // false) == true' 2>/dev/null | grep -qx true; then
        if _m365_account_value "$alias" '(.mail.write_enabled // false) == true' 2>/dev/null | grep -qx true; then printf 'Mail.ReadWrite\n'; else printf 'Mail.Read\n'; fi
    fi
    _m365_account_value "$alias" '(.calendar.enabled // false) == true' 2>/dev/null | grep -qx true && printf 'Calendars.ReadWrite\n'
    _m365_account_value "$alias" '(.contacts.enabled // false) == true' 2>/dev/null | grep -qx true && printf 'Contacts.ReadWrite\n'
    _m365_account_value "$alias" '(.files.enabled // false) == true' 2>/dev/null | grep -qx true && printf 'Files.ReadWrite\n'
    return 0
}

_m365_auth_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-auth.py" "$@"
}

_m365_powershell_bin() {
    printf '%s\n' "${M365_PWSH_BIN:-pwsh}"
}

_m365_powershell_helper() {
    printf '%s/m365-graph.ps1\n' "$LIB_DIR"
}

_m365_powershell_ready() {
    local pwsh
    pwsh="$(_m365_powershell_bin)"
    command -v "$pwsh" >/dev/null 2>&1 || { _err "PowerShell is required for Microsoft 365 auth_provider graph-powershell"; return 1; }
    "$pwsh" -NoLogo -NoProfile -Command 'if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) { exit 1 }' >/dev/null 2>&1 || {
        _err "Microsoft.Graph.Authentication is not installed for PowerShell"
        _say "NEXT: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        return 1
    }
}

_m365_msal_ready() {
    _check_command curl >/dev/null || { _err "curl is required for Microsoft 365 auth_provider msal"; return 1; }
    "$LIFEOS_PY" -c 'import msal' >/dev/null 2>&1 || {
        _err "MSAL is not installed in the LifeOS Python environment"
        _say "NEXT: run './lifeos.sh setup'"
        return 1
    }
}

_m365_scopes_json() {
    _m365_scopes "$1" | jq -Rsc 'split("\n") | map(select(length > 0))'
}

_m365_uri_encode() {
    jq -rn --arg value "$1" '$value | @uri'
}

_m365_prepare_powershell_request() {
    local method="$1" alias="$2" url="$3" body="$4" out="$5" pair key value separator header name headers_json scopes_json tenant
    shift 5
    headers_json='{}'
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --data-urlencode)
                [ "$#" -ge 2 ] || { _err "--data-urlencode requires a value"; return 1; }
                pair="$2"
                key="${pair%%=*}"
                if [ "$key" = "$pair" ]; then value=""; else value="${pair#*=}"; fi
                case "$url" in *\?*) separator='&' ;; *) separator='?' ;; esac
                url="${url}${separator}$(_m365_uri_encode "$key")=$(_m365_uri_encode "$value")"
                shift 2
                ;;
            -H|--header)
                [ "$#" -ge 2 ] || { _err "$1 requires a header value"; return 1; }
                header="$2"
                name="${header%%:*}"
                value="${header#*:}"
                while [ "${value# }" != "$value" ]; do value="${value# }"; done
                headers_json="$(jq -cn --argjson current "$headers_json" --arg name "$name" --arg value "$value" '$current + {($name): $value}')" || return 1
                shift 2
                ;;
            *)
                _err "Unsupported Microsoft Graph request option for graph-powershell: $1"
                return 1
                ;;
        esac
    done
    scopes_json="$(_m365_scopes_json "$alias")" || return 1
    tenant="$(_m365_account_value "$alias" '.tenant // "organizations"')" || tenant="organizations"
    jq -n \
        --arg method "$method" \
        --arg uri "$url" \
        --arg body "$body" \
        --arg tenant "$tenant" \
        --argjson headers "$headers_json" \
        --argjson scopes "$scopes_json" \
        '{method: $method, uri: $uri, body: $body, tenant: $tenant, headers: $headers, scopes: $scopes}' > "$out"
}

_m365_powershell_invoke() {
    local mode="$1" request_path="$2" pwsh
    pwsh="$(_m365_powershell_bin)"
    "$pwsh" -NoLogo -NoProfile -File "$(_m365_powershell_helper)" -Mode "$mode" -RequestPath "$request_path"
}

_m365_powershell_auth() {
    local alias="$1" no_browser="$2" request scopes_json tenant status
    _m365_powershell_ready || return 1
    request="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-auth.XXXXXX")" || return 1
    scopes_json="$(_m365_scopes_json "$alias")" || return 1
    tenant="$(_m365_account_value "$alias" '.tenant // "organizations"')" || tenant="organizations"
    jq -n \
        --arg tenant "$tenant" \
        --argjson scopes "$scopes_json" \
        --argjson no_browser "$([ -n "$no_browser" ] && printf true || printf false)" \
        '{tenant: $tenant, scopes: $scopes, no_browser: $no_browser}' > "$request" || return 1
    if _m365_powershell_invoke auth "$request"; then status=0; else status=$?; fi
    rm -f "$request"
    return "$status"
}

_m365_auth() {
    local alias="${1:-}" no_browser="" provider client_id tenant token_path scope scopes=()
    [ -n "$alias" ] || { _err "m365 auth requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-browser) no_browser="--no-browser"; shift ;;
            *) _err "Unknown m365 auth option: $1"; return 1 ;;
        esac
    done
    _m365_account_exists "$alias" || { _err "Unknown Microsoft 365 account alias: $alias"; return 1; }
    provider="$(_m365_auth_provider "$alias")" || return 1
    case "$provider" in
        graph-powershell)
            _m365_powershell_auth "$alias" "$no_browser"
            return
            ;;
        msal) _m365_msal_ready || return 1 ;;
        *) _err "Unsupported Microsoft 365 auth_provider for alias '$alias': $provider"; return 1 ;;
    esac
    client_id="$(_m365_account_value "$alias" '.client_id')" || { _err "Microsoft 365 alias '$alias' needs client_id"; return 1; }
    tenant="$(_m365_account_value "$alias" '.tenant // "organizations"')" || tenant="organizations"
    token_path="$(_m365_account_path "$alias" '.token_path')" || { _err "Microsoft 365 alias '$alias' needs token_path"; return 1; }
    while IFS= read -r scope || [ -n "$scope" ]; do
        [ -n "$scope" ] && scopes+=("$scope")
    done <<EOF
$(_m365_scopes "$alias")
EOF
    if [ -n "$no_browser" ]; then
        _m365_auth_helper auth "$client_id" "$tenant" "$token_path" "${scopes[@]}" "$no_browser"
    else
        _m365_auth_helper auth "$client_id" "$tenant" "$token_path" "${scopes[@]}"
    fi
}

_m365_access_token() {
    local alias="$1" provider client_id tenant token_path scope scopes=()
    _m365_account_exists "$alias" || { _err "Unknown Microsoft 365 account alias: $alias"; return 1; }
    provider="$(_m365_auth_provider "$alias")" || return 1
    [ "$provider" = "msal" ] || { _err "Raw access tokens are unavailable for Microsoft 365 auth_provider '$provider'"; return 1; }
    _m365_msal_ready || return 1
    client_id="$(_m365_account_value "$alias" '.client_id')" || return 1
    tenant="$(_m365_account_value "$alias" '.tenant // "organizations"')" || tenant="organizations"
    token_path="$(_m365_account_path "$alias" '.token_path')" || return 1
    if [ ! -f "$token_path" ]; then
        _err "Microsoft token cache does not exist for alias '$alias': $token_path"
        _say "NEXT: run './lifeos.sh m365 auth $alias'" >&2
        return 1
    fi
    while IFS= read -r scope || [ -n "$scope" ]; do
        [ -n "$scope" ] && scopes+=("$scope")
    done <<EOF
$(_m365_scopes "$alias")
EOF
    _m365_auth_helper access-token "$client_id" "$tenant" "$token_path" "${scopes[@]}"
}

_m365_graph_base() {
    local alias="$1"
    _m365_account_value "$alias" '.graph_base // "https://graph.microsoft.com/v1.0"' 2>/dev/null || printf 'https://graph.microsoft.com/v1.0'
}

_m365_http_msal() {
    local method="$1" alias="$2" url="$3" body="$4" token response http_code message
    shift 4
    token="$(_m365_access_token "$alias")" || return 1
    response="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-response.XXXXXX")" || return 1
    if [ -n "$body" ]; then
        http_code="$(curl -sS -o "$response" -w '%{http_code}' -X "$method" "$url" \
            -H "Authorization: Bearer ${token}" \
            -H "Content-Type: application/json; charset=utf-8" \
            --data-binary "$body" "$@")" || { _err "Microsoft Graph request failed before receiving a response"; return 1; }
    else
        http_code="$(curl -sS -o "$response" -w '%{http_code}' -X "$method" --get "$url" \
            -H "Authorization: Bearer ${token}" \
            -H "Accept: application/json" "$@")" || { _err "Microsoft Graph request failed before receiving a response"; return 1; }
    fi
    case "$http_code" in
        2??) cat "$response" ;;
        *)
            message="$(jq -r 'if .error then ((.error.code // "GraphError") + ": " + (.error.message // "request failed")) else empty end' "$response" 2>/dev/null)"
            [ -n "$message" ] || message="Microsoft Graph returned HTTP $http_code"
            _err "$message"
            return 1
            ;;
    esac
}

_m365_http_powershell() {
    local method="$1" alias="$2" url="$3" body="$4" request status
    shift 4
    _m365_powershell_ready || return 1
    request="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-request.XXXXXX")" || return 1
    _m365_prepare_powershell_request "$method" "$alias" "$url" "$body" "$request" "$@" || { rm -f "$request"; return 1; }
    if _m365_powershell_invoke request "$request"; then status=0; else status=$?; fi
    rm -f "$request"
    return "$status"
}

_m365_http() {
    local method="$1" alias="$2" url="$3" body="$4" provider
    shift 4
    provider="$(_m365_auth_provider "$alias")" || return 1
    case "$provider" in
        graph-powershell) _m365_http_powershell "$method" "$alias" "$url" "$body" "$@" ;;
        msal) _m365_http_msal "$method" "$alias" "$url" "$body" "$@" ;;
        *) _err "Unsupported Microsoft 365 auth_provider for alias '$alias': $provider"; return 1 ;;
    esac
}

_m365_get() {
    local alias="$1" url="$2"
    shift 2
    _m365_http GET "$alias" "$url" "" "$@"
}

_m365_write() {
    local method="$1" alias="$2" url="$3" body="$4"
    _m365_http "$method" "$alias" "$url" "$body"
}

_m365_get_paginated() {
    local alias="$1" max_results="$2" out="$3" url="$4" page_dir page next count
    local pages=()
    shift 4
    page_dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-pages.XXXXXX")" || return 1
    page="${page_dir}/0.json"
    _m365_get "$alias" "$url" "$@" > "$page" || return 1
    pages+=("$page")
    while :; do
        count="$(jq -s '[.[].value[]?] | length' "${pages[@]}")" || return 1
        [ "$count" -lt "$max_results" ] || break
        next="$(jq -r '."@odata.nextLink" // empty' "$page")" || return 1
        [ -n "$next" ] || break
        page="${page_dir}/${#pages[@]}.json"
        _m365_get "$alias" "$next" > "$page" || return 1
        pages+=("$page")
    done
    jq -s --argjson max "$max_results" '{value: ([.[].value[]?] | .[:$max])}' "${pages[@]}" > "$out"
}

_m365_profile_json() {
    local alias="$1"
    _m365_get "$alias" "$(_m365_graph_base "$alias")/me" \
        --data-urlencode "\$select=id,displayName,givenName,surname,mail,userPrincipalName"
}

_m365_profile() {
    local alias="${1:-}" json=0 profile
    [ -n "$alias" ] || { _err "m365 profile requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown m365 profile option: $1"; return 1 ;;
        esac
    done
    profile="$(_m365_profile_json "$alias")" || return 1
    if [ "$json" -eq 1 ]; then
        printf '%s\n' "$profile"
    else
        printf '%s' "$profile" | jq -r '
          "Display name: " + (.displayName // "") + "\n" +
          "Mail: " + (.mail // "") + "\n" +
          "User principal: " + (.userPrincipalName // "") + "\n" +
          "Graph user ID: " + (.id // "")
        '
    fi
}

_m365_profile_email() {
    local alias="$1"
    _m365_profile_json "$alias" | jq -r '.mail // .userPrincipalName // ""'
}

_m365_sources_dir() {
    printf '%s/m365\n' "$(_sources_dir)"
}

_m365_output() {
    local alias="$1" service="$2" qa="$3"
    if [ "$qa" -eq 1 ]; then
        printf '%s/m365/%s-%s.md\n' "$QA_DIR" "$alias" "$service"
    else
        printf '%s/%s-%s.md\n' "$(_m365_sources_dir)" "$alias" "$service"
    fi
}

_m365_write_index() {
    local dir="$1" refreshed="${2:-}" alias service file
    [ -d "$dir" ] || return 0
    {
        printf '# Microsoft 365\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf '## Source Snapshots\n\n'
        while IFS= read -r alias || [ -n "$alias" ]; do
            for service in mail calendar contacts; do
                file="${alias}-${service}.md"
                [ -f "${dir}/${file}" ] && printf -- '- [%s %s](%s)\n' "$alias" "$service" "$file"
            done
        done <<EOF
$(jq -r '(.accounts // [])[] | .alias' "$(_m365_accounts_path)")
EOF
    } > "${dir}/index.md"
}

_m365_days_ago() {
    "$LIFEOS_PY" -c 'from datetime import datetime, timedelta, timezone; import sys; print((datetime.now(timezone.utc) - timedelta(days=int(sys.argv[1]))).replace(microsecond=0).isoformat().replace("+00:00", "Z"))' "$1"
}

_m365_render_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-render.py" "$@"
}

_m365_write_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-write.py" "$@"
}

_m365_mail_sync() {
    local alias="${1:-}" qa=0 custom_out="" out tmp json profile_email refreshed days max_results body_limit after dir
    [ -n "$alias" ] || { _err "m365 mail sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) qa=1; shift ;;
            --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;;
            *) _err "Unknown m365 mail sync option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" mail || return 1
    if [ -n "$custom_out" ]; then
        out="$custom_out"
    elif [ "$qa" -eq 1 ]; then
        out="$(_m365_output "$alias" mail 1)"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_m365_output "$alias" mail 0)"
    fi
    _ensure_parent_dir "$out" || return 1
    tmp="$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")" || return 1
    _register_temp_file "$tmp"
    json="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-mail.XXXXXX")" || return 1
    days="$(_m365_account_value "$alias" '.mail.days // 30')" || days=30
    max_results="$(_m365_account_value "$alias" '.mail.max_results // 150')" || max_results=150
    body_limit="$(_m365_account_value "$alias" '.mail.body_character_limit // 8000')" || body_limit=8000
    after="$(_m365_days_ago "$days")" || return 1
    _say "Syncing Microsoft 365 Inbox: $alias" >&2
    _m365_get_paginated "$alias" "$max_results" "$json" "$(_m365_graph_base "$alias")/me/mailFolders/inbox/messages" \
        --data-urlencode "\$top=${max_results}" \
        --data-urlencode "\$filter=receivedDateTime ge ${after}" \
        --data-urlencode "\$orderby=receivedDateTime desc" \
        --data-urlencode "\$select=id,conversationId,subject,from,toRecipients,ccRecipients,receivedDateTime,body,bodyPreview,hasAttachments,isRead,importance,webLink,internetMessageHeaders,categories" \
        -H 'Prefer: outlook.body-content-type="text"' || return 1
    profile_email="$(_m365_profile_email "$alias")" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    _m365_render_helper mail --alias "$alias" --email "$profile_email" --refreshed "$refreshed" --days "$days" --max-results "$max_results" --body-limit "$body_limit" --input "$json" > "$tmp" || return 1
    mv "$tmp" "$out"
    dir="$(dirname "$out")"
    case "$out" in
        */m365/*.md) _m365_write_index "$dir" "$refreshed" ;;
    esac
    _say "Updated $out"
}

_m365_calendar_ids() {
    local alias="$1"
    _m365_account_value "$alias" '.calendar.calendar_ids // ["primary"] | .[]' 2>/dev/null || printf 'primary\n'
}

_m365_calendar_writable_ids() {
    local alias="$1"
    _m365_account_value "$alias" '.calendar.writable_calendar_ids // ["primary"] | .[]' 2>/dev/null || printf 'primary\n'
}

_m365_calendar_is_writable() {
    local alias="$1" requested="$2" value
    while IFS= read -r value || [ -n "$value" ]; do
        [ "$value" = "$requested" ] && return 0
    done <<EOF
$(_m365_calendar_writable_ids "$alias")
EOF
    return 1
}

_m365_calendar_timezone() {
    local alias="$1"
    _m365_account_value "$alias" '.calendar.timezone // "Central Standard Time"' 2>/dev/null || printf 'Central Standard Time'
}

_m365_calendar_window() {
    "$LIFEOS_PY" -c 'from datetime import datetime, timedelta, timezone; import sys; now=datetime.now(timezone.utc); start=(now-timedelta(days=int(sys.argv[1]))).replace(hour=0,minute=0,second=0,microsecond=0); end=(now+timedelta(days=int(sys.argv[2])+1)).replace(hour=0,minute=0,second=0,microsecond=0); print(start.isoformat().replace("+00:00","Z")); print(end.isoformat().replace("+00:00","Z"))' "$LIFEOS_DAYS_BACK" "$LIFEOS_DAYS_AHEAD"
}

_m365_calendar_list() {
    local alias="${1:-}" json
    [ -n "$alias" ] || { _err "m365 calendar list-calendars requires ALIAS"; return 1; }
    _m365_require_enabled "$alias" calendar || return 1
    json="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-calendars.XXXXXX")" || return 1
    _m365_get_paginated "$alias" 500 "$json" "$(_m365_graph_base "$alias")/me/calendars" \
        --data-urlencode "\$top=500" \
        --data-urlencode "\$select=id,name,isDefaultCalendar,canEdit,canShare,owner" || return 1
    jq -r '
      (.value // [])[] |
      "- " + (.name // "Untitled calendar") +
      " | id: " + (.id // "") +
      " | default: " + ((.isDefaultCalendar // false) | tostring) +
      " | editable: " + ((.canEdit // false) | tostring)
    ' "$json"
}

_m365_calendar_path() {
    local alias="$1" calendar_id="$2" suffix="$3" encoded
    if [ "$calendar_id" = "primary" ]; then
        printf '%s/me/calendar/%s\n' "$(_m365_graph_base "$alias")" "$suffix"
    else
        encoded="$(_urlencode "$calendar_id")" || return 1
        printf '%s/me/calendars/%s/%s\n' "$(_m365_graph_base "$alias")" "$encoded" "$suffix"
    fi
}

_m365_calendar_fetch() {
    local alias="$1" from="$2" to="$3" calendar_ids="$4" out="$5" timezone calendar_id meta events item dir endpoint encoded
    local items=()
    # Optional 6th argument overrides the response time zone; the unified agenda fetches in UTC and converts to the Google calendar's IANA zone.
    timezone="${6:-$(_m365_calendar_timezone "$alias")}"
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-calendar.XXXXXX")" || return 1
    for calendar_id in $calendar_ids; do
        calendar_id="$(_trim "$calendar_id")"
        [ -n "$calendar_id" ] || continue
        meta="${dir}/${#items[@]}-meta.json"
        events="${dir}/${#items[@]}-events.json"
        item="${dir}/${#items[@]}-item.json"
        if [ "$calendar_id" = "primary" ]; then
            _m365_get "$alias" "$(_m365_graph_base "$alias")/me/calendar" \
                --data-urlencode "\$select=id,name,isDefaultCalendar,canEdit,owner" > "$meta" || return 1
        else
            encoded="$(_urlencode "$calendar_id")" || return 1
            _m365_get "$alias" "$(_m365_graph_base "$alias")/me/calendars/${encoded}" \
                --data-urlencode "\$select=id,name,isDefaultCalendar,canEdit,owner" > "$meta" || return 1
        fi
        endpoint="$(_m365_calendar_path "$alias" "$calendar_id" 'calendarView')" || return 1
        _say "Syncing Microsoft 365 calendar: $(jq -r '.name // .id // "Calendar"' "$meta")" >&2
        _m365_get_paginated "$alias" 1000 "$events" "$endpoint" \
            --data-urlencode "startDateTime=${from}" \
            --data-urlencode "endDateTime=${to}" \
            --data-urlencode "\$top=1000" \
            --data-urlencode "\$select=id,iCalUId,subject,body,bodyPreview,start,end,isAllDay,isCancelled,isOnlineMeeting,onlineMeeting,location,organizer,attendees,webLink,type,seriesMasterId" \
            -H "Prefer: outlook.timezone=\"${timezone}\"" \
            -H 'Prefer: outlook.body-content-type="text"' || return 1
        jq -n --arg requested "$calendar_id" --slurpfile meta "$meta" --slurpfile events "$events" '{id: $requested, graphId: ($meta[0].id // ""), name: ($meta[0].name // $requested), events: ($events[0].value // [])}' > "$item" || return 1
        items+=("$item")
    done
    if [ "${#items[@]}" -eq 0 ]; then
        jq -n '{calendars: []}' > "$out"
    else
        jq -s '{calendars: .}' "${items[@]}" > "$out"
    fi
}

_m365_calendar_enabled_aliases() {
    local accounts_path
    accounts_path="$(_m365_accounts_path)"
    [ -f "$accounts_path" ] || return 0
    jq -r '(.accounts // [])[] | select((.calendar.enabled // false) == true) | .alias' "$accounts_path" 2>/dev/null
}

_m365_calendar_normalize_helper() {
    "$LIFEOS_PY" "${LIB_DIR}/m365-calendar-normalize.py" "$@"
}

_m365_calendar_sync() {
    local alias="${1:-}" qa=0 custom_out="" out tmp json profile_email refreshed window from to timezone ids limit dir
    [ -n "$alias" ] || { _err "m365 calendar sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) qa=1; shift ;;
            --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;;
            *) _err "Unknown m365 calendar sync option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" calendar || return 1
    if [ -n "$custom_out" ]; then out="$custom_out"; elif [ "$qa" -eq 1 ]; then out="$(_m365_output "$alias" calendar 1)"; else _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_m365_output "$alias" calendar 0)"; fi
    _ensure_parent_dir "$out" || return 1
    tmp="$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")" || return 1
    _register_temp_file "$tmp"
    json="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-calendar-render.XXXXXX")" || return 1
    window="$(_m365_calendar_window)" || return 1
    from="$(printf '%s\n' "$window" | sed -n '1p')"
    to="$(printf '%s\n' "$window" | sed -n '2p')"
    ids="$(printf '%s\n' "$(_m365_calendar_ids "$alias")" | tr '\n' ' ')"
    _m365_calendar_fetch "$alias" "$from" "$to" "$ids" "$json" || return 1
    profile_email="$(_m365_profile_email "$alias")" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    timezone="$(_m365_calendar_timezone "$alias")"
    limit="$(_m365_account_value "$alias" '.calendar.description_character_limit // 8000')" || limit=8000
    _m365_render_helper calendar --alias "$alias" --email "$profile_email" --refreshed "$refreshed" --start "$from" --end "$to" --timezone "$timezone" --description-limit "$limit" --input "$json" > "$tmp" || return 1
    mv "$tmp" "$out"
    dir="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dir" "$refreshed" ;; esac
    _say "Updated $out"
}

_m365_calendar_find_human() {
    jq -r '
      (.items // [])[] |
      [
        ("- " + (.subject // "Untitled event")),
        ("calendar: " + (._calendar_name // ._calendar_id // "")),
        ("calendar_id: " + (._calendar_id // "")),
        ("event_id: " + (.id // "")),
        ("start: " + (.start.dateTime // "")),
        ("end: " + (.end.dateTime // "")),
        (if ((.location.displayName // "") != "") then "location: " + .location.displayName else empty end),
        (if ((.webLink // "") != "") then .webLink else empty end)
      ] | join(" | ")
    '
}

_m365_calendar_find() {
    local alias="${1:-}" query="" from="" to="" calendar_id="" json_mode=0 window ids data results
    [ -n "$alias" ] || { _err "m365 calendar find requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --from) [ -n "${2:-}" ] || { _err "--from requires YYYY-MM-DD"; return 1; }; from="${2}T00:00:00Z"; shift 2 ;;
            --to) [ -n "${2:-}" ] || { _err "--to requires YYYY-MM-DD"; return 1; }; to="${2}T23:59:59Z"; shift 2 ;;
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            -*) _err "Unknown m365 calendar find option: $1"; return 1 ;;
            *) if [ -z "$query" ]; then query="$1"; shift; else _err "Unexpected argument: $1"; return 1; fi ;;
        esac
    done
    [ -n "$query" ] || { _err "m365 calendar find requires QUERY"; return 1; }
    _m365_require_enabled "$alias" calendar || return 1
    window="$(_m365_calendar_window)" || return 1
    [ -n "$from" ] || from="$(printf '%s\n' "$window" | sed -n '1p')"
    [ -n "$to" ] || to="$(printf '%s\n' "$window" | sed -n '2p')"
    if [ -n "$calendar_id" ]; then ids="$calendar_id"; else ids="$(printf '%s\n' "$(_m365_calendar_ids "$alias")" | tr '\n' ' ')"; fi
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-calendar-find.XXXXXX")" || return 1
    results="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-calendar-results.XXXXXX")" || return 1
    _m365_calendar_fetch "$alias" "$from" "$to" "$ids" "$data" || return 1
    jq --arg q "$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')" '{items: [(.calendars // [])[] as $calendar | ($calendar.events // [])[] | select((((.subject // "") + " " + (.bodyPreview // "") + " " + (.location.displayName // "")) | ascii_downcase | contains($q))) | . + {_calendar_id: $calendar.id, _calendar_name: $calendar.name}]}' "$data" > "$results" || return 1
    if [ "$json_mode" -eq 1 ]; then
        cat "$results"
    elif [ "$(jq '(.items // []) | length' "$results")" -eq 0 ]; then
        _say "No matching Microsoft 365 events found."
    else
        _m365_calendar_find_human < "$results"
    fi
}

_m365_resolve_attendees() {
    local raw email
    _RESOLVED_EMAILS=()
    _RESOLVED_DISPLAY=()
    for raw in "$@"; do
        case "$raw" in
            *@*) email="$raw" ;;
            *)
                email="$(_people_alias_lookup "$raw")" || {
                    _err "No deterministic local alias matched '$raw'. Pass a full email or run 'lifeos people add-alias NAME EMAIL'."
                    return 1
                }
                ;;
        esac
        _RESOLVED_EMAILS+=("$email")
        if [ "$raw" = "$email" ]; then _RESOLVED_DISPLAY+=("$email"); else _RESOLVED_DISPLAY+=("$raw -> $email"); fi
    done
}

_m365_calendar_event_url() {
    local alias="$1" calendar_id="$2" event_id="${3:-}" encoded event_encoded base
    base="$(_m365_graph_base "$alias")"
    if [ "$calendar_id" = "primary" ]; then
        if [ -n "$event_id" ]; then event_encoded="$(_urlencode "$event_id")" || return 1; printf '%s/me/events/%s\n' "$base" "$event_encoded"; else printf '%s/me/calendar/events\n' "$base"; fi
    else
        encoded="$(_urlencode "$calendar_id")" || return 1
        if [ -n "$event_id" ]; then event_encoded="$(_urlencode "$event_id")" || return 1; printf '%s/me/calendars/%s/events/%s\n' "$base" "$encoded" "$event_encoded"; else printf '%s/me/calendars/%s/events\n' "$base" "$encoded"; fi
    fi
}

_m365_calendar_create() {
    local alias="${1:-}" calendar_id="primary" title="" start="" end="" tz="" location="" desc="" desc_file="" notify=0 execute=0 body created
    local attendees_raw=() build_args=()
    [ -n "$alias" ] || { _err "m365 calendar create-event requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; shift 2 ;;
            --start) [ -n "${2:-}" ] || { _err "--start requires DATE or DATETIME"; return 1; }; start="$2"; shift 2 ;;
            --end) [ -n "${2:-}" ] || { _err "--end requires DATE or DATETIME"; return 1; }; end="$2"; shift 2 ;;
            --tz) [ -n "${2:-}" ] || { _err "--tz requires ZONE"; return 1; }; tz="$2"; shift 2 ;;
            --location) [ -n "${2+x}" ] || { _err "--location requires TEXT"; return 1; }; location="$2"; shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; shift 2 ;;
            --attendee) [ -n "${2:-}" ] || { _err "--attendee requires NAME or EMAIL"; return 1; }; attendees_raw+=("$2"); shift 2 ;;
            --notify) notify=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 calendar create-event option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" calendar || return 1
    [ -n "$title" ] || { _err "create-event requires --title"; return 1; }
    [ -n "$start" ] || { _err "create-event requires --start"; return 1; }
    _m365_calendar_is_writable "$alias" "$calendar_id" || { _err "Calendar '$calendar_id' is not writable for alias '$alias'"; return 1; }
    if [ "${#attendees_raw[@]}" -gt 0 ] && [ "$notify" -ne 1 ]; then
        _err "Microsoft may email invitations when an event has attendees. Re-run with --notify to acknowledge that blast radius."
        return 1
    fi
    if [ -n "$desc_file" ]; then [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }; desc="$(cat "$desc_file")"; fi
    [ -n "$tz" ] || tz="$(_m365_calendar_timezone "$alias")"
    if [ "${#attendees_raw[@]}" -gt 0 ]; then _m365_resolve_attendees "${attendees_raw[@]}" || return 1; else _RESOLVED_EMAILS=(); _RESOLVED_DISPLAY=(); fi
    build_args=(event --title "$title" --start "$start")
    [ -n "$end" ] && build_args+=(--end "$end")
    [ -n "$tz" ] && build_args+=(--tz "$tz")
    [ -n "$location" ] && build_args+=(--location "$location")
    [ -n "$desc" ] && build_args+=(--description "$desc")
    local email
    for email in "${_RESOLVED_EMAILS[@]}"; do build_args+=(--attendee "$email"); done
    body="$(_m365_write_helper "${build_args[@]}")" || return 1
    _say "Microsoft 365 event create plan:"
    _say "Account: $alias"
    _say "Calendar: $calendar_id"
    _say "Title: $title"
    _say "Start: $start"
    _say "End: ${end:-<default>}"
    [ -n "$tz" ] && _say "Time zone: $tz"
    _say "Location: ${location:-<none>}"
    if [ "${#_RESOLVED_DISPLAY[@]}" -gt 0 ]; then _say "Attendees: ${_RESOLVED_DISPLAY[*]}"; else _say "Attendees: <none>"; fi
    _say "Microsoft invitation/update email acknowledged: $([ "$notify" -eq 1 ] && echo yes || echo no)"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no event was created. Re-run with --execute to create it."; return 0; fi
    created="$(_m365_write POST "$alias" "$(_m365_calendar_event_url "$alias" "$calendar_id")" "$body")" || return 1
    _say "Created event: $(printf '%s' "$created" | jq -r '.webLink // .id // "(unknown)"')"
}

_m365_calendar_update() {
    local alias="${1:-}" calendar_id="primary" event_id="" title="" start="" end="" tz="" location="" desc="" desc_file=""
    local set_title=0 set_location=0 set_desc=0 notify=0 execute=0 replace_attendees=0 body current updated attendee_count
    local attendees_raw=() final_emails=() build_args=()
    [ -n "$alias" ] || { _err "m365 calendar update-event requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --event) [ -n "${2:-}" ] || { _err "--event requires ID"; return 1; }; event_id="$2"; shift 2 ;;
            --title) [ -n "${2+x}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; set_title=1; shift 2 ;;
            --start) [ -n "${2:-}" ] || { _err "--start requires DATE or DATETIME"; return 1; }; start="$2"; shift 2 ;;
            --end) [ -n "${2:-}" ] || { _err "--end requires DATE or DATETIME"; return 1; }; end="$2"; shift 2 ;;
            --tz) [ -n "${2:-}" ] || { _err "--tz requires ZONE"; return 1; }; tz="$2"; shift 2 ;;
            --location) [ -n "${2+x}" ] || { _err "--location requires TEXT"; return 1; }; location="$2"; set_location=1; shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; set_desc=1; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; set_desc=1; shift 2 ;;
            --attendee) [ -n "${2:-}" ] || { _err "--attendee requires NAME or EMAIL"; return 1; }; attendees_raw+=("$2"); shift 2 ;;
            --replace-attendees) replace_attendees=1; shift ;;
            --notify) notify=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 calendar update-event option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" calendar || return 1
    [ -n "$event_id" ] || { _err "update-event requires --event"; return 1; }
    _m365_calendar_is_writable "$alias" "$calendar_id" || { _err "Calendar '$calendar_id' is not writable for alias '$alias'"; return 1; }
    if [ -n "$desc_file" ]; then [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }; desc="$(cat "$desc_file")"; fi
    current="$(_m365_get "$alias" "$(_m365_calendar_event_url "$alias" "$calendar_id" "$event_id")" -H 'Prefer: outlook.body-content-type="text"')" || return 1
    attendee_count="$(printf '%s' "$current" | jq '(.attendees // []) | length')"
    if { [ "$attendee_count" -gt 0 ] || [ "${#attendees_raw[@]}" -gt 0 ]; } && [ "$notify" -ne 1 ]; then
        _err "This meeting has or will have attendees, and Microsoft may send an update. Re-run with --notify to acknowledge that blast radius."
        return 1
    fi
    if [ "$set_desc" -eq 1 ] && printf '%s' "$current" | jq -e '.isOnlineMeeting == true' >/dev/null 2>&1; then
        _err "Description updates are blocked for online meetings because replacing the body can remove the Teams meeting blob."
        return 1
    fi
    if [ -n "$start" ]; then [ -n "$tz" ] || tz="$(_m365_calendar_timezone "$alias")"; fi
    if [ "${#attendees_raw[@]}" -gt 0 ] || [ "$replace_attendees" -eq 1 ]; then
        if [ "${#attendees_raw[@]}" -gt 0 ]; then _m365_resolve_attendees "${attendees_raw[@]}" || return 1; else _RESOLVED_EMAILS=(); fi
        if [ "$replace_attendees" -ne 1 ]; then
            local existing
            while IFS= read -r existing || [ -n "$existing" ]; do [ -n "$existing" ] && final_emails+=("$existing"); done <<EOF
$(printf '%s' "$current" | jq -r '(.attendees // [])[] | .emailAddress.address // empty')
EOF
        fi
        final_emails+=("${_RESOLVED_EMAILS[@]}")
    fi
    build_args=(event)
    [ "$set_title" -eq 1 ] && build_args+=(--title "$title")
    [ -n "$start" ] && build_args+=(--start "$start")
    [ -n "$end" ] && build_args+=(--end "$end")
    [ -n "$tz" ] && build_args+=(--tz "$tz")
    [ "$set_location" -eq 1 ] && build_args+=(--location "$location")
    [ "$set_desc" -eq 1 ] && build_args+=(--description "$desc")
    local email
    for email in "${final_emails[@]}"; do build_args+=(--attendee "$email"); done
    body="$(_m365_write_helper "${build_args[@]}")" || return 1
    if printf '%s' "$body" | jq -e '.attendees' >/dev/null 2>&1; then body="$(printf '%s' "$body" | jq -c '.attendees |= unique_by(.emailAddress.address | ascii_downcase)')"; fi
    _say "Microsoft 365 event update plan:"
    _say "Account: $alias"
    _say "Calendar: $calendar_id"
    _say "Event: $event_id"
    _say "Current title: $(printf '%s' "$current" | jq -r '.subject // "(none)"')"
    _say "Changes:"
    printf '%s' "$body" | jq .
    _say "Microsoft invitation/update email acknowledged: $([ "$notify" -eq 1 ] && echo yes || echo no)"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no event was updated. Re-run with --execute to apply."; return 0; fi
    updated="$(_m365_write PATCH "$alias" "$(_m365_calendar_event_url "$alias" "$calendar_id" "$event_id")" "$body")" || return 1
    _say "Updated event: $(printf '%s' "$updated" | jq -r '.webLink // .id // "(unknown)"')"
}

_m365_contacts_max() {
    local alias="$1"
    _m365_account_value "$alias" '.contacts.max_results // 500' 2>/dev/null || printf '500'
}

_m365_contacts_fetch() {
    local alias="$1" out="$2" max
    max="$(_m365_contacts_max "$alias")"
    _m365_get_paginated "$alias" "$max" "$out" "$(_m365_graph_base "$alias")/me/contacts" \
        --data-urlencode "\$top=${max}" \
        --data-urlencode "\$orderby=displayName" \
        --data-urlencode "\$select=id,displayName,givenName,surname,emailAddresses,businessPhones,mobilePhone,companyName,jobTitle,personalNotes,parentFolderId"
}

_m365_contacts_human() {
    jq -r '
      (.value // [])[] |
      [
        ("- " + (.displayName // .givenName // "Unnamed contact")),
        ("contact_id: " + (.id // "")),
        ("email: " + (((.emailAddresses // []) | map(.address // "") | map(select(. != ""))) | join(", "))),
        (if ((.companyName // "") != "") then "company: " + .companyName else empty end),
        (if ((.jobTitle // "") != "") then "title: " + .jobTitle else empty end)
      ] | join(" | ")
    '
}

_m365_contacts_list() {
    local alias="${1:-}" json_mode=0 data
    [ -n "$alias" ] || { _err "m365 contacts list requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --json) json_mode=1; shift ;; *) _err "Unknown m365 contacts list option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" contacts || return 1
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-contacts.XXXXXX")" || return 1
    _m365_contacts_fetch "$alias" "$data" || return 1
    if [ "$json_mode" -eq 1 ]; then cat "$data"; else _m365_contacts_human < "$data"; fi
}

_m365_contacts_find() {
    local alias="${1:-}" query="" json_mode=0 data results
    [ -n "$alias" ] || { _err "m365 contacts find requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json_mode=1; shift ;;
            -*) _err "Unknown m365 contacts find option: $1"; return 1 ;;
            *) if [ -z "$query" ]; then query="$1"; shift; else _err "Unexpected argument: $1"; return 1; fi ;;
        esac
    done
    [ -n "$query" ] || { _err "m365 contacts find requires QUERY"; return 1; }
    _m365_require_enabled "$alias" contacts || return 1
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-contacts-find.XXXXXX")" || return 1
    results="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-contacts-results.XXXXXX")" || return 1
    _m365_contacts_fetch "$alias" "$data" || return 1
    jq --arg q "$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')" '{value: [(.value // [])[] | select((((.displayName // "") + " " + (.givenName // "") + " " + (.surname // "") + " " + (.companyName // "") + " " + (.jobTitle // "") + " " + (((.emailAddresses // []) | map(.address // "")) | join(" "))) | ascii_downcase | contains($q)))]}' "$data" > "$results" || return 1
    if [ "$json_mode" -eq 1 ]; then cat "$results"; elif [ "$(jq '(.value // []) | length' "$results")" -eq 0 ]; then _say "No matching Outlook contacts found."; else _m365_contacts_human < "$results"; fi
}

_m365_contacts_sync() {
    local alias="${1:-}" qa=0 custom_out="" out tmp data email refreshed max notes_limit dir
    [ -n "$alias" ] || { _err "m365 contacts sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --qa) qa=1; shift ;; --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;; *) _err "Unknown m365 contacts sync option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" contacts || return 1
    if [ -n "$custom_out" ]; then out="$custom_out"; elif [ "$qa" -eq 1 ]; then out="$(_m365_output "$alias" contacts 1)"; else _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_m365_output "$alias" contacts 0)"; fi
    _ensure_parent_dir "$out" || return 1
    tmp="$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")" || return 1
    _register_temp_file "$tmp"
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-contacts-render.XXXXXX")" || return 1
    _say "Syncing Outlook contacts: $alias" >&2
    _m365_contacts_fetch "$alias" "$data" || return 1
    email="$(_m365_profile_email "$alias")" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    max="$(_m365_contacts_max "$alias")"
    notes_limit="$(_m365_account_value "$alias" '.contacts.notes_character_limit // 4000')" || notes_limit=4000
    _m365_render_helper contacts --alias "$alias" --email "$email" --refreshed "$refreshed" --max-results "$max" --notes-limit "$notes_limit" --input "$data" > "$tmp" || return 1
    mv "$tmp" "$out"
    dir="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dir" "$refreshed" ;; esac
    _say "Updated $out"
}

_m365_contacts_create() {
    local alias="${1:-}" display_name="" given_name="" surname="" mobile="" company="" job_title="" notes="" notes_file="" execute=0 body created
    local set_display=0 set_given=0 set_surname=0 set_mobile=0 set_company=0 set_job=0 set_notes=0 emails=() phones=() args=()
    [ -n "$alias" ] || { _err "m365 contacts create requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --display-name) [ -n "${2+x}" ] || { _err "--display-name requires TEXT"; return 1; }; display_name="$2"; set_display=1; shift 2 ;;
            --given-name) [ -n "${2+x}" ] || { _err "--given-name requires TEXT"; return 1; }; given_name="$2"; set_given=1; shift 2 ;;
            --surname) [ -n "${2+x}" ] || { _err "--surname requires TEXT"; return 1; }; surname="$2"; set_surname=1; shift 2 ;;
            --email) [ -n "${2:-}" ] || { _err "--email requires ADDRESS"; return 1; }; emails+=("$2"); shift 2 ;;
            --phone) [ -n "${2:-}" ] || { _err "--phone requires NUMBER"; return 1; }; phones+=("$2"); shift 2 ;;
            --mobile) [ -n "${2+x}" ] || { _err "--mobile requires NUMBER"; return 1; }; mobile="$2"; set_mobile=1; shift 2 ;;
            --company) [ -n "${2+x}" ] || { _err "--company requires TEXT"; return 1; }; company="$2"; set_company=1; shift 2 ;;
            --job-title) [ -n "${2+x}" ] || { _err "--job-title requires TEXT"; return 1; }; job_title="$2"; set_job=1; shift 2 ;;
            --notes) [ -n "${2+x}" ] || { _err "--notes requires TEXT"; return 1; }; notes="$2"; set_notes=1; shift 2 ;;
            --notes-file) [ -n "${2:-}" ] || { _err "--notes-file requires FILE"; return 1; }; notes_file="$2"; set_notes=1; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 contacts create option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" contacts || return 1
    if [ -n "$notes_file" ]; then [ -f "$notes_file" ] || { _err "Notes file does not exist: $notes_file"; return 1; }; notes="$(cat "$notes_file")"; fi
    args=(contact)
    [ "$set_display" -eq 1 ] && args+=(--display-name "$display_name")
    [ "$set_given" -eq 1 ] && args+=(--given-name "$given_name")
    [ "$set_surname" -eq 1 ] && args+=(--surname "$surname")
    local value
    for value in "${emails[@]}"; do args+=(--email "$value"); done
    for value in "${phones[@]}"; do args+=(--phone "$value"); done
    [ "$set_mobile" -eq 1 ] && args+=(--mobile "$mobile")
    [ "$set_company" -eq 1 ] && args+=(--company "$company")
    [ "$set_job" -eq 1 ] && args+=(--job-title "$job_title")
    [ "$set_notes" -eq 1 ] && args+=(--notes "$notes")
    body="$(_m365_write_helper "${args[@]}")" || return 1
    _say "Outlook contact create plan:"
    _say "Account: $alias"
    printf '%s' "$body" | jq .
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no contact was created. Re-run with --execute to create it."; return 0; fi
    created="$(_m365_write POST "$alias" "$(_m365_graph_base "$alias")/me/contacts" "$body")" || return 1
    _say "Created contact: $(printf '%s' "$created" | jq -r '(.displayName // "Contact") + " | id: " + (.id // "")')"
}

_m365_contacts_update() {
    local alias="${1:-}" contact_id="" display_name="" given_name="" surname="" mobile="" company="" job_title="" notes="" notes_file="" execute=0 body current updated encoded
    local set_display=0 set_given=0 set_surname=0 set_mobile=0 set_company=0 set_job=0 set_notes=0 emails=() phones=() args=()
    [ -n "$alias" ] || { _err "m365 contacts update requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --contact) [ -n "${2:-}" ] || { _err "--contact requires ID"; return 1; }; contact_id="$2"; shift 2 ;;
            --display-name) [ -n "${2+x}" ] || { _err "--display-name requires TEXT"; return 1; }; display_name="$2"; set_display=1; shift 2 ;;
            --given-name) [ -n "${2+x}" ] || { _err "--given-name requires TEXT"; return 1; }; given_name="$2"; set_given=1; shift 2 ;;
            --surname) [ -n "${2+x}" ] || { _err "--surname requires TEXT"; return 1; }; surname="$2"; set_surname=1; shift 2 ;;
            --email) [ -n "${2:-}" ] || { _err "--email requires ADDRESS"; return 1; }; emails+=("$2"); shift 2 ;;
            --phone) [ -n "${2:-}" ] || { _err "--phone requires NUMBER"; return 1; }; phones+=("$2"); shift 2 ;;
            --mobile) [ -n "${2+x}" ] || { _err "--mobile requires NUMBER"; return 1; }; mobile="$2"; set_mobile=1; shift 2 ;;
            --company) [ -n "${2+x}" ] || { _err "--company requires TEXT"; return 1; }; company="$2"; set_company=1; shift 2 ;;
            --job-title) [ -n "${2+x}" ] || { _err "--job-title requires TEXT"; return 1; }; job_title="$2"; set_job=1; shift 2 ;;
            --notes) [ -n "${2+x}" ] || { _err "--notes requires TEXT"; return 1; }; notes="$2"; set_notes=1; shift 2 ;;
            --notes-file) [ -n "${2:-}" ] || { _err "--notes-file requires FILE"; return 1; }; notes_file="$2"; set_notes=1; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 contacts update option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" contacts || return 1
    [ -n "$contact_id" ] || { _err "contacts update requires --contact"; return 1; }
    if [ -n "$notes_file" ]; then [ -f "$notes_file" ] || { _err "Notes file does not exist: $notes_file"; return 1; }; notes="$(cat "$notes_file")"; fi
    encoded="$(_urlencode "$contact_id")" || return 1
    current="$(_m365_get "$alias" "$(_m365_graph_base "$alias")/me/contacts/${encoded}")" || return 1
    args=(contact)
    [ "$set_display" -eq 1 ] && args+=(--display-name "$display_name")
    [ "$set_given" -eq 1 ] && args+=(--given-name "$given_name")
    [ "$set_surname" -eq 1 ] && args+=(--surname "$surname")
    local value
    for value in "${emails[@]}"; do args+=(--email "$value"); done
    for value in "${phones[@]}"; do args+=(--phone "$value"); done
    [ "$set_mobile" -eq 1 ] && args+=(--mobile "$mobile")
    [ "$set_company" -eq 1 ] && args+=(--company "$company")
    [ "$set_job" -eq 1 ] && args+=(--job-title "$job_title")
    [ "$set_notes" -eq 1 ] && args+=(--notes "$notes")
    body="$(_m365_write_helper "${args[@]}")" || return 1
    _say "Outlook contact update plan:"
    _say "Account: $alias"
    _say "Contact: $contact_id"
    _say "Current name: $(printf '%s' "$current" | jq -r '.displayName // "(unnamed)"')"
    _say "Changes:"
    printf '%s' "$body" | jq .
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no contact was updated. Re-run with --execute to apply."; return 0; fi
    updated="$(_m365_write PATCH "$alias" "$(_m365_graph_base "$alias")/me/contacts/${encoded}" "$body")" || return 1
    _say "Updated contact: $(printf '%s' "$updated" | jq -r '(.displayName // "Contact") + " | id: " + (.id // "")')"
}

##- Files (OneDrive / SharePoint via Graph). Read-side commands address items by both drive and item id; resolve-link turns an existing OneDrive, SharePoint, or Teams sharing URL into that stable pair.
_m365_files_item_url() {
    local alias="$1" item="$2" drive="$3" base encoded_item encoded_drive
    base="$(_m365_graph_base "$alias")"
    encoded_item="$(_m365_uri_encode "$item")" || return 1
    if [ -n "$drive" ]; then
        encoded_drive="$(_m365_uri_encode "$drive")" || return 1
        printf '%s/drives/%s/items/%s\n' "$base" "$encoded_drive" "$encoded_item"
    else
        printf '%s/me/drive/items/%s\n' "$base" "$encoded_item"
    fi
}

_m365_files_print_item() {
    jq -r '"name: " + (.name // "?"),
           "item_id: " + (.id // "?"),
           "drive_id: " + (.parentReference.driveId // "?"),
           "size: " + ((.size // 0) | tostring) + " bytes",
           "modified: " + (.lastModifiedDateTime // "?"),
           "mimeType: " + (.file.mimeType // "(folder or unknown)"),
           "path: " + ((.parentReference.path // "") + "/" + (.name // "")),
           "url: " + (.webUrl // "")'
}

_m365_files_search() {
    local alias="$1" query="$2" drive="" json=0 base enc response encoded_drive
    [ -n "$alias" ] || { _err "m365 files search requires ALIAS QUERY"; return 1; }
    [ -n "$query" ] || { _err "m365 files search requires a QUERY"; return 1; }
    shift 2 2>/dev/null || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --drive) [ -n "${2:-}" ] || { _err "--drive requires DRIVE_ID"; return 1; }; drive="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) _err "Unknown files search option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" files || return 1
    base="$(_m365_graph_base "$alias")"
    enc="$(_m365_uri_encode "$query")"
    if [ -n "$drive" ]; then
        encoded_drive="$(_m365_uri_encode "$drive")" || return 1
        base="${base}/drives/${encoded_drive}"
    else
        base="${base}/me/drive"
    fi
    response="$(_m365_get "$alias" "${base}/root/search(q='${enc}')" \
        --data-urlencode "\$select=id,name,size,lastModifiedDateTime,webUrl,file,parentReference" \
        --data-urlencode "\$top=25")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; return 0; fi
    printf '%s' "$response" |
        jq -r '(.value // [])[] |
            "- " + (.name // "?") +
            "\n  item_id: " + (.id // "?") +
            "\n  drive_id: " + (.parentReference.driveId // "?") +
            "\n  type: " + (.file.mimeType // "(folder)") +
            "\n  modified: " + (.lastModifiedDateTime // "?") +
            "\n  path: " + ((.parentReference.path // "") + "/" + (.name // "")) +
            "\n  url: " + (.webUrl // "")'
}

_m365_files_meta() {
    local alias="$1" item="$2" drive="" json=0 url response
    [ -n "$alias" ] || { _err "m365 files meta requires ALIAS ITEM_ID"; return 1; }
    [ -n "$item" ] || { _err "m365 files meta requires a drive-item id (from 'files search')"; return 1; }
    shift 2 2>/dev/null || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --drive) [ -n "${2:-}" ] || { _err "--drive requires DRIVE_ID"; return 1; }; drive="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) _err "Unknown files meta option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" files || return 1
    url="$(_m365_files_item_url "$alias" "$item" "$drive")" || return 1
    response="$(_m365_get "$alias" "$url" --data-urlencode "\$select=id,name,size,lastModifiedDateTime,webUrl,file,parentReference")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _m365_files_print_item; fi
}

_m365_files_resolve_link() {
    local alias="$1" sharing_url="$2" json=0 base token response
    [ -n "$alias" ] || { _err "m365 files resolve-link requires ALIAS URL"; return 1; }
    [ -n "$sharing_url" ] || { _err "m365 files resolve-link requires a OneDrive, SharePoint, or Teams sharing URL"; return 1; }
    shift 2 2>/dev/null || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown files resolve-link option: $1"; return 1 ;;
        esac
    done
    case "$sharing_url" in https://*) ;; *) _err "Sharing URL must use https://"; return 1 ;; esac
    _m365_require_enabled "$alias" files || return 1
    token="$("$LIFEOS_PY" -c 'import base64, sys; print("u!" + base64.urlsafe_b64encode(sys.argv[1].encode()).decode().rstrip("="))' "$sharing_url")" || return 1
    base="$(_m365_graph_base "$alias")"
    response="$(_m365_get "$alias" "${base}/shares/${token}/driveItem" --data-urlencode "\$select=id,name,size,lastModifiedDateTime,webUrl,file,parentReference")" || return 1
    if [ "$json" -eq 1 ]; then printf '%s\n' "$response"; else printf '%s' "$response" | _m365_files_print_item; fi
}

_m365_files_download() {
    local alias="$1" item="$2" out="" drive="" force=0 url
    shift 2 2>/dev/null || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --out) [ -n "${2:-}" ] || { _err "--out requires PATH"; return 1; }; out="$2"; shift 2 ;;
            --drive) [ -n "${2:-}" ] || { _err "--drive requires DRIVE_ID"; return 1; }; drive="$2"; shift 2 ;;
            --force) force=1; shift ;;
            *) _err "Unknown files download option: $1"; return 1 ;;
        esac
    done
    [ -n "$alias" ] || { _err "m365 files download requires ALIAS ITEM_ID [--out PATH]"; return 1; }
    [ -n "$item" ] || { _err "m365 files download requires a drive-item id"; return 1; }
    [ -n "$out" ] || { _err "m365 files download requires --out PATH"; return 1; }
    _m365_require_enabled "$alias" files || return 1
    [ "$force" -eq 1 ] || [ ! -e "$out" ] || { _err "Refusing to overwrite existing file: $out (use --force)"; return 1; }
    [ -d "$(dirname "$out")" ] || { _err "Output directory does not exist: $(dirname "$out")"; return 1; }
    url="$(_m365_files_item_url "$alias" "$item" "$drive")" || return 1
    _m365_get "$alias" "${url}/content" > "$out" || { rm -f "$out"; return 1; }
    _say "Downloaded item ${item} -> ${out}"
}

##- Mail folders and moves. Reads (folders, list) need only mail.enabled; executed moves and folder creation also need mail.write_enabled, which switches the scope to Mail.ReadWrite.
##- Moves target exact Graph message IDs, go through Graph JSON batching (20 requests per call, because every PowerShell-transport call costs about two seconds), and are read back afterwards. There is no delete, and folders that amount to deletion or sending (Deleted Items, Junk, Drafts, Sent, Outbox, and anything under them) are never move targets.
_M365_MAIL_WELL_KNOWN='["inbox","archive","deleteditems","junkemail","drafts","sentitems","outbox","conversationhistory","recoverableitemsdeletions"]'
_M365_MAIL_BLOCKED_TARGETS='["deleteditems","junkemail","drafts","sentitems","outbox","recoverableitemsdeletions"]'
_M365_MAIL_FOLDER_SELECT='id,displayName,parentFolderId,childFolderCount,totalItemCount,unreadItemCount'

_m365_mail_require_write() {
    local alias="$1"
    if ! _m365_account_value "$alias" '(.mail.write_enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Microsoft 365 mail moves are not enabled for alias '$alias'"
        _say "NEXT: set mail.write_enabled to true for '$alias' in $(_m365_accounts_path), then run 'lifeos m365 auth $alias' so the session requests Mail.ReadWrite" >&2
        return 1
    fi
}

_m365_mail_move_cap() {
    _m365_account_value "$1" '.mail.max_moves_per_call // 50' 2>/dev/null || printf '50'
}

# _m365_batch ALIAS REQUESTS_FILE OUT_FILE: REQUESTS_FILE holds a JSON array of {method, url, body?} with URLs relative to the Graph version root. OUT_FILE receives the responses as an array in request order.
_m365_batch() {
    local alias="$1" requests="$2" out="$3" dir total start=0 n=0 chunk
    local files=()
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-batch.XXXXXX")" || return 1
    total="$(jq 'length' "$requests")" || return 1
    while [ "$start" -lt "$total" ]; do
        chunk="$(jq -c --argjson s "$start" '{requests: [.[$s:($s + 20)] | to_entries[] | {id: (($s + .key) | tostring)} + .value + (if .value.body then {headers: {"Content-Type": "application/json"}} else {} end)]}' "$requests")" || return 1
        _m365_write POST "$alias" "$(_m365_graph_base "$alias")/\$batch" "$chunk" > "${dir}/${n}.json" || return 1
        files+=("${dir}/${n}.json")
        n=$((n + 1))
        start=$((start + 20))
    done
    if [ "${#files[@]}" -eq 0 ]; then
        printf '[]\n' > "$out"
    else
        jq -s '[.[].responses[]?] | sort_by(.id | tonumber)' "${files[@]}" > "$out"
    fi
}

# Write the mailbox's folder tree to OUT as a JSON array of folders, each carrying path, depth, wellKnown (or null), and moveTarget.
_m365_mail_folder_tree() {
    local alias="$1" out="$2" dir depth=0
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-folders.XXXXXX")" || return 1
    _m365_get_paginated "$alias" 1000 "${dir}/top.json" "$(_m365_graph_base "$alias")/me/mailFolders" \
        --data-urlencode "\$top=250" \
        --data-urlencode "\$select=${_M365_MAIL_FOLDER_SELECT}" || return 1
    jq '[(.value // [])[] | . + {path: .displayName, depth: 0}]' "${dir}/top.json" > "${dir}/all.json" || return 1
    cp "${dir}/all.json" "${dir}/level.json"
    while jq -e 'any(.[]; (.childFolderCount // 0) > 0)' "${dir}/level.json" >/dev/null; do
        depth=$((depth + 1))
        [ "$depth" -le 10 ] || { _err "Mail folder tree is deeper than 10 levels; refusing to continue"; return 1; }
        jq '[.[] | select((.childFolderCount // 0) > 0)]' "${dir}/level.json" > "${dir}/parents.json" || return 1
        jq --arg select "$_M365_MAIL_FOLDER_SELECT" '[.[] | {method: "GET", url: ("/me/mailFolders/" + (.id | @uri) + "/childFolders?$top=250&$select=" + $select)}]' "${dir}/parents.json" > "${dir}/requests.json" || return 1
        _m365_batch "$alias" "${dir}/requests.json" "${dir}/responses.json" || return 1
        jq -n --slurpfile p "${dir}/parents.json" --slurpfile r "${dir}/responses.json" '
          [range(0; ($p[0] | length)) as $i |
            ($r[0][$i]) as $resp |
            if ($resp.status // 0) != 200 then
              error("Could not list child folders of " + $p[0][$i].path + ": " + (($resp.body.error.message // "HTTP " + (($resp.status // 0) | tostring))))
            else
              ($resp.body.value // [])[] | . + {path: ($p[0][$i].path + "/" + .displayName), depth: ($p[0][$i].depth + 1)}
            end]
        ' > "${dir}/level.json" || return 1
        jq -s '.[0] + .[1]' "${dir}/all.json" "${dir}/level.json" > "${dir}/merged.json" && mv "${dir}/merged.json" "${dir}/all.json"
    done
    jq -n --argjson names "$_M365_MAIL_WELL_KNOWN" '[$names[] | {method: "GET", url: ("/me/mailFolders/" + . + "?$select=id")}]' > "${dir}/wk-requests.json"
    _m365_batch "$alias" "${dir}/wk-requests.json" "${dir}/wk-responses.json" || return 1
    jq --argjson names "$_M365_MAIL_WELL_KNOWN" --argjson blocked "$_M365_MAIL_BLOCKED_TARGETS" --slurpfile wk "${dir}/wk-responses.json" '
      ([range(0; ($names | length)) as $i | select(($wk[0][$i].status // 0) == 200) | {key: $wk[0][$i].body.id, value: $names[$i]}] | from_entries) as $map |
      (sort_by(.depth) | reduce .[] as $f ({out: [], blocked: {}};
        ($map[$f.id] // null) as $name |
        ((($name != null) and (($blocked | index($name)) != null)) or (.blocked[$f.parentFolderId // ""] // false)) as $isBlocked |
        .out += [$f + {wellKnown: $name, moveTarget: ($isBlocked | not)}] |
        if $isBlocked then .blocked[$f.id] = true else . end)) |
      .out | sort_by(.path | ascii_downcase)
    ' "${dir}/all.json" > "$out"
}

# Resolve SPEC against TREE_FILE and print the matching folder as JSON. SPEC may be a well-known name (inbox, archive, ...), an exact folder ID, a full path such as "Inbox/Receipts", or a unique display name. Ambiguity and absence both fail.
_m365_mail_resolve_folder() {
    local tree="$1" spec="$2" result
    result="$(jq --arg s "$spec" '
      ($s | ascii_downcase) as $l |
      ([.[] | select(.wellKnown == $l)]) as $wk |
      ([.[] | select(.id == $s)]) as $byId |
      ([.[] | select((.path | ascii_downcase) == $l)]) as $byPath |
      ([.[] | select((.displayName | ascii_downcase) == $l)]) as $byName |
      if ($wk | length) == 1 then {match: $wk[0]}
      elif ($byId | length) == 1 then {match: $byId[0]}
      elif ($byPath | length) == 1 then {match: $byPath[0]}
      elif ($byName | length) == 1 then {match: $byName[0]}
      elif ($byName | length) > 1 then {ambiguous: [$byName[] | .path]}
      else {missing: true} end
    ' "$tree")" || return 1
    if printf '%s' "$result" | jq -e '.match' >/dev/null; then
        printf '%s' "$result" | jq -c '.match'
    elif printf '%s' "$result" | jq -e '.ambiguous' >/dev/null; then
        _err "Mail folder '$spec' matches more than one folder: $(printf '%s' "$result" | jq -r '.ambiguous | join(", ")'). Pass the full path or the folder ID."
        return 1
    else
        _err "No mail folder matches '$spec'. Run 'lifeos m365 mail folders ALIAS' to see folders, or 'lifeos m365 mail create-folder' to make one."
        return 1
    fi
}

_m365_mail_folders() {
    local alias="${1:-}" json_mode=0 tree
    [ -n "$alias" ] || { _err "m365 mail folders requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 mail folders option: $1"; return 1 ;;
        esac
    done
    _m365_require_enabled "$alias" mail || return 1
    tree="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-folder-tree.XXXXXX")" || return 1
    _m365_mail_folder_tree "$alias" "$tree" || return 1
    if [ "$json_mode" -eq 1 ]; then
        cat "$tree"
    else
        jq -r '.[] |
          ("  " * .depth) + "- " + .displayName +
          " | path: " + .path +
          " | id: " + .id +
          " | total: " + ((.totalItemCount // 0) | tostring) +
          " | unread: " + ((.unreadItemCount // 0) | tostring) +
          (if .wellKnown then " | well-known: " + .wellKnown else "" end) +
          (if .moveTarget then "" else " | move target: no" end)
        ' "$tree"
    fi
}

_m365_mail_list() {
    local alias="${1:-}" folder_spec="" limit=25 json_mode=0 tree folder folder_id data
    [ -n "$alias" ] || { _err "m365 mail list requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --folder) [ -n "${2:-}" ] || { _err "--folder requires NAME, PATH, or ID"; return 1; }; folder_spec="$2"; shift 2 ;;
            --limit) [ -n "${2:-}" ] || { _err "--limit requires N"; return 1; }; limit="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 mail list option: $1"; return 1 ;;
        esac
    done
    [ -n "$folder_spec" ] || { _err "m365 mail list requires --folder"; return 1; }
    case "$limit" in ''|*[!0-9]*) _err "--limit must be a positive integer"; return 1 ;; esac
    [ "$limit" -ge 1 ] && [ "$limit" -le 200 ] || { _err "--limit must be between 1 and 200"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    tree="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-folder-tree.XXXXXX")" || return 1
    _m365_mail_folder_tree "$alias" "$tree" || return 1
    folder="$(_m365_mail_resolve_folder "$tree" "$folder_spec")" || return 1
    folder_id="$(printf '%s' "$folder" | jq -r '.id')"
    data="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-folder-messages.XXXXXX")" || return 1
    _m365_get_paginated "$alias" "$limit" "$data" "$(_m365_graph_base "$alias")/me/mailFolders/$(_m365_uri_encode "$folder_id")/messages" \
        --data-urlencode "\$top=${limit}" \
        --data-urlencode "\$orderby=receivedDateTime desc" \
        --data-urlencode "\$select=id,conversationId,subject,from,receivedDateTime,isRead,hasAttachments,categories" || return 1
    if [ "$json_mode" -eq 1 ]; then
        jq --argjson folder "$folder" '{folder: $folder, value: (.value // [])}' "$data"
    else
        _say "Folder: $(printf '%s' "$folder" | jq -r '.path') ($(printf '%s' "$folder" | jq -r '.totalItemCount // 0') total)"
        jq -r '(.value // [])[] |
          "- " + (.receivedDateTime // "") +
          " | from: " + (.from.emailAddress.name // .from.emailAddress.address // "") +
          " <" + (.from.emailAddress.address // "") + ">" +
          " | " + (.subject // "(no subject)") +
          (if .isRead then "" else " | unread" end) +
          (if ((.categories // []) | length) > 0 then " | categories: " + (.categories | join(", ")) else "" end) +
          "\n  message_id: " + (.id // "")
        ' "$data"
    fi
}

# Shared engine for move, archive, and unarchive. REQUIRED_SOURCE is a folder spec every message must currently sit in, or empty for no source rule.
_m365_mail_move_run() {
    local alias="$1" action="$2" dest_spec="$3" required_source="$4" execute="$5"
    shift 5
    local ids=() id cap tree dir dest dest_id dest_path source source_id count failures ts
    for id in "$@"; do
        case " ${ids[*]:-} " in *" $id "*) continue ;; esac
        ids+=("$id")
    done
    [ "${#ids[@]}" -gt 0 ] || { _err "m365 mail $action requires at least one --message ID or --ids-file"; return 1; }
    cap="$(_m365_mail_move_cap "$alias")"
    [ "${#ids[@]}" -le "$cap" ] || { _err "m365 mail $action accepts at most $cap messages per call (got ${#ids[@]}); split the list"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-move.XXXXXX")" || return 1
    tree="${dir}/tree.json"
    _m365_mail_folder_tree "$alias" "$tree" || return 1
    dest="$(_m365_mail_resolve_folder "$tree" "$dest_spec")" || return 1
    dest_id="$(printf '%s' "$dest" | jq -r '.id')"
    dest_path="$(printf '%s' "$dest" | jq -r '.path')"
    if ! printf '%s' "$dest" | jq -e '.moveTarget' >/dev/null; then
        _err "Refusing to move mail into '$dest_path': Deleted Items, Junk, Drafts, Sent, Outbox, and their subfolders are never move targets"
        return 1
    fi
    source_id=""
    if [ -n "$required_source" ]; then
        source="$(_m365_mail_resolve_folder "$tree" "$required_source")" || return 1
        source_id="$(printf '%s' "$source" | jq -r '.id')"
    fi
    printf '%s\n' "${ids[@]}" | jq -R . | jq -s '[.[] | {method: "GET", url: ("/me/messages/" + (. | @uri) + "?$select=id,subject,from,receivedDateTime,parentFolderId")}]' > "${dir}/get-requests.json"
    _m365_batch "$alias" "${dir}/get-requests.json" "${dir}/get-responses.json" || return 1
    printf '%s\n' "${ids[@]}" | jq -R . | jq -s --slurpfile r "${dir}/get-responses.json" --slurpfile tree "$tree" '
      ($tree[0] | map({key: .id, value: .path}) | from_entries) as $paths |
      [range(0; length) as $i | {requested: .[$i], status: ($r[0][$i].status // 0), message: $r[0][$i].body} |
        . + {folderPath: ($paths[.message.parentFolderId // ""] // "(folder not listed)")}]
    ' > "${dir}/targets.json" || return 1
    if jq -e 'any(.[]; .status != 200)' "${dir}/targets.json" >/dev/null; then
        _err "These message IDs were not found; nothing was moved:"
        jq -r '.[] | select(.status != 200) | "  - " + .requested + " (" + (.message.error.code // ("HTTP " + (.status | tostring))) + ")"' "${dir}/targets.json" >&2
        return 1
    fi
    if [ -n "$source_id" ] && jq -e --arg src "$source_id" 'any(.[]; .message.parentFolderId != $src)' "${dir}/targets.json" >/dev/null; then
        _err "m365 mail $action only moves messages that are currently in '$(printf '%s' "$source" | jq -r '.path')'; nothing was moved. Out of place:"
        jq -r --arg src "$source_id" '.[] | select(.message.parentFolderId != $src) | "  - " + (.message.subject // "(no subject)") + " | in: " + .folderPath + " | " + .requested' "${dir}/targets.json" >&2
        return 1
    fi
    if jq -e --arg dest "$dest_id" 'any(.[]; .message.parentFolderId == $dest)' "${dir}/targets.json" >/dev/null; then
        _err "Some messages are already in '$dest_path'; nothing was moved. Remove them from the list:"
        jq -r --arg dest "$dest_id" '.[] | select(.message.parentFolderId == $dest) | "  - " + (.message.subject // "(no subject)") + " | " + .requested' "${dir}/targets.json" >&2
        return 1
    fi
    count="${#ids[@]}"
    _say "Microsoft 365 mail $action plan:"
    _say "Account: $alias"
    _say "Destination: $dest_path"
    _say "Messages: $count"
    jq -r '.[] | "- " + (.message.receivedDateTime // "") + " | " + (.message.from.emailAddress.address // "") + " | " + (.message.subject // "(no subject)") + " | from folder: " + .folderPath' "${dir}/targets.json"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was moved. Re-run with --execute to move these messages."; return 0; fi
    _m365_mail_require_write "$alias" || return 1
    jq --arg dest "$dest_id" '[.[] | {method: "POST", url: ("/me/messages/" + (.requested | @uri) + "/move"), body: {destinationId: $dest}}]' "${dir}/targets.json" > "${dir}/move-requests.json"
    _m365_batch "$alias" "${dir}/move-requests.json" "${dir}/move-responses.json" || return 1
    # Read back each moved message under its new ID, since a Graph move returns the message with a different ID.
    jq '[.[] | select((.status // 0) == 201 or (.status // 0) == 200) | {method: "GET", url: ("/me/messages/" + (.body.id | @uri) + "?$select=id,parentFolderId")}]' "${dir}/move-responses.json" > "${dir}/readback-requests.json"
    _m365_batch "$alias" "${dir}/readback-requests.json" "${dir}/readback-responses.json" || return 1
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    jq -n --slurpfile t "${dir}/targets.json" --slurpfile m "${dir}/move-responses.json" --slurpfile rb "${dir}/readback-responses.json" --arg dest "$dest_id" '
      ([$rb[0][] | select((.status // 0) == 200) | {key: .body.id, value: .body.parentFolderId}] | from_entries) as $now |
      [range(0; ($t[0] | length)) as $i | $t[0][$i] as $target | $m[0][$i] as $resp |
        (($resp.status // 0) == 201 or ($resp.status // 0) == 200) as $moved |
        {requested: $target.requested, subject: ($target.message.subject // ""), from: ($target.message.from.emailAddress.address // ""), fromFolder: $target.folderPath,
         newId: (if $moved then $resp.body.id else null end),
         verified: ($moved and ($now[$resp.body.id] // "") == $dest),
         error: (if $moved then null else ($resp.body.error.message // ("HTTP " + (($resp.status // 0) | tostring))) end)}]
    ' > "${dir}/results.json" || return 1
    jq -c --arg ts "$ts" --arg alias "$alias" --arg action "$action" --arg dest "$dest_path" '.[] | {ts: $ts, service: "m365", alias: $alias, action: $action, message_id: .requested, new_message_id: .newId, destination: $dest, from_folder: .fromFolder, sender: .from, subject: .subject, verified: .verified, error: .error}' "${dir}/results.json" | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    jq -r '.[] | if .verified then "- moved: " + .subject + "\n  new message_id: " + .newId elif .newId then "- MOVED BUT NOT CONFIRMED in destination: " + .subject + "\n  new message_id: " + .newId else "- FAILED: " + .subject + " | " + .error + "\n  message_id: " + .requested end' "${dir}/results.json"
    failures="$(jq '[.[] | select(.verified | not)] | length' "${dir}/results.json")"
    if [ "$failures" -gt 0 ]; then
        _err "$failures of $count messages were not confirmed in '$dest_path'"
        return 1
    fi
    _say "Moved $count messages to $dest_path (confirmed by readback). Moved messages have new IDs, shown above."
}

_m365_mail_move_args() {
    # Parses the shared move options into _MOVE_IDS, _MOVE_FOLDER, and _MOVE_EXECUTE.
    local command="$1"
    shift
    _MOVE_IDS=()
    _MOVE_FOLDER=""
    _MOVE_EXECUTE=0
    local line
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --message) [ -n "${2:-}" ] || { _err "--message requires ID"; return 1; }; _MOVE_IDS+=("$2"); shift 2 ;;
            --ids-file)
                [ -n "${2:-}" ] || { _err "--ids-file requires FILE"; return 1; }
                _read_ids_file "$2" > /dev/null || return 1
                while IFS= read -r line; do [ -n "$line" ] && _MOVE_IDS+=("$line"); done <<EOF
$(_read_ids_file "$2")
EOF
                shift 2
                ;;
            --folder)
                [ "$command" = "move" ] || { _err "m365 mail $command does not take --folder"; return 1; }
                [ -n "${2:-}" ] || { _err "--folder requires NAME, PATH, or ID"; return 1; }
                _MOVE_FOLDER="$2"; shift 2
                ;;
            --execute) _MOVE_EXECUTE=1; shift ;;
            --dry-run) _MOVE_EXECUTE=0; shift ;;
            *) _err "Unknown m365 mail $command option: $1"; return 1 ;;
        esac
    done
}

_m365_mail_move() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "m365 mail move requires ALIAS"; return 1; }
    shift || true
    _m365_mail_move_args move "$@" || return 1
    [ -n "$_MOVE_FOLDER" ] || { _err "m365 mail move requires --folder"; return 1; }
    _m365_mail_move_run "$alias" move "$_MOVE_FOLDER" "" "$_MOVE_EXECUTE" ${_MOVE_IDS[@]+"${_MOVE_IDS[@]}"}
}

_m365_mail_archive() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "m365 mail archive requires ALIAS"; return 1; }
    shift || true
    _m365_mail_move_args archive "$@" || return 1
    _m365_mail_move_run "$alias" archive archive inbox "$_MOVE_EXECUTE" ${_MOVE_IDS[@]+"${_MOVE_IDS[@]}"}
}

_m365_mail_unarchive() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "m365 mail unarchive requires ALIAS"; return 1; }
    shift || true
    _m365_mail_move_args unarchive "$@" || return 1
    _m365_mail_move_run "$alias" unarchive inbox archive "$_MOVE_EXECUTE" ${_MOVE_IDS[@]+"${_MOVE_IDS[@]}"}
}

# List a message's attachments, or save its file attachments into an existing directory. Read-only (Mail.Read); refuses to overwrite unless --force.
_m365_mail_attachments() {
    local alias="${1:-}" message_id="" save_dir="" force=0 base list dir id name out
    [ -n "$alias" ] || { _err "m365 mail attachments requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --message) [ -n "${2:-}" ] || { _err "--message requires ID"; return 1; }; message_id="$2"; shift 2 ;;
            --save) [ -n "${2:-}" ] || { _err "--save requires DIR"; return 1; }; save_dir="$2"; shift 2 ;;
            --force) force=1; shift ;;
            *) _err "Unknown m365 mail attachments option: $1"; return 1 ;;
        esac
    done
    [ -n "$message_id" ] || { _err "m365 mail attachments requires --message ID"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    base="$(_m365_graph_base "$alias")/me/messages/$(_m365_uri_encode "$message_id")/attachments"
    list="$(_m365_get "$alias" "$base" --data-urlencode "\$select=id,name,contentType,size,isInline")" || return 1
    if [ -z "$save_dir" ]; then
        printf '%s' "$list" | jq -r '(.value // [])[] | "- " + .name + " | " + (.contentType // "") + " | " + ((.size // 0) | tostring) + " bytes" + (if .isInline then " | inline" else "" end) + " | type: " + ((."@odata.type" // "") | sub("#microsoft.graph."; ""))'
        return 0
    fi
    [ -d "$save_dir" ] || { _err "Save directory does not exist: $save_dir"; return 1; }
    if printf '%s' "$list" | jq -e '(.value // []) | map(.name) | (length != (unique | length))' >/dev/null; then
        _err "Two attachments share a file name; refusing to guess which to keep"; return 1
    fi
    # Check every destination before writing any, so a collision stops the whole save.
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        case "$name" in */*|..*) _err "Refusing unsafe attachment file name: $name"; return 1 ;; esac
        [ "$force" -eq 1 ] || [ ! -e "${save_dir}/${name}" ] || { _err "Refusing to overwrite existing file: ${save_dir}/${name} (use --force)"; return 1; }
    done <<EOF2
$(printf '%s' "$list" | jq -r '(.value // [])[] | select((."@odata.type" // "") == "#microsoft.graph.fileAttachment" and (.isInline | not)) | .name')
EOF2
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-attachments.XXXXXX")" || return 1
    for id in $(printf '%s' "$list" | jq -r '(.value // [])[] | select((."@odata.type" // "") == "#microsoft.graph.fileAttachment" and (.isInline | not)) | .id'); do
        _m365_get "$alias" "${base}/$(_m365_uri_encode "$id")" > "${dir}/att.json" || return 1
        name="$(jq -r '.name' "${dir}/att.json")"
        out="${save_dir}/${name}"
        jq -r '.contentBytes' "${dir}/att.json" | "$LIFEOS_PY" -c 'import base64, sys; sys.stdout.buffer.write(base64.b64decode(sys.stdin.read()))' > "$out" || { rm -f "$out"; return 1; }
        _say "Saved: $out ($(wc -c < "$out" | tr -d ' ') bytes)"
    done
    rm -rf "$dir"
    printf '%s' "$list" | jq -r '(.value // [])[] | select((."@odata.type" // "") != "#microsoft.graph.fileAttachment" or .isInline) | "Skipped (inline or not a file): " + .name'
}

##- Outlook categories: the Microsoft 365 counterpart of Gmail's user labels, used for subject-matter tags during triage. A category name is free text on the message; it does not need to exist in the mailbox's master category list (it then shows without a color). Same gates as moves: dry run by default, mail.write_enabled to execute, exact IDs, per-call cap, batched, read back, and audit-logged.
_m365_mail_category_run() {
    local alias="$1" action="$2" category="$3" execute="$4"
    shift 4
    local ids=() id cap dir count failures ts
    for id in "$@"; do
        case " ${ids[*]:-} " in *" $id "*) continue ;; esac
        ids+=("$id")
    done
    [ -n "$category" ] || { _err "m365 mail $action requires --category NAME"; return 1; }
    case "$category" in *,*) _err "Category names may not contain commas"; return 1 ;; esac
    [ "${#ids[@]}" -gt 0 ] || { _err "m365 mail $action requires at least one --message ID or --ids-file"; return 1; }
    cap="$(_m365_mail_move_cap "$alias")"
    [ "${#ids[@]}" -le "$cap" ] || { _err "m365 mail $action accepts at most $cap messages per call (got ${#ids[@]}); split the list"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-category.XXXXXX")" || return 1
    printf '%s\n' "${ids[@]}" | jq -R . | jq -s '[.[] | {method: "GET", url: ("/me/messages/" + (. | @uri) + "?$select=id,subject,from,receivedDateTime,categories")}]' > "${dir}/get-requests.json"
    _m365_batch "$alias" "${dir}/get-requests.json" "${dir}/get-responses.json" || return 1
    printf '%s\n' "${ids[@]}" | jq -R . | jq -s --slurpfile r "${dir}/get-responses.json" '[range(0; length) as $i | {requested: .[$i], status: ($r[0][$i].status // 0), message: $r[0][$i].body}]' > "${dir}/targets.json" || return 1
    if jq -e 'any(.[]; .status != 200)' "${dir}/targets.json" >/dev/null; then
        _err "These message IDs were not found; nothing was changed:"
        jq -r '.[] | select(.status != 200) | "  - " + .requested + " (" + (.message.error.code // ("HTTP " + (.status | tostring))) + ")"' "${dir}/targets.json" >&2
        return 1
    fi
    # Compute each message's new category list; categories are compared case-insensitively, as Outlook does.
    jq --arg c "$category" --arg action "$action" '[.[] |
        (.message.categories // []) as $now |
        (($now | map(ascii_downcase)) | index($c | ascii_downcase)) as $has |
        . + {current: $now,
             wanted: (if $action == "categorize" then (if $has then $now else $now + [$c] end) else [$now[] | select(ascii_downcase != ($c | ascii_downcase))] end),
             noop: (if $action == "categorize" then ($has != null) else ($has == null) end)}]' "${dir}/targets.json" > "${dir}/plan.json" || return 1
    if jq -e 'any(.[]; .noop)' "${dir}/plan.json" >/dev/null; then
        _err "Some messages already $( [ "$action" = categorize ] && echo have || echo lack ) category '$category'; nothing was changed. Remove them from the list:"
        jq -r '.[] | select(.noop) | "  - " + (.message.subject // "(no subject)") + " | " + .requested' "${dir}/plan.json" >&2
        return 1
    fi
    count="${#ids[@]}"
    _say "Microsoft 365 mail $action plan:"
    _say "Account: $alias"
    _say "Category: $category ($( [ "$action" = categorize ] && echo add || echo remove ))"
    _say "Messages: $count"
    jq -r '.[] | "- " + (.message.receivedDateTime // "") + " | " + (.message.from.emailAddress.address // "") + " | " + (.message.subject // "(no subject)") + " | categories now: " + ((.current | join(", ")) // "") ' "${dir}/plan.json"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was changed. Re-run with --execute to apply."; return 0; fi
    _m365_mail_require_write "$alias" || return 1
    jq '[.[] | {method: "PATCH", url: ("/me/messages/" + (.requested | @uri)), body: {categories: .wanted}}]' "${dir}/plan.json" > "${dir}/patch-requests.json"
    _m365_batch "$alias" "${dir}/patch-requests.json" "${dir}/patch-responses.json" || return 1
    jq '[.[] | {method: "GET", url: ("/me/messages/" + (.requested | @uri) + "?$select=id,categories")}]' "${dir}/plan.json" > "${dir}/readback-requests.json"
    _m365_batch "$alias" "${dir}/readback-requests.json" "${dir}/readback-responses.json" || return 1
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    jq -n --slurpfile p "${dir}/plan.json" --slurpfile w "${dir}/patch-responses.json" --slurpfile rb "${dir}/readback-responses.json" '
      [range(0; ($p[0] | length)) as $i | $p[0][$i] as $t |
        ((($w[0][$i].status // 0) / 100 | floor) == 2) as $patched |
        ($rb[0][$i].body.categories // null) as $after |
        {requested: $t.requested, subject: ($t.message.subject // ""), from: ($t.message.from.emailAddress.address // ""),
         verified: ($patched and $after != null and (($after | map(ascii_downcase) | sort) == ($t.wanted | map(ascii_downcase) | sort))),
         error: (if $patched then null else ($w[0][$i].body.error.message // ("HTTP " + (($w[0][$i].status // 0) | tostring))) end)}]
    ' > "${dir}/results.json" || return 1
    jq -c --arg ts "$ts" --arg alias "$alias" --arg action "$action" --arg category "$category" '.[] | {ts: $ts, service: "m365", alias: $alias, action: $action, category: $category, message_id: .requested, sender: .from, subject: .subject, verified: .verified, error: .error}' "${dir}/results.json" | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    jq -r '.[] | (if .verified then "- done: " else "- NOT CONFIRMED: " end) + .subject + (if .error then " | " + .error else "" end)' "${dir}/results.json"
    failures="$(jq '[.[] | select(.verified | not)] | length' "${dir}/results.json")"
    if [ "$failures" -gt 0 ]; then
        _err "$failures of $count messages were not confirmed by readback"
        return 1
    fi
    _say "Applied to $count messages (confirmed by readback). Message IDs are unchanged."
}

_m365_mail_category_cmd() {
    local action="$1" alias="${2:-}" category="" line
    local ids=()
    [ -n "$alias" ] || { _err "m365 mail $action requires ALIAS"; return 1; }
    shift 2 || true
    local execute=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --category) [ -n "${2:-}" ] || { _err "--category requires NAME"; return 1; }; category="$2"; shift 2 ;;
            --message) [ -n "${2:-}" ] || { _err "--message requires ID"; return 1; }; ids+=("$2"); shift 2 ;;
            --ids-file)
                [ -n "${2:-}" ] || { _err "--ids-file requires FILE"; return 1; }
                _read_ids_file "$2" > /dev/null || return 1
                while IFS= read -r line; do [ -n "$line" ] && ids+=("$line"); done <<EOF
$(_read_ids_file "$2")
EOF
                shift 2
                ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 mail $action option: $1"; return 1 ;;
        esac
    done
    _m365_mail_category_run "$alias" "$action" "$category" "$execute" ${ids[@]+"${ids[@]}"}
}

# Junk review: list Junk Email and rescue false positives to the Inbox. Junk is never part of mail sync, and Junk stays refused as a move destination.
_m365_mail_junk() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "m365 mail junk requires ALIAS"; return 1; }
    shift || true
    _m365_mail_list "$alias" --folder junkemail "$@"
}

_m365_mail_not_junk() {
    local alias="${1:-}"
    [ -n "$alias" ] || { _err "m365 mail not-junk requires ALIAS"; return 1; }
    shift || true
    _m365_mail_move_args not-junk "$@" || return 1
    _m365_mail_move_run "$alias" not-junk inbox junkemail "$_MOVE_EXECUTE" ${_MOVE_IDS[@]+"${_MOVE_IDS[@]}"}
}

_m365_mail_create_folder() {
    local alias="${1:-}" name="" parent_spec="" execute=0 tree parent parent_id parent_path url created new_path ts
    [ -n "$alias" ] || { _err "m365 mail create-folder requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name) [ -n "${2:-}" ] || { _err "--name requires TEXT"; return 1; }; name="$2"; shift 2 ;;
            --parent) [ -n "${2:-}" ] || { _err "--parent requires NAME, PATH, or ID"; return 1; }; parent_spec="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 mail create-folder option: $1"; return 1 ;;
        esac
    done
    [ -n "$name" ] || { _err "m365 mail create-folder requires --name"; return 1; }
    case "$name" in */*) _err "Folder names may not contain '/'; use --parent to nest"; return 1 ;; esac
    _m365_require_enabled "$alias" mail || return 1
    tree="$(mktemp "${TMPDIR:-/tmp}/lifeos-m365-folder-tree.XXXXXX")" || return 1
    _m365_mail_folder_tree "$alias" "$tree" || return 1
    parent_id=""
    parent_path=""
    if [ -n "$parent_spec" ]; then
        parent="$(_m365_mail_resolve_folder "$tree" "$parent_spec")" || return 1
        parent_id="$(printf '%s' "$parent" | jq -r '.id')"
        parent_path="$(printf '%s' "$parent" | jq -r '.path')"
        printf '%s' "$parent" | jq -e '.moveTarget' >/dev/null || { _err "Refusing to create a folder under '$parent_path'"; return 1; }
        new_path="${parent_path}/${name}"
    else
        new_path="$name"
    fi
    if jq -e --arg p "$new_path" 'any(.[]; (.path | ascii_downcase) == ($p | ascii_downcase))' "$tree" >/dev/null; then
        _err "A mail folder already exists at '$new_path'"
        return 1
    fi
    _say "Microsoft 365 mail folder create plan:"
    _say "Account: $alias"
    _say "New folder: $new_path"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no folder was created. Re-run with --execute to create it."; return 0; fi
    _m365_mail_require_write "$alias" || return 1
    if [ -n "$parent_id" ]; then
        url="$(_m365_graph_base "$alias")/me/mailFolders/$(_m365_uri_encode "$parent_id")/childFolders"
    else
        url="$(_m365_graph_base "$alias")/me/mailFolders"
    fi
    created="$(_m365_write POST "$alias" "$url" "$(jq -cn --arg name "$name" '{displayName: $name}')")" || return 1
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '%s' "$created" | jq -c --arg ts "$ts" --arg alias "$alias" --arg path "$new_path" '{ts: $ts, service: "m365", alias: $alias, action: "create-folder", folder_id: .id, folder: $path}' | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    _say "Created folder: $new_path | id: $(printf '%s' "$created" | jq -r '.id // "(unknown)"')"
}

_m365_dispatch() {
    case "${1:-}" in
        accounts) shift; _m365_accounts_list "$@" ;;
        auth) shift; _m365_auth "$@" ;;
        profile) shift; _m365_profile "$@" ;;
        mail)
            case "${2:-}" in
                sync) shift 2; _m365_mail_sync "$@" ;;
                folders) shift 2; _m365_mail_folders "$@" ;;
                list) shift 2; _m365_mail_list "$@" ;;
                move) shift 2; _m365_mail_move "$@" ;;
                archive) shift 2; _m365_mail_archive "$@" ;;
                unarchive) shift 2; _m365_mail_unarchive "$@" ;;
                create-folder) shift 2; _m365_mail_create_folder "$@" ;;
                junk) shift 2; _m365_mail_junk "$@" ;;
                attachments) shift 2; _m365_mail_attachments "$@" ;;
                categorize) shift 2; _m365_mail_category_cmd categorize "$@" ;;
                uncategorize) shift 2; _m365_mail_category_cmd uncategorize "$@" ;;
                not-junk) shift 2; _m365_mail_not_junk "$@" ;;
                *) _err "Unknown m365 mail command: ${2:-}"; return 1 ;;
            esac
            ;;
        calendar)
            case "${2:-}" in
                list-calendars) shift 2; _m365_calendar_list "$@" ;;
                find) shift 2; _m365_calendar_find "$@" ;;
                sync) shift 2; _m365_calendar_sync "$@" ;;
                create-event) shift 2; _m365_calendar_create "$@" ;;
                update-event) shift 2; _m365_calendar_update "$@" ;;
                *) _err "Unknown m365 calendar command: ${2:-}"; return 1 ;;
            esac
            ;;
        files)
            case "${2:-}" in
                search) shift 2; _m365_files_search "$@" ;;
                resolve-link) shift 2; _m365_files_resolve_link "$@" ;;
                meta) shift 2; _m365_files_meta "$@" ;;
                download) shift 2; _m365_files_download "$@" ;;
                *) _err "Unknown m365 files command: ${2:-}"; return 1 ;;
            esac
            ;;
        contacts)
            case "${2:-}" in
                list) shift 2; _m365_contacts_list "$@" ;;
                find) shift 2; _m365_contacts_find "$@" ;;
                sync) shift 2; _m365_contacts_sync "$@" ;;
                create) shift 2; _m365_contacts_create "$@" ;;
                update) shift 2; _m365_contacts_update "$@" ;;
                *) _err "Unknown m365 contacts command: ${2:-}"; return 1 ;;
            esac
            ;;
        *) _err "Unknown m365 command: ${1:-}"; return 1 ;;
    esac
}
