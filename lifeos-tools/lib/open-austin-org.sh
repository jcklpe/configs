#!/usr/bin/env bash
##- lifeos Open Austin org feature: snapshot the org's GitHub state into the vault and create issues via gh.
##- Sourced by lifeos.sh; depends on lib/common.sh and the bootstrap vars.

_open_austin_org_repo_path() {
    if _var_is_set OPEN_AUSTIN_ORG_REPO_PATH; then
        _path_value OPEN_AUSTIN_ORG_REPO_PATH
    else
        printf "%s/work/org\n" "$HOME"
    fi
}

_open_austin_org_snapshot_dir() {
    printf "%s/snapshot\n" "$(_open_austin_org_repo_path)"
}

_open_austin_org_ready() {
    local repo run
    repo="$(_open_austin_org_repo_path)"
    run="${repo}/tools/sync/run.sh"

    if [ ! -d "$repo" ]; then
        _err "OPEN_AUSTIN_ORG_REPO_PATH does not exist: $repo"
        return 1
    fi
    if [ ! -x "$run" ]; then
        _err "Open Austin org sync script is missing or not executable: $run"
        return 1
    fi
    return 0
}

_open_austin_org_path() {
    local repo snapshot
    repo="$(_open_austin_org_repo_path)"
    snapshot="$(_open_austin_org_snapshot_dir)"
    _say "Repo: $repo"
    _say "Snapshot: $snapshot"
    if _vault_ready >/dev/null 2>&1; then
        _say "LifeOS output: $(_sources_dir)/open-austin-org"
    fi
}

_copy_open_austin_org_snapshot() {
    local src="$1" dest="$2" name

    [ -d "$src" ] || { _err "Snapshot directory does not exist: $src"; return 1; }
    mkdir -p "$dest" || return 1

    find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

    for name in issues.md labels.md board-org-kanban.md board-open-roles.md weekly-summary.md; do
        if [ -f "$src/$name" ]; then
            cp "$src/$name" "$dest/$name" || return 1
        fi
    done

    if [ -d "$src/issues" ]; then
        mkdir -p "$dest/issues" || return 1
        find "$src/issues" -maxdepth 1 -type f -name "*.md" -exec cp {} "$dest/issues/" \;
    fi
}

_open_austin_org_sync() {
    local custom_out="" repo snapshot out

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${SCRIPT_DIR}/open-austin-org-qa"
                shift
                ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires DIR"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown open-austin-org sync option: $1"; return 1 ;;
        esac
    done

    _open_austin_org_ready || return 1
    repo="$(_open_austin_org_repo_path)"
    snapshot="$(_open_austin_org_snapshot_dir)"

    _say "Refreshing Open Austin org snapshot from $repo" >&2
    (cd "$repo" && tools/sync/run.sh) || return 1

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/open-austin-org"
    fi

    _copy_open_austin_org_snapshot "$snapshot" "$out" || return 1

    _say "Updated $out"
    [ -f "$out/issues.md" ] && _say "- $out/issues.md"
    [ -f "$out/board-org-kanban.md" ] && _say "- $out/board-org-kanban.md"
    [ -f "$out/board-open-roles.md" ] && _say "- $out/board-open-roles.md"
    [ -f "$out/weekly-summary.md" ] && _say "- $out/weekly-summary.md"
}


_open_austin_org_github_repo() {
    if _var_is_set OPEN_AUSTIN_ORG_GITHUB_REPO; then
        _path_value OPEN_AUSTIN_ORG_GITHUB_REPO
    else
        printf 'open-austin/org\n'
    fi
}

_open_austin_org_gh_ready() {
    _check_command gh >/dev/null || { _err "gh is required"; return 1; }
    return 0
}

_open_austin_org_create_issue() {
    local repo title="" body="" body_file="" execute=0 sync_after=1 assign_me=0 login="" created_url=""
    local labels=() assignees=() cmd=()

    repo="$(_open_austin_org_github_repo)"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --title)
                [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }
                title="$2"
                shift 2
                ;;
            --body)
                [ -n "${2+x}" ] || { _err "--body requires TEXT"; return 1; }
                body="$2"
                shift 2
                ;;
            --body-file)
                [ -n "${2:-}" ] || { _err "--body-file requires FILE"; return 1; }
                body_file="$2"
                shift 2
                ;;
            --label)
                [ -n "${2:-}" ] || { _err "--label requires LABEL"; return 1; }
                labels+=("$2")
                shift 2
                ;;
            --assignee|--assign)
                [ -n "${2:-}" ] || { _err "$1 requires LOGIN"; return 1; }
                assignees+=("$2")
                shift 2
                ;;
            --assign-me)
                assign_me=1
                shift
                ;;
            --repo)
                [ -n "${2:-}" ] || { _err "--repo requires OWNER/REPO"; return 1; }
                repo="$2"
                shift 2
                ;;
            --execute)
                execute=1
                shift
                ;;
            --dry-run)
                execute=0
                shift
                ;;
            --no-sync)
                sync_after=0
                shift
                ;;
            *) _err "Unknown open-austin-org create-issue option: $1"; return 1 ;;
        esac
    done

    [ -n "$title" ] || { _err "create-issue requires --title"; return 1; }
    if [ -n "$body_file" ] && [ ! -f "$body_file" ]; then
        _err "Body file does not exist: $body_file"
        return 1
    fi

    if [ "$assign_me" -eq 1 ] && [ "$execute" -eq 1 ]; then
        _open_austin_org_gh_ready || return 1
        login="$(gh api user --jq .login)" || return 1
        assignees+=("$login")
    elif [ "$assign_me" -eq 1 ]; then
        assignees+=("@me")
    fi

    _say "GitHub issue create plan:"
    _say "Repo: $repo"
    _say "Title: $title"
    if [ -n "$body_file" ]; then
        _say "Body file: $body_file"
    elif [ -n "$body" ]; then
        _say "Body:"
        printf '%s\n' "$body"
    else
        _say "Body: <empty>"
    fi
    if [ "${#labels[@]}" -gt 0 ]; then
        _say "Labels: ${labels[*]}"
    else
        _say "Labels: <none>"
    fi
    if [ "${#assignees[@]}" -gt 0 ]; then
        _say "Assignees: ${assignees[*]}"
    else
        _say "Assignees: <none>"
    fi

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no GitHub issue was created. Re-run with --execute to create it."
        return 0
    fi

    _open_austin_org_gh_ready || return 1

    cmd=(gh issue create --repo "$repo" --title "$title")
    if [ -n "$body_file" ]; then
        cmd+=(--body-file "$body_file")
    else
        cmd+=(--body "$body")
    fi
    for label in "${labels[@]}"; do
        cmd+=(--label "$label")
    done
    for login in "${assignees[@]}"; do
        cmd+=(--assignee "$login")
    done

    created_url="$("${cmd[@]}")" || return 1
    _say "Created issue: $created_url"

    if [ "$sync_after" -eq 1 ]; then
        _open_austin_org_sync || return 1
    fi
}

