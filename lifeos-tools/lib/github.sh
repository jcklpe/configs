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
##- Carries the full thread — comments and their nested replies — not just a preview,
##- because a discussion IS the content. An issue's substance is its title and body;
##- a discussion's substance is the argument in the replies.
_github_sync_discussions() {
    local owner="$1" repo="$2" dest="$3" nodes numbers n gh_err
    gh_err="$(mktemp)"
    nodes="$(gh api graphql -f owner="$owner" -f repo="$repo" -f query='
      query($owner:String!, $repo:String!) {
        repository(owner:$owner, name:$repo) {
          discussions(first:50, orderBy:{field:UPDATED_AT, direction:DESC}) {
            nodes {
              number title url body createdAt updatedAt isAnswered
              author { login }
              category { name }
              comments(first:50) {
                totalCount
                nodes {
                  body createdAt isAnswer
                  author { login }
                  replies(first:25) {
                    totalCount
                    nodes { body createdAt author { login } }
                  }
                }
              }
            }
          }
        }
      }' --jq ".data.repository.discussions.nodes" 2>"$gh_err")" || {
        _warn "Could not read discussions for $owner/$repo: $(tr '\n' ' ' < "$gh_err")"
        rm -f "$gh_err"; return 0; }
    rm -f "$gh_err"

    [ -n "$nodes" ] && [ "$nodes" != "null" ] && [ "$(printf '%s' "$nodes" | jq 'length')" -gt 0 ] || {
        rm -f "$dest/discussions.md"; rm -rf "$dest/discussions"
        _say "  discussions: 0 (skipped)" >&2; return 0; }

    printf '%s' "$nodes" \
        | jq '{items: [.[] | {number,title,url,body,createdAt,updatedAt,isAnswered,author,category,
                              commentCount: .comments.totalCount,
                              replyCount: ([.comments.nodes[]?.replies.totalCount] | add // 0)}]}' \
        | _github_render discussions --owner "$owner" --repo "$repo" > "$dest/discussions.md" || return 1

    rm -rf "$dest/discussions"
    mkdir -p "$dest/discussions" || return 1
    numbers="$(printf '%s' "$nodes" | jq -r '.[].number')"
    for n in $numbers; do
        printf '%s' "$nodes" | jq --argjson n "$n" 'map(select(.number == $n))[0]' \
            | _github_render discussion-detail --owner "$owner" --repo "$repo" \
            > "$dest/discussions/$n.md" || return 1
    done
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

##- Resolve a repo argument: either a configured alias or a literal owner/repo.
##- Aliases are preferred because they carry the rest of the config, but a literal
##- slug has to work for one-off issues in repos the vault does not track.
_github_resolve_repo() {
    local arg="$1" entry
    case "$arg" in
        */*) printf '%s\n' "$arg"; return 0 ;;
    esac
    entry="$(_github_repo_entry "$arg")" || return 1
    printf '%s/%s\n' "$(printf '%s' "$entry" | jq -r '.owner')" "$(printf '%s' "$entry" | jq -r '.repo')"
}

##- Create one issue. Dry-run by default, per lifeos write policy and decision 0006:
##- a write that cannot be shown before it happens should not happen.
_github_create_issue() {
    local repo_arg="" repo="" title="" body="" body_file="" execute=0 assign_me=0
    local labels="" assignees="" cmd_out label assignee

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --repo) [ -n "${2:-}" ] || { _err "--repo requires ALIAS or OWNER/REPO"; return 1; }; repo_arg="$2"; shift 2 ;;
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; shift 2 ;;
            --body) [ -n "${2:-}" ] || { _err "--body requires TEXT"; return 1; }; body="$2"; shift 2 ;;
            --body-file) [ -n "${2:-}" ] || { _err "--body-file requires FILE"; return 1; }; body_file="$2"; shift 2 ;;
            --label) [ -n "${2:-}" ] || { _err "--label requires NAME"; return 1; }; labels="$labels$2\n"; shift 2 ;;
            --assignee) [ -n "${2:-}" ] || { _err "--assignee requires LOGIN"; return 1; }; assignees="$assignees$2\n"; shift 2 ;;
            --assign-me) assign_me=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown create-issue option: $1"; return 1 ;;
        esac
    done

    _github_ready || return 1
    [ -n "$title" ] || { _err "--title is required"; return 1; }
    [ -n "$repo_arg" ] || { _err "--repo is required (alias or OWNER/REPO)"; return 1; }
    [ -z "$body_file" ] || [ -f "$body_file" ] || { _err "Body file does not exist: $body_file"; return 1; }
    repo="$(_github_resolve_repo "$repo_arg")" || return 1

    if [ "$assign_me" -eq 1 ]; then
        if [ "$execute" -eq 1 ]; then
            assignees="$assignees$(gh api user --jq .login)\n"
        else
            assignees="${assignees}@me\n"
        fi
    fi

    _say "GitHub issue create plan:"
    _say "Repo: $repo"
    _say "Title: $title"
    if [ -n "$body_file" ]; then
        _say "Body file: $body_file"
        _say "--- body preview ---"
        sed -n '1,240p' "$body_file"
        _say "--- end body preview ---"
    elif [ -n "$body" ]; then
        _say "Body:"
        printf '%s\n' "$body"
    else
        _say "Body: <empty>"
    fi
    _say "Labels: $(printf '%b' "$labels" | grep -c . | tr -d ' ') -> $(printf '%b' "$labels" | paste -sd, - | sed 's/,$//')"
    _say "Assignees: $(printf '%b' "$assignees" | grep -c . | tr -d ' ') -> $(printf '%b' "$assignees" | paste -sd, - | sed 's/,$//')"

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no GitHub issue was created. Re-run with --execute after approval."
        return 0
    fi

    gh repo view "$repo" --json nameWithOwner --jq .nameWithOwner >/dev/null || {
        _err "Cannot reach repo: $repo"; return 1; }

    set -- gh issue create --repo "$repo" --title "$title"
    if [ -n "$body_file" ]; then set -- "$@" --body-file "$body_file"; else set -- "$@" --body "$body"; fi
    while IFS= read -r label; do [ -n "$label" ] && set -- "$@" --label "$label"; done <<EOF_LABELS
$(printf '%b' "$labels")
EOF_LABELS
    while IFS= read -r assignee; do [ -n "$assignee" ] && set -- "$@" --assignee "$assignee"; done <<EOF_ASSIGNEES
$(printf '%b' "$assignees")
EOF_ASSIGNEES

    cmd_out="$("$@")" || { _err "Issue creation failed"; return 1; }
    _say "Created issue: $cmd_out"
}

##- Move a card between columns on a Projects v2 board. Dry-run by default.
##- This is a legitimate input to board automation, not a fight with it: in a repo
##- wired like open-austin/org or the HAI mono-repo, moving a card to Done triggers
##- native Auto-close, and moving one out of a terminal column is picked up by a
##- reconciler that reopens the issue. Expect lag on the reopen direction —
##- reconcilers are cron-driven and GitHub delays scheduled runs, so a sync run
##- immediately after a move can show the board and the issue disagreeing.
_github_move_card() {
    local repo_arg="" issue="" status="" execute=0
    local owner repo entry proj_owner proj_number proj_id field_id option_id
    local issue_node item_id current current_name

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --repo) repo_arg="${2:-}"; shift 2 ;;
            --issue) issue="${2:-}"; shift 2 ;;
            --status) status="${2:-}"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown move-card option: $1"; return 1 ;;
        esac
    done

    _github_ready || return 1
    [ -n "$repo_arg" ] || { _err "--repo is required (a configured alias)"; return 1; }
    [ -n "$issue" ] || { _err "--issue NUMBER is required"; return 1; }
    [ -n "$status" ] || { _err "--status NAME is required (e.g. Done, Backlog)"; return 1; }

    entry="$(_github_repo_entry "$repo_arg")" || return 1
    owner="$(printf '%s' "$entry" | jq -r '.owner')"
    repo="$(printf '%s' "$entry" | jq -r '.repo')"
    [ "$(printf '%s' "$entry" | jq '(.projects // []) | length')" -gt 0 ] || {
        _err "No project board configured for alias: $repo_arg"; return 1; }
    proj_number="$(printf '%s' "$entry" | jq -r '.projects[0].number')"
    proj_owner="$(printf '%s' "$entry" | jq -r --arg d "$owner" '.project_owner // $d')"

    # Resolve project node id, the Status field, and the target option in one query.
    local meta
    meta="$(gh api graphql -f owner="$proj_owner" -F number="$proj_number" -f query='
      query($owner:String!, $number:Int!) {
        organization(login:$owner) {
          projectV2(number:$number) {
            id
            field(name:"Status") {
              ... on ProjectV2SingleSelectField { id options { id name } }
            }
          }
        }
      }' 2>/dev/null)" || { _err "Could not read project #$proj_number for $proj_owner"; return 1; }

    proj_id="$(printf '%s' "$meta" | jq -r '.data.organization.projectV2.id')"
    field_id="$(printf '%s' "$meta" | jq -r '.data.organization.projectV2.field.id')"
    option_id="$(printf '%s' "$meta" | jq -r --arg s "$status" '.data.organization.projectV2.field.options[] | select(.name == $s) | .id')"

    if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
        _err "No such status column: $status"
        _say "Available: $(printf '%s' "$meta" | jq -r '[.data.organization.projectV2.field.options[].name] | join(", ")')"
        return 1
    fi

    issue_node="$(gh issue view "$issue" --repo "$owner/$repo" --json id --jq .id 2>/dev/null)" || {
        _err "Could not read issue #$issue in $owner/$repo"; return 1; }

    item_id="$(gh api graphql --paginate -f project="$proj_id" -f query='
      query($project: ID!, $endCursor: String) {
        node(id: $project) { ... on ProjectV2 {
          items(first:100, after:$endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes { id content { ... on Issue { id } }
                    fieldValueByName(name:"Status") { ... on ProjectV2ItemFieldSingleSelectValue { optionId name } } }
        } } }' --jq ".data.node.items.nodes[] | select(.content.id == \"$issue_node\")" 2>/dev/null)"

    [ -n "$item_id" ] || { _err "Issue #$issue is not on the board"; return 1; }
    current="$(printf '%s' "$item_id" | jq -r '.fieldValueByName.optionId // ""')"
    current_name="$(printf '%s' "$item_id" | jq -r '.fieldValueByName.name // "No Status"')"
    item_id="$(printf '%s' "$item_id" | jq -r '.id')"

    _say "GitHub board move plan:"
    _say "Repo: $owner/$repo"
    _say "Issue: #$issue"
    _say "Board: $proj_owner project #$proj_number"
    _say "Status: $current_name -> $status"

    if [ "$current" = "$option_id" ]; then
        _say "Already in $status — nothing to do."
        return 0
    fi
    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no change made. Re-run with --execute after approval."
        return 0
    fi

    gh api graphql -f project="$proj_id" -f item="$item_id" -f field="$field_id" -f option="$option_id" -f query='
      mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
        updateProjectV2ItemFieldValue(input:{
          projectId:$project, itemId:$item, fieldId:$field,
          value:{ singleSelectOptionId:$option }}) { projectV2Item { id } }
      }' >/dev/null || { _err "Board move failed"; return 1; }
    _say "Moved #$issue to $status."
    _warn "Board automation reacts on its own schedule. A Done move closes the issue via native Auto-close (fast); moving out of a terminal column reopens it via a cron reconciler, which can lag well past its interval. Re-sync later, not immediately."
}
