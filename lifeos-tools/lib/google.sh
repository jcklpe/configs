#!/usr/bin/env bash
##- lifeos Google ecosystem: Calendar, Gmail, Drive, Sheets, and People, plus the shared Google OAuth and account-alias layer they all authenticate through. Includes the Google-local _urlencode helper.
##- Sourced by lifeos.sh; depends on lib/common.sh and the bootstrap vars. Large and cohesive; could be split into per-service modules later if that ever pays off.

_calendar_helper() {
    python3 "${LIB_DIR}/google-calendar-auth.py" "$@"
}

_calendar_render_helper() {
    python3 "${LIB_DIR}/google-calendar-render.py" "$@"
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
    python3 "${LIB_DIR}/google-people.py" "$@"
}

_calendar_write_helper() {
    python3 "${LIB_DIR}/google-calendar-write.py" "$@"
}

_urlencode() {
    jq -rn --arg value "$1" '$value | @uri'
}

_google_accounts_path() {
    if _var_is_set GOOGLE_ACCOUNTS_PATH; then
        _path_value GOOGLE_ACCOUNTS_PATH
    else
        printf '%s/google-accounts.json\n' "$SCRIPT_DIR"
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
        *) printf '%s/%s\n' "$SCRIPT_DIR" "$value" ;;
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
        _say "NEXT: cp ${SCRIPT_DIR}/google-accounts.example.json $config"
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
          "https://www.googleapis.com/auth/gmail.readonly"
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
    python3 "${LIB_DIR}/google-oauth.py" "$@"
}

_google_auth() {
    local alias="${1:-}" credentials_path token_path no_browser=""
    local scopes=() scope

    [ -n "$alias" ] || { _err "google auth requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-browser) no_browser="--no-browser"; shift ;;
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
        printf '%s/gmail-qa/%s.md\n' "$SCRIPT_DIR" "$alias"
    else
        printf '%s/%s.md\n' "$(_gmail_sources_dir)" "$alias"
    fi
}

_gmail_render_helper() {
    python3 "${LIB_DIR}/google-gmail-render.py" "$@"
}

_gmail_sync_alias() {
    local alias="$1"
    local out="$2"
    local query max_results body_limit email_address refreshed
    local list_file msg_dir messages_file message_id message_file count

    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    query="$(_gmail_query "$alias")"
    max_results="$(_gmail_max_results "$alias")"
    body_limit="$(_gmail_body_limit "$alias")"
    email_address="$(_google_account_email "$alias")"
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    _ensure_parent_dir "$out" || return 1
    list_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-list.XXXXXX")" || return 1
    msg_dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-gmail-messages.XXXXXX")" || return 1
    messages_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-render.XXXXXX")" || return 1

    _say "Syncing Gmail: ${alias}" >&2
    _google_get_url "$alias" "https://gmail.googleapis.com/gmail/v1/users/me/messages" \
        --data-urlencode "q=${query}" \
        --data-urlencode "maxResults=${max_results}" > "$list_file" || return 1

    count=0
    for message_id in $(jq -r '.messages[]?.id' "$list_file"); do
        message_file="${msg_dir}/${count}.json"
        _google_get_url "$alias" "https://gmail.googleapis.com/gmail/v1/users/me/messages/${message_id}" \
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
    local all=0 qa=0 custom_out="" alias aliases="" out dir refreshed

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
            *) _err "Unknown gmail sync option: $1"; return 1 ;;
        esac
    done

    if [ "$all" -eq 1 ]; then
        [ -z "$custom_out" ] || { _err "gmail sync --all does not support --output"; return 1; }
        aliases="$(_google_enabled_aliases gmail)" || return 1
        [ -n "$aliases" ] || { _err "No Gmail-enabled Google aliases configured"; return 1; }
        if [ "$qa" -eq 1 ]; then
            dir="${SCRIPT_DIR}/gmail-qa"
        else
            _vault_ready || return 1
            _ensure_sources_dir || return 1
            dir="$(_gmail_sources_dir)"
        fi
        [ -d "$dir" ] || mkdir -p "$dir"
        for alias in $aliases; do
            _gmail_sync_alias "$alias" "${dir}/${alias}.md" || return 1
        done
        refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        _gmail_write_index "$dir" "$refreshed" $aliases
        _say "Updated ${dir}/index.md"
        return 0
    fi

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    elif [ "$qa" -eq 1 ]; then
        out="$(_gmail_output_for_alias "$alias" 1)"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_gmail_output_for_alias "$alias" 0)"
    fi
    _gmail_sync_alias "$alias" "$out"
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
    python3 -c 'import sys
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
            python3 "${LIB_DIR}/google-sheets-render.py" "$alias" "$file_id" "$sheet_meta_file" "$values_file"
            ;;
        *)
            _warn "Drive read supports Google Docs and Google Sheets for now. Showing metadata only."
            _drive_meta_human < "$meta_file"
            ;;
    esac
}

_drive_import_source_mime() {
    local source="$1"
    case "$source" in
        *.html|*.htm) printf 'text/html' ;;
        *.txt|*.md|*.markdown) printf 'text/plain' ;;
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
    _say "Account: $alias"
    _say "Source: $source_file"
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

    metadata_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-import-meta.XXXXXX.json")" || return 1
    result_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-import-result.XXXXXX.json")" || return 1
    if [ -n "$folder" ]; then
        jq -n --arg name "$title" --arg parent "$folder" \
            '{name: $name, mimeType: "application/vnd.google-apps.document", parents: [$parent]}' > "$metadata_file" || return 1
    else
        jq -n --arg name "$title" \
            '{name: $name, mimeType: "application/vnd.google-apps.document"}' > "$metadata_file" || return 1
    fi

    mime="$(_drive_import_source_mime "$source_file")"
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
        printf '%s/people-aliases.json\n' "$SCRIPT_DIR"
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
        _say "NEXT: cp ${SCRIPT_DIR}/people-aliases.example.json $path"
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

# Default time zone for timed events: explicit override wins, else the target
# calendar's own time zone, else the system zone.
_calendar_default_tz() {
    local calendar_id="$1" encoded tz
    encoded="$(_urlencode "$calendar_id")" || return 1
    tz="$(_calendar_get "/calendars/${encoded}" --data-urlencode "fields=timeZone" 2>/dev/null | jq -r '.timeZone // empty')"
    if [ -n "$tz" ]; then
        printf '%s' "$tz"
        return 0
    fi
    if [ -f /etc/timezone ]; then
        _trim "$(cat /etc/timezone)"
        return 0
    fi
    printf 'UTC'
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

_calendar_window() {
    _calendar_helper date-window "$LIFEOS_DAYS_BACK" "$LIFEOS_DAYS_AHEAD"
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
    local render_args=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${SCRIPT_DIR}/calendar-qa.md"
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

    tmp_out="$(mktemp "${out}.XXXXXX")" || return 1
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

        _calendar_get "/calendars/${encoded_id}/events" \
            --data-urlencode "singleEvents=true" \
            --data-urlencode "orderBy=startTime" \
            --data-urlencode "showDeleted=false" \
            --data-urlencode "timeMin=${time_min}" \
            --data-urlencode "timeMax=${time_max}" \
            --data-urlencode "maxResults=2500" \
            --data-urlencode "fields=items(id,status,summary,description,location,htmlLink,hangoutLink,conferenceData(entryPoints(entryPointType,label,uri)),start,end)" > "$events_file" || return 1

        render_args+=( "$calendar_file" "$events_file" )
    done

    if [ "${#render_args[@]}" -eq 0 ]; then
        _warn "No Google Calendar IDs were configured."
    else
        _calendar_render_events "${render_args[@]}" >> "$tmp_out" || return 1
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


