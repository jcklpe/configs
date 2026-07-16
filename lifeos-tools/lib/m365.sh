#!/usr/bin/env bash
##- LifeOS Microsoft 365: delegated auth plus bounded mail, calendar, and Outlook contact reads and gated writes.
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
      " | calendar: " + (((.calendar.enabled // false) == true) | tostring) +
      " | contacts: " + (((.contacts.enabled // false) == true) | tostring)
    ' "$(_m365_accounts_path)"
}

_m365_scopes() {
    local alias="$1"
    _m365_account_exists "$alias" || return 1
    printf 'User.Read\n'
    _m365_account_value "$alias" '(.mail.enabled // false) == true' 2>/dev/null | grep -qx true && printf 'Mail.Read\n'
    _m365_account_value "$alias" '(.calendar.enabled // false) == true' 2>/dev/null | grep -qx true && printf 'Calendars.ReadWrite\n'
    _m365_account_value "$alias" '(.contacts.enabled // false) == true' 2>/dev/null | grep -qx true && printf 'Contacts.ReadWrite\n'
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
    local dir="$1" refreshed alias service file
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
    tmp="$(mktemp "${out}.XXXXXX")" || return 1
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
        --data-urlencode "\$select=id,conversationId,subject,from,toRecipients,ccRecipients,receivedDateTime,body,bodyPreview,hasAttachments,isRead,importance,webLink" \
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
    timezone="$(_m365_calendar_timezone "$alias")"
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
            --data-urlencode "\$select=id,subject,body,bodyPreview,start,end,isAllDay,isCancelled,isOnlineMeeting,location,organizer,attendees,webLink,type,seriesMasterId" \
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
    tmp="$(mktemp "${out}.XXXXXX")" || return 1
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
    tmp="$(mktemp "${out}.XXXXXX")" || return 1
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

_m365_dispatch() {
    case "${1:-}" in
        accounts) shift; _m365_accounts_list "$@" ;;
        auth) shift; _m365_auth "$@" ;;
        profile) shift; _m365_profile "$@" ;;
        mail)
            case "${2:-}" in
                sync) shift 2; _m365_mail_sync "$@" ;;
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
