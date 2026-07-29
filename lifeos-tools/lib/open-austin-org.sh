#!/usr/bin/env bash
##- lifeos Open Austin org feature: refresh the public org repo snapshot and copy it into the vault.
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
                custom_out="${QA_DIR}/open-austin-org-qa"
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
