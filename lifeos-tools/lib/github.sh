#!/usr/bin/env bash
##- Legacy aggregate export routing; portable capabilities live in Agent Hands.
GITHUB_AUTH_DIR="$(cd "${LIB_DIR}/../../agent-hands/skills/authorize-github" && pwd)" || return 1
. "${GITHUB_AUTH_DIR}/scripts/client.sh"
for github_domain in issues pull-requests discussions projects; do
    . "${GITHUB_AUTH_DIR}/../use-github-${github_domain}/scripts/operations.sh"
done
GITHUB_USE_DIR="${GITHUB_AUTH_DIR}/../use-github-issues"

_github_sync_repo() {
    local entry="$1" dest_root="$2"
    local alias owner repo slug dest want_issues want_prs want_discussions

    alias="$(printf '%s' "$entry" | jq -r '.alias')"
    owner="$(printf '%s' "$entry" | jq -r '.owner')"
    repo="$(printf '%s' "$entry" | jq -r '.repo')"
    want_issues="$(printf '%s' "$entry" | jq -r 'if .issues == null then true else .issues end')"
    want_prs="$(printf '%s' "$entry" | jq -r '.prs // false')"
    want_discussions="$(printf '%s' "$entry" | jq -r '.discussions // false')"
    slug="$owner-$repo"
    dest="$dest_root/$slug"

    _github_say "Syncing GitHub: $owner/$repo -> $dest" >&2
    mkdir -p "$dest" || return 1

    [ "$want_issues" = "true" ] && { _github_export_items "$owner/$repo" issue "$dest" || return 1; }
    [ "$want_prs" = "true" ] && { _github_export_items "$owner/$repo" pr "$dest" || return 1; }
    [ "$want_discussions" = "true" ] && { _github_export_discussions "$owner/$repo" "$dest" || return 1; }
    _github_export_projects "$alias" "$dest" || return 1

    _github_say "Updated $dest"
    return 0
}

_github_sync() {
    local custom_out="" only_alias="" dest entry aliases a status=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output)
                [ -n "${2:-}" ] || { _github_error "--output requires DIR"; return 1; }
                custom_out="$2"; shift 2 ;;
            --all) shift ;;
            -*) _github_error "Unknown github sync option: $1"; return 1 ;;
            *) only_alias="$1"; shift ;;
        esac
    done

    [ -n "$custom_out" ] || { _github_error 'github sync requires --output DIRECTORY'; return 1; }
    _github_ready || return 1
    _github_config_ready || return 1
    dest="$custom_out"
    mkdir -p "$dest" || return 1

    if [ -n "$only_alias" ]; then
        entry="$(_github_repo_entry "$only_alias")" || return 1
        _github_sync_repo "$entry" "$dest" || status=1
    else
        aliases="$(jq -r '.repos[].alias' "$(_github_repos_config)")"
        for a in $aliases; do
            entry="$(_github_repo_entry "$a")" || { status=1; continue; }
            _github_sync_repo "$entry" "$dest" || status=1
        done
    fi
    return "$status"
}
