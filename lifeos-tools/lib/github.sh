#!/usr/bin/env bash
##- lifeos GitHub feature: sync issues, pull requests, discussions, and project boards for configured repos.
##- Sourced by lifeos.sh; depends on lib/common.sh and the bootstrap vars.
##- Reads through the `gh` CLI, so auth is whatever `gh auth status` reports. No token is stored here.

_github_repos_config() {
    printf '%s/github-repos.json\n' "$SECRETS_DIR"
}

_github_ready() {
    local cfg
    cfg="$(_github_repos_config)"
    command -v gh >/dev/null 2>&1 || { _err "gh CLI is required for GitHub sync"; return 1; }
    command -v jq >/dev/null 2>&1 || { _err "jq is required for GitHub sync"; return 1; }
    [ -f "$cfg" ] || { _err "Missing repo config: $cfg (copy github-repos.example.json)"; return 1; }
    gh auth status >/dev/null 2>&1 || { _err "gh is not authenticated. Run: gh auth login"; return 1; }
    return 0
}

_github_render() {
    "$LIFEOS_PY" "${LIB_DIR}/github-render.py" "$@"
}

_github_list_repos() {
    _github_ready || return 1
    jq -r '.repos[] | "\(.alias) | \(.owner)/\(.repo) | issues:\(.issues // true) prs:\(.prs // false) discussions:\(.discussions // false) projects:\((.projects // []) | length)"' "$(_github_repos_config)"
}

##- Look up one repo entry by alias. Prints compact JSON, or fails loudly.
_github_repo_entry() {
    local alias="$1" entry
    entry="$(jq -c --arg a "$alias" '.repos[] | select(.alias == $a)' "$(_github_repos_config)")" || return 1
    [ -n "$entry" ] || { _err "No repo configured with alias: $alias"; return 1; }
    printf '%s\n' "$entry"
}

##- Sync one repo into DEST/<alias>/.
_github_sync_repo() {
    local entry="$1" dest_root="$2"
    local alias owner repo slug dest want_issues want_prs want_discussions

    alias="$(printf '%s' "$entry" | jq -r '.alias')"
    owner="$(printf '%s' "$entry" | jq -r '.owner')"
    repo="$(printf '%s' "$entry" | jq -r '.repo')"
    want_issues="$(printf '%s' "$entry" | jq -r '.issues // true')"
    want_prs="$(printf '%s' "$entry" | jq -r '.prs // false')"
    want_discussions="$(printf '%s' "$entry" | jq -r '.discussions // false')"
    slug="$owner-$repo"
    dest="$dest_root/$slug"

    _say "Syncing GitHub: $owner/$repo -> $dest" >&2
    mkdir -p "$dest" || return 1

    [ "$want_issues" = "true" ] && { _github_sync_items "$owner" "$repo" issue "$dest" || return 1; }
    [ "$want_prs" = "true" ] && { _github_sync_items "$owner" "$repo" pr "$dest" || return 1; }
    [ "$want_discussions" = "true" ] && { _github_sync_discussions "$owner" "$repo" "$dest" || return 1; }
    _github_sync_projects "$entry" "$owner" "$dest" || return 1

    _say "Updated $dest"
    return 0
}

##- Issues and PRs share a shape, so they share a path. KIND is `issue` or `pr`.
_github_sync_items() {
    local owner="$1" repo="$2" kind="$3" dest="$4"
    local index_name detail_dir list_json numbers n item_json

    if [ "$kind" = "pr" ]; then
        index_name="pull-requests.md"; detail_dir="pull-requests"
    else
        index_name="issues.md"; detail_dir="issues"
    fi

    list_json="$(gh "$kind" list --repo "$owner/$repo" --state open --limit 300 \
        --json number,title,labels,assignees,updatedAt,createdAt,body 2>/dev/null)" || {
        _warn "Could not list ${kind}s for $owner/$repo (feature may be disabled)"; return 0; }

    # An empty index is snapshot noise; skip the file entirely and clear any stale copy.
    if [ "$(printf '%s' "$list_json" | jq 'length')" -eq 0 ]; then
        rm -f "$dest/$index_name"
        rm -rf "$dest/$detail_dir"
        _say "  ${index_name%.md}: 0 (skipped)" >&2
        return 0
    fi

    printf '{"items":%s}' "$list_json" | _github_render issue-index \
        --owner "$owner" --repo "$repo" --kind "$kind" --detail-dir "$detail_dir" \
        > "$dest/$index_name" || return 1

    # Detail files carry full body + comment threads. Rebuild the directory each
    # time so closed items do not linger as stale files.
    rm -rf "$dest/$detail_dir"
    mkdir -p "$dest/$detail_dir" || return 1
    numbers="$(printf '%s' "$list_json" | jq -r '.[].number')"
    for n in $numbers; do
        item_json="$(gh "$kind" view "$n" --repo "$owner/$repo" \
            --json number,title,state,body,author,assignees,labels,createdAt,updatedAt,url,comments 2>/dev/null)" || continue
        printf '%s' "$item_json" | _github_render item-detail \
            --owner "$owner" --repo "$repo" --kind "$kind" > "$dest/$detail_dir/$n.md" || return 1
    done
    _say "  ${index_name%.md}: $(printf '%s' "$numbers" | grep -c . | tr -d ' ')" >&2
}

##- Discussions are GraphQL-only; `gh issue`/REST cannot see them.
_github_sync_discussions() {
    local owner="$1" repo="$2" dest="$3" nodes
    nodes="$(gh api graphql -f owner="$owner" -f repo="$repo" -f query='
      query($owner:String!, $repo:String!) {
        repository(owner:$owner, name:$repo) {
          discussions(first:100, orderBy:{field:UPDATED_AT, direction:DESC}) {
            nodes {
              number title url body updatedAt isAnswered
              author { login }
              category { name }
              comments { totalCount }
            }
          }
        }
      }' --jq '.data.repository.discussions.nodes' 2>/dev/null)" || {
        _warn "Could not read discussions for $owner/$repo (may be disabled)"; return 0; }

    [ -n "$nodes" ] && [ "$nodes" != "null" ] || { _warn "No discussions for $owner/$repo"; return 0; }

    printf '%s' "$nodes" \
        | jq '{items: [.[] | {number,title,url,body,updatedAt,isAnswered,author,category, commentCount: .comments.totalCount}]}' \
        | _github_render discussions --owner "$owner" --repo "$repo" > "$dest/discussions.md" || return 1
    _say "  discussions: $(printf '%s' "$nodes" | jq 'length')" >&2
}

##- Projects v2 boards. Read-only: board *automation* is org-side GitHub Actions and is not touched here.
_github_sync_projects() {
    local entry="$1" default_owner="$2" dest="$3"
    local count i number name proj_owner items

    count="$(printf '%s' "$entry" | jq '(.projects // []) | length')"
    [ "$count" -gt 0 ] 2>/dev/null || return 0
    proj_owner="$(printf '%s' "$entry" | jq -r --arg d "$default_owner" '.project_owner // $d')"

    i=0
    while [ "$i" -lt "$count" ]; do
        number="$(printf '%s' "$entry" | jq -r --argjson i "$i" '.projects[$i].number')"
        name="$(printf '%s' "$entry" | jq -r --argjson i "$i" '.projects[$i].name // "project-\(.projects[$i].number)"')"
        items="$(gh project item-list "$number" --owner "$proj_owner" --format json --limit 500 2>/dev/null)" || {
            _warn "Could not read project #$number for $proj_owner"; i=$((i + 1)); continue; }
        printf '%s' "$items" | jq '{items: (.items // [])}' | _github_render board \
            --project-number "$number" --project-name "$name" > "$dest/board-$name.md" || return 1
        _say "  board-$name: $(printf '%s' "$items" | jq '(.items // []) | length')" >&2
        i=$((i + 1))
    done
}

_github_sync() {
    local custom_out="" only_alias="" dest entry aliases a status=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) custom_out="${QA_DIR}/github-qa"; shift ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires DIR"; return 1; }
                custom_out="$2"; shift 2 ;;
            --all) shift ;;
            -*) _err "Unknown github sync option: $1"; return 1 ;;
            *) only_alias="$1"; shift ;;
        esac
    done

    _github_ready || return 1

    if [ -n "$custom_out" ]; then
        dest="$custom_out"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        dest="$(_sources_dir)/github"
    fi
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
