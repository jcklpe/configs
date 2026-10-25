#!/usr/bin/env bash
##- Legacy resume entry: preserve caller defaults while delegating rendering to the portable skill.

_resume_theme_default() {
    printf '%s/../../agent-hands/skills/render-markdown-pdf/assets/themes/resume.css\n' "$LIB_DIR"
}

_resume_render() {
    local input="" output="" theme="" open_output=0 renderer_dir
    local asset_args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --output|--theme|--asset-dir)
                [ $# -ge 2 ] && [ -n "$2" ] || { _err "Missing value for $1"; return 1; }
                case "$1" in
                    --output) output="$2" ;;
                    --theme) theme="$2" ;;
                    --asset-dir) asset_args+=(--asset-dir "$2") ;;
                esac
                shift 2 ;;
            --open) open_output=1; shift ;;
            -h|--help)
                _say 'Usage: lifeos resume render INPUT.md [--output PATH] [--theme CSS] [--asset-dir DIR] [--open]'
                return 0 ;;
            -*) _err "Unknown resume render option: $1"; return 1 ;;
            *)
                [ -z "$input" ] || { _err "Unexpected argument: $1"; return 1; }
                input="$1"; shift ;;
        esac
    done
    [ -n "$input" ] && [ -f "$input" ] || { _err 'Expected an existing Markdown input'; return 1; }
    command -v uv >/dev/null 2>&1 || { _err 'uv is required; see render-markdown-pdf setup'; return 1; }
    renderer_dir="$(cd "$LIB_DIR/../../agent-hands/skills/render-markdown-pdf" && pwd)" || return 1
    theme="${theme:-$(_resume_theme_default)}"
    if [ -z "$output" ]; then
        output="$(cd "$(dirname "$input")" && pwd)/$(basename "${input%.md}").pdf"
    fi
    _ensure_parent_dir "$output" || return 1
    uv run --locked --project "$renderer_dir" python "$renderer_dir/scripts/render.py" "$input" --output "$output" --theme "$theme" --force "${asset_args[@]}" || return 1
    if [ "$open_output" = 1 ] && command -v open >/dev/null 2>&1; then
        open "$output"
    fi
}
