#!/usr/bin/env bash
##- LifeOS Microsoft 365 file writes: upload a new file, replace an existing file's contents, and create a folder in OneDrive or SharePoint, as the signed-in user.
##- No delete, move, rename, or sharing change. OneNote notebooks are refused. Dry-run by default; needs files.write_enabled. Decision record: docs/decisions/0010-lifeos-m365-file-writes.md.
##- Sourced by lifeos.sh after m365.sh; reuses _m365_files_item_url and the Graph transport.

# Graph's simple upload accepts up to 250 MB; larger files need an upload session, which this surface does not implement.
_M365_FILES_MAX_BYTES=262144000

_m365_files_require_write() {
    local alias="$1"
    if ! _m365_account_value "$alias" '(.files.write_enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Microsoft 365 file writes are not enabled for alias '$alias'"
        _say "NEXT: set files.write_enabled to true for '$alias' in $(_m365_accounts_path)" >&2
        return 1
    fi
}

_m365_files_local_size() {
    wc -c < "$1" | tr -d ' '
}

_m365_files_check_local() {
    local file="$1" size
    [ -f "$file" ] || { _err "Local file does not exist: $file"; return 1; }
    size="$(_m365_files_local_size "$file")"
    [ "$size" -le "$_M365_FILES_MAX_BYTES" ] || { _err "File is $size bytes; uploads are limited to 250 MB"; return 1; }
    case "$file" in *.one|*.onetoc2) _err "Refusing to upload OneNote files; OneNote notebooks cannot be safely written as files"; return 1 ;; esac
}

# Refuse anything that is a OneNote notebook or section, or not a plain file.
_m365_files_refuse_special() {
    local item="$1" what="$2"
    if printf '%s' "$item" | jq -e '.package.type == "oneNote" or ((.name // "") | test("\\.(one|onetoc2)$"; "i"))' >/dev/null; then
        _err "Refusing to $what a OneNote notebook or section; OneNote cannot be safely written as files"
        return 1
    fi
}

_m365_files_audit() {
    jq -nc --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg alias "$1" --arg action "$2" --argjson item "$3" --argjson verified "$4" \
        '{ts: $ts, service: "m365-files", alias: $alias, action: $action, item_id: $item.id, name: $item.name, drive_id: ($item.parentReference.driveId // null), size: ($item.size // null), url: ($item.webUrl // null), verified: $verified}' | _mail_audit_append || _warn "Could not append to the audit log: $(_mail_audit_log_path)"
}

_m365_files_upload() {
    local alias="${1:-}" file="${2:-}" parent="" drive="" name="" execute=0 parent_url parent_item size url created readback ok
    [ -n "$alias" ] && [ -n "$file" ] || { _err "m365 files upload requires ALIAS LOCAL_FILE --parent FOLDER_ITEM_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --parent) [ -n "${2:-}" ] || { _err "--parent requires a folder item id or 'root'"; return 1; }; parent="$2"; shift 2 ;;
            --drive) [ -n "${2:-}" ] || { _err "--drive requires DRIVE_ID"; return 1; }; drive="$2"; shift 2 ;;
            --name) [ -n "${2:-}" ] || { _err "--name requires TEXT"; return 1; }; name="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown files upload option: $1"; return 1 ;;
        esac
    done
    [ -n "$parent" ] || { _err "files upload requires --parent FOLDER_ITEM_ID (or root)"; return 1; }
    _m365_require_enabled "$alias" files || return 1
    _m365_files_check_local "$file" || return 1
    [ -n "$name" ] || name="$(basename "$file")"
    case "$name" in */*|*\\*) _err "--name must be a file name, not a path"; return 1 ;; esac
    size="$(_m365_files_local_size "$file")"
    parent_url="$(_m365_files_item_url "$alias" "$parent" "$drive")" || return 1
    parent_item="$(_m365_get "$alias" "$parent_url" --data-urlencode '$select=id,name,folder,package,webUrl,parentReference')" || return 1
    printf '%s' "$parent_item" | jq -e '.folder != null' >/dev/null || { _err "--parent is not a folder: $(printf '%s' "$parent_item" | jq -r '.name')"; return 1; }
    _m365_files_refuse_special "$parent_item" "upload into" || return 1
    if _m365_get "$alias" "${parent_url}:/$(_m365_uri_encode "$name")" --data-urlencode '$select=id' >/dev/null 2>&1; then
        _err "A file named '$name' already exists in that folder; use 'files replace' to change it"
        return 1
    fi
    _say "Microsoft 365 file upload plan:"
    _say "Account: $alias"
    _say "Local file: $file ($size bytes)"
    _say "Destination: $(printf '%s' "$parent_item" | jq -r '(.parentReference.path // "") + "/" + (.name // "")')/$name"
    _say "Folder URL: $(printf '%s' "$parent_item" | jq -r '.webUrl // ""')"
    _say "Note: anyone with access to that folder will see the new file."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was uploaded. Re-run with --execute to upload."; return 0; fi
    _m365_files_require_write "$alias" || return 1
    url="${parent_url}:/$(_m365_uri_encode "$name"):/content?@microsoft.graph.conflictBehavior=fail"
    created="$(_m365_http PUT "$alias" "$url" "" --upload-file "$file")" || return 1
    readback="$(_m365_get "$alias" "$(_m365_files_item_url "$alias" "$(printf '%s' "$created" | jq -r '.id')" "$(printf '%s' "$created" | jq -r '.parentReference.driveId // empty')")" --data-urlencode '$select=id,name,size,webUrl,parentReference')" || return 1
    ok="$(jq -n --argjson got "$readback" --arg name "$name" --argjson size "$size" '($got.name == $name) and ($got.size == $size)')"
    _m365_files_audit "$alias" upload "$readback" "$ok"
    [ "$ok" = true ] || { _err "Uploaded, but readback did not match the local file's name and size"; return 1; }
    _say "Uploaded (confirmed by readback): $(printf '%s' "$readback" | jq -r '.name + " | item_id: " + .id + " | " + (.webUrl // "")')"
}

_m365_files_replace() {
    local alias="${1:-}" item_id="${2:-}" file="" drive="" execute=0 url current size readback ok
    [ -n "$alias" ] && [ -n "$item_id" ] || { _err "m365 files replace requires ALIAS ITEM_ID --file LOCAL_FILE"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --file) [ -n "${2:-}" ] || { _err "--file requires LOCAL_FILE"; return 1; }; file="$2"; shift 2 ;;
            --drive) [ -n "${2:-}" ] || { _err "--drive requires DRIVE_ID"; return 1; }; drive="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown files replace option: $1"; return 1 ;;
        esac
    done
    [ -n "$file" ] || { _err "files replace requires --file LOCAL_FILE"; return 1; }
    _m365_require_enabled "$alias" files || return 1
    _m365_files_check_local "$file" || return 1
    size="$(_m365_files_local_size "$file")"
    url="$(_m365_files_item_url "$alias" "$item_id" "$drive")" || return 1
    current="$(_m365_get "$alias" "$url" --data-urlencode '$select=id,name,size,eTag,file,folder,package,webUrl,parentReference,lastModifiedDateTime,lastModifiedBy')" || return 1
    printf '%s' "$current" | jq -e '.file != null' >/dev/null || { _err "Item is not a file: $(printf '%s' "$current" | jq -r '.name')"; return 1; }
    _m365_files_refuse_special "$current" "replace" || return 1
    _say "Microsoft 365 file replace plan:"
    _say "Account: $alias"
    printf '%s' "$current" | jq -r '"Remote file: " + ((.parentReference.path // "") + "/" + .name), "Now: " + ((.size // 0) | tostring) + " bytes, modified " + (.lastModifiedDateTime // "?") + " by " + (.lastModifiedBy.user.displayName // "?"), "URL: " + (.webUrl // "")'
    _say "New contents: $file ($size bytes)"
    _say "OneDrive and SharePoint keep version history, so the current version stays restorable. Anyone with access sees the change."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: nothing was replaced. Re-run with --execute to replace the contents."; return 0; fi
    _m365_files_require_write "$alias" || return 1
    # If-Match carries the eTag read in this run, so a file someone changed in the meantime is refused rather than overwritten.
    _m365_http PUT "$alias" "${url}/content" "" --upload-file "$file" -H "If-Match: $(printf '%s' "$current" | jq -r '.eTag')" >/dev/null || { _err "Replace refused or failed; the file may have changed since it was read. Re-run to see its current state."; return 1; }
    readback="$(_m365_get "$alias" "$url" --data-urlencode '$select=id,name,size,webUrl,parentReference')" || return 1
    ok="$(jq -n --argjson got "$readback" --argjson size "$size" '$got.size == $size')"
    _m365_files_audit "$alias" replace "$readback" "$ok"
    [ "$ok" = true ] || { _err "Replaced, but readback size does not match the local file"; return 1; }
    _say "Replaced (confirmed by readback): $(printf '%s' "$readback" | jq -r '.name + " | " + (.size | tostring) + " bytes | " + (.webUrl // "")')"
}

_m365_files_create_folder() {
    local alias="${1:-}" parent="" drive="" name="" execute=0 parent_url parent_item created readback ok
    [ -n "$alias" ] || { _err "m365 files create-folder requires ALIAS --parent FOLDER_ITEM_ID --name NAME"; return 1; }
    shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --parent) [ -n "${2:-}" ] || { _err "--parent requires a folder item id or 'root'"; return 1; }; parent="$2"; shift 2 ;;
            --drive) [ -n "${2:-}" ] || { _err "--drive requires DRIVE_ID"; return 1; }; drive="$2"; shift 2 ;;
            --name) [ -n "${2:-}" ] || { _err "--name requires TEXT"; return 1; }; name="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown files create-folder option: $1"; return 1 ;;
        esac
    done
    [ -n "$parent" ] && [ -n "$name" ] || { _err "files create-folder requires --parent and --name"; return 1; }
    case "$name" in */*|*\\*) _err "--name must be a folder name, not a path"; return 1 ;; esac
    _m365_require_enabled "$alias" files || return 1
    parent_url="$(_m365_files_item_url "$alias" "$parent" "$drive")" || return 1
    parent_item="$(_m365_get "$alias" "$parent_url" --data-urlencode '$select=id,name,folder,package,webUrl,parentReference')" || return 1
    printf '%s' "$parent_item" | jq -e '.folder != null' >/dev/null || { _err "--parent is not a folder"; return 1; }
    _m365_files_refuse_special "$parent_item" "create a folder in" || return 1
    _say "Microsoft 365 create-folder plan:"
    _say "Account: $alias"
    _say "New folder: $(printf '%s' "$parent_item" | jq -r '(.parentReference.path // "") + "/" + (.name // "")')/$name"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no folder was created. Re-run with --execute to create it."; return 0; fi
    _m365_files_require_write "$alias" || return 1
    created="$(_m365_write POST "$alias" "${parent_url}/children" "$(jq -nc --arg n "$name" '{name: $n, folder: {}, "@microsoft.graph.conflictBehavior": "fail"}')")" || return 1
    readback="$(_m365_get "$alias" "$(_m365_files_item_url "$alias" "$(printf '%s' "$created" | jq -r '.id')" "$(printf '%s' "$created" | jq -r '.parentReference.driveId // empty')")" --data-urlencode '$select=id,name,folder,webUrl,parentReference')" || return 1
    ok="$(jq -n --argjson got "$readback" --arg name "$name" '($got.name == $name) and ($got.folder != null)')"
    _m365_files_audit "$alias" create-folder "$readback" "$ok"
    [ "$ok" = true ] || { _err "Created, but readback did not match"; return 1; }
    _say "Created folder (confirmed by readback): $(printf '%s' "$readback" | jq -r '.name + " | item_id: " + .id + " | " + (.webUrl // "")')"
}
