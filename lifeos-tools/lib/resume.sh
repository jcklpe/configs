#!/usr/bin/env bash
##- lifeos resume: render a Markdown resume to a themed PDF (headless, no app).
##- Pipeline: strip YAML frontmatter -> pandoc (Markdown -> HTML) -> wrap in the resume
##- theme inside Typora's #write container (so #write-scoped rules apply) -> WeasyPrint -> PDF.
##- Markdown stays the source of truth; the PDF is a regenerable artifact.
##- Deps: pandoc + weasyprint (both `brew install`). Fonts resolve from the system.

_resume_theme_default() {
    printf '%s/resume-theme/aslan-resume.css\n' "$LIB_DIR"
}

_resume_render() {
    local input="" output="" theme="" open=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --output) output="${2:-}"; shift 2 ;;
            --theme) theme="${2:-}"; shift 2 ;;
            --open) open=1; shift ;;
            -*) _err "Unknown resume render option: $1"; return 1 ;;
            *)
                if [ -z "$input" ]; then
                    input="$1"; shift
                else
                    _err "Unexpected argument: $1"; return 1
                fi
                ;;
        esac
    done

    if [ -z "$input" ]; then
        _err "Usage: lifeos resume render INPUT.md [--output PATH] [--theme CSS] [--open]"
        return 1
    fi
    [ -f "$input" ] || { _err "Input not found: $input"; return 1; }

    theme="${theme:-$(_resume_theme_default)}"
    [ -f "$theme" ] || { _err "Theme CSS not found: $theme"; return 1; }

    command -v pandoc >/dev/null 2>&1 || { _err "pandoc not found (brew install pandoc)"; return 1; }
    command -v weasyprint >/dev/null 2>&1 || { _err "weasyprint not found (brew install weasyprint)"; return 1; }

    # Default output: <name>.pdf next to the input source.
    if [ -z "$output" ]; then
        local dir base
        dir="$(cd "$(dirname "$input")" && pwd)"
        base="$(basename "${input%.md}")"
        output="${dir}/${base}.pdf"
    fi
    _ensure_parent_dir "$output"

    local workdir body_html html
    workdir="$(mktemp -d)"
    body_html="${workdir}/body.html"
    html="${workdir}/resume.html"

    # Strip a leading YAML frontmatter block so metadata never reaches the PDF, then convert.
    if ! awk '
        NR==1 && $0=="---" { infm=1; next }
        infm && ($0=="---" || $0=="...") { infm=0; next }
        !infm { print }
    ' "$input" | pandoc --from gfm --to html --wrap=none -o "$body_html"; then
        _err "pandoc conversion failed"
        command rm -rf "$workdir"
        return 1
    fi

    # Typora-shaped document: #write + .typora-export-content so the theme's element rules
    # and #write-scoped rules both apply. Merriweather (headings) and Arial (body) resolve
    # from installed system fonts; no network needed.
    {
        printf '<!doctype html>\n<html>\n<head>\n<meta charset="utf-8">\n'
        printf '<style>\n'
        cat "$theme"
        printf '\n</style>\n</head>\n<body class="typora-export">\n'
        printf '<div id="write" class="typora-export-content">\n'
        cat "$body_html"
        printf '\n</div>\n</body>\n</html>\n'
    } > "$html"

    if ! weasyprint "$html" "$output" 2>"${workdir}/err.log"; then
        _err "weasyprint render failed:"
        sed 's/^/  /' "${workdir}/err.log" >&2
        command rm -rf "$workdir"
        return 1
    fi

    command rm -rf "$workdir"

    if [ ! -s "$output" ]; then
        _err "render produced no output: $output"
        return 1
    fi

    _say "Rendered: $output"
    if [ "$open" = "1" ] && command -v open >/dev/null 2>&1; then
        open "$output"
    fi
    return 0
}
