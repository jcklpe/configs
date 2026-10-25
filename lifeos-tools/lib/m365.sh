#!/usr/bin/env bash
##- LifeOS Microsoft 365: delegated auth plus bounded mail, calendar, and Outlook contact reads and gated writes, including opt-in mail moves between folders (never delete). Planner lives in m365-planner.sh.
##- Sourced by lifeos.sh after common.sh and google.sh; uses the shared people alias map for deterministic attendee resolution.

source "${LIB_DIR}/../../agent-hands/skills/authorize-microsoft/scripts/client.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-calendar/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-microsoft-files/scripts/operations.sh"
source "${LIB_DIR}/../../agent-hands/skills/use-outlook-contacts/scripts/operations.sh"

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

# Provider mechanics are shared; the hooks below retain existing local configuration and SDK context behavior.
_m365_python() { shift; "$LIFEOS_PY" "$@"; }
_m365_expected_account() { _m365_account_value "$1" '.expected_account' 2>/dev/null || printf ''; }

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
            for service in mail calendar contacts planner; do
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

_m365_calendar_timezone() {
    local alias="$1"
    _m365_account_value "$alias" '.calendar.timezone // "Central Standard Time"' 2>/dev/null || printf 'Central Standard Time'
}

_m365_calendar_window() {
    "$LIFEOS_PY" -c 'from datetime import datetime, timedelta, timezone; import sys; now=datetime.now(timezone.utc); start=(now-timedelta(days=int(sys.argv[1]))).replace(hour=0,minute=0,second=0,microsecond=0); end=(now+timedelta(days=int(sys.argv[2])+1)).replace(hour=0,minute=0,second=0,microsecond=0); print(start.isoformat().replace("+00:00","Z")); print(end.isoformat().replace("+00:00","Z"))' "$LIFEOS_DAYS_BACK" "$LIFEOS_DAYS_AHEAD"
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
    _m365_calendar_export "$alias" --output "$out" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    dir="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dir" "$refreshed" ;; esac
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

_m365_contacts_sync() {
    local alias="${1:-}" qa=0 custom_out="" out refreshed dir
    [ -n "$alias" ] || { _err "m365 contacts sync requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --qa) qa=1; shift ;; --output) [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }; custom_out="$2"; shift 2 ;; *) _err "Unknown m365 contacts sync option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" contacts || return 1
    if [ -n "$custom_out" ]; then out="$custom_out"; elif [ "$qa" -eq 1 ]; then out="$(_m365_output "$alias" contacts 1)"; else _vault_ready || return 1; _ensure_sources_dir || return 1; out="$(_m365_output "$alias" contacts 0)"; fi
    _ensure_parent_dir "$out" || return 1
    _m365_contacts_export "$alias" --output "$out" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    dir="$(dirname "$out")"
    case "$out" in */m365/*.md) _m365_write_index "$dir" "$refreshed" ;; esac
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

_M365_MAIL_LIST_SELECT='id,conversationId,subject,from,receivedDateTime,isRead,hasAttachments,categories,webLink,parentFolderId'
_M365_MAIL_READ_SELECT='id,conversationId,subject,from,toRecipients,ccRecipients,bccRecipients,replyTo,receivedDateTime,sentDateTime,body,bodyPreview,hasAttachments,isRead,isDraft,importance,webLink,internetMessageHeaders,categories,parentFolderId'

# List the newest messages in one folder, or search with KQL (Graph $search) in one folder or across the mailbox. A mailbox-wide search leaves out Junk Email; pass --folder junkemail to search it.
_m365_mail_list() {
    local alias="${1:-}" folder_spec="" search="" limit=25 json_mode=0 dir tree folder="null" folder_id url query junk_path
    [ -n "$alias" ] || { _err "m365 mail list requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --folder) [ -n "${2:-}" ] || { _err "--folder requires NAME, PATH, or ID"; return 1; }; folder_spec="$2"; shift 2 ;;
            --search) [ -n "${2:-}" ] || { _err "--search requires a KQL query"; return 1; }; search="$2"; shift 2 ;;
            --limit) [ -n "${2:-}" ] || { _err "--limit requires N"; return 1; }; limit="$2"; shift 2 ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 mail list option: $1"; return 1 ;;
        esac
    done
    [ -n "$folder_spec" ] || [ -n "$search" ] || { _err "m365 mail list requires --folder, --search, or both"; return 1; }
    case "$limit" in ''|*[!0-9]*) _err "--limit must be a positive integer"; return 1 ;; esac
    [ "$limit" -ge 1 ] && [ "$limit" -le 200 ] || { _err "--limit must be between 1 and 200"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-mail-list.XXXXXX")" || return 1
    tree="${dir}/tree.json"
    _m365_mail_folder_tree "$alias" "$tree" || return 1
    if [ -n "$folder_spec" ]; then
        folder="$(_m365_mail_resolve_folder "$tree" "$folder_spec")" || return 1
        folder_id="$(printf '%s' "$folder" | jq -r '.id')"
        url="$(_m365_graph_base "$alias")/me/mailFolders/$(_m365_uri_encode "$folder_id")/messages"
    else
        url="$(_m365_graph_base "$alias")/me/messages"
    fi
    if [ -n "$search" ]; then
        # Graph wants the whole query in double quotes; quotes inside it are escaped. $search returns newest first and cannot be combined with $orderby.
        query="\"$(printf '%s' "$search" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
        _m365_get_paginated "$alias" "$limit" "${dir}/messages.json" "$url" \
            --data-urlencode "\$search=${query}" \
            --data-urlencode "\$top=${limit}" \
            --data-urlencode "\$select=${_M365_MAIL_LIST_SELECT}" || return 1
    else
        _m365_get_paginated "$alias" "$limit" "${dir}/messages.json" "$url" \
            --data-urlencode "\$top=${limit}" \
            --data-urlencode "\$orderby=receivedDateTime desc" \
            --data-urlencode "\$select=${_M365_MAIL_LIST_SELECT}" || return 1
    fi
    # Name each message's folder by its path; a mailbox-wide search drops Junk Email and its subfolders.
    junk_path="$(jq -r '.[] | select(.wellKnown == "junkemail") | .path' "$tree")"
    jq --slurpfile tree "$tree" --argjson folder "$folder" --arg search "$search" --arg junk "$junk_path" '
      ($tree[0] | map({key: .id, value: .path}) | from_entries) as $paths |
      [(.value // [])[] | . + {folderPath: ($paths[.parentFolderId // ""] // "(folder not listed)")}] as $all |
      (if $folder == null and $junk != "" then [$all[] | select(.folderPath != $junk and (.folderPath | startswith($junk + "/") | not))] else $all end) as $kept |
      {folder: $folder, search: (if $search == "" then null else $search end), excludedJunk: (($all | length) - ($kept | length)), value: $kept}
    ' "${dir}/messages.json" > "${dir}/result.json" || return 1
    if [ "$json_mode" -eq 1 ]; then
        cat "${dir}/result.json"
    else
        jq -r '
          (.search != null) as $searching |
          (if .search == null then "Folder: " + .folder.path + " (" + ((.folder.totalItemCount // 0) | tostring) + " total)"
           else "Search: " + .search + " | " + (if .folder == null then "all folders except Junk Email" else "folder: " + .folder.path end) + " | " + ((.value | length) | tostring) + " found" +
             (if .excludedJunk > 0 then " (" + (.excludedJunk | tostring) + " more in Junk Email left out)" else "" end) end),
          (.value[] |
            "- " + (.receivedDateTime // "") +
            " | from: " + (.from.emailAddress.name // .from.emailAddress.address // "") +
            " <" + (.from.emailAddress.address // "") + ">" +
            " | " + (.subject // "(no subject)") +
            (if .isRead then "" else " | unread" end) +
            (if ((.categories // []) | length) > 0 then " | categories: " + (.categories | join(", ")) else "" end) +
            (if $searching then " | folder: " + .folderPath else "" end) +
            "\n  message_id: " + (.id // "") +
            (if .webLink then "\n  outlook: " + .webLink else "" end))
        ' "${dir}/result.json"
    fi
    rm -rf "$dir"
}

# Read one message by exact ID from any folder: headers, recipients, text body, attachment names, folder, and web link. Read-only; the body is capped at mail.body_character_limit unless --full.
_m365_mail_read() {
    local alias="${1:-}" message_id="" json_mode=0 full=0 dir base folder_id body_limit
    [ -n "$alias" ] || { _err "m365 mail read requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --message) [ -n "${2:-}" ] || { _err "--message requires ID"; return 1; }; message_id="$2"; shift 2 ;;
            --full) full=1; shift ;;
            --json) json_mode=1; shift ;;
            *) _err "Unknown m365 mail read option: $1"; return 1 ;;
        esac
    done
    [ -n "$message_id" ] || { _err "m365 mail read requires --message ID"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-mail-read.XXXXXX")" || return 1
    base="$(_m365_graph_base "$alias")"
    _m365_get "$alias" "${base}/me/messages/$(_m365_uri_encode "$message_id")" \
        --data-urlencode "\$select=${_M365_MAIL_READ_SELECT}" \
        --data-urlencode "\$expand=attachments(\$select=id,name,contentType,size,isInline)" \
        -H 'Prefer: outlook.body-content-type="text"' > "${dir}/message.json" || return 1
    # The folder name is a convenience; a failed lookup leaves it out rather than failing the read.
    folder_id="$(jq -r '.parentFolderId // empty' "${dir}/message.json")"
    if [ -z "$folder_id" ] || ! _m365_get "$alias" "${base}/me/mailFolders/$(_m365_uri_encode "$folder_id")" --data-urlencode "\$select=id,displayName" > "${dir}/folder.json" 2>/dev/null; then
        printf '{}\n' > "${dir}/folder.json"
    fi
    jq --slurpfile f "${dir}/folder.json" '. + {folder: ($f[0].displayName // null)}' "${dir}/message.json" > "${dir}/read.json" || return 1
    if [ "$json_mode" -eq 1 ]; then
        cat "${dir}/read.json"
    else
        body_limit=0
        [ "$full" -eq 1 ] || body_limit="$(_m365_account_value "$alias" '.mail.body_character_limit // 8000')" || body_limit=8000
        _m365_render_helper message --body-limit "$body_limit" --input "${dir}/read.json" || return 1
    fi
    rm -rf "$dir"
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
                read) shift 2; _m365_mail_read "$@" ;;
                move) shift 2; _m365_mail_move "$@" ;;
                archive) shift 2; _m365_mail_archive "$@" ;;
                unarchive) shift 2; _m365_mail_unarchive "$@" ;;
                create-folder) shift 2; _m365_mail_create_folder "$@" ;;
                junk) shift 2; _m365_mail_junk "$@" ;;
                attachments) shift 2; _m365_mail_attachments "$@" ;;
                categorize) shift 2; _m365_mail_category_cmd categorize "$@" ;;
                uncategorize) shift 2; _m365_mail_category_cmd uncategorize "$@" ;;
                not-junk) shift 2; _m365_mail_not_junk "$@" ;;
                rules) shift 2; _m365_mail_rules "$@" ;;
                create-rule) shift 2; _m365_mail_create_rule "$@" ;;
                delete-rule) shift 2; _m365_mail_delete_rule "$@" ;;
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
                upload) shift 2; _m365_files_upload "$@" ;;
                replace) shift 2; _m365_files_replace "$@" ;;
                create-folder) shift 2; _m365_files_create_folder "$@" ;;
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
        planner) shift; _m365_planner_dispatch "$@" ;;
        excel) shift; _m365_excel_dispatch "$@" ;;
        *) _err "Unknown m365 command: ${1:-}"; return 1 ;;
    esac
}
