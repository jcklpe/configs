#!/usr/bin/env bash
# Offline tests for lib/github-render.py. No network, no credentials — the
# renderer is a pure JSON-to-markdown function, so it is directly testable.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${ROOT}/.venv/bin/python"; [ -x "$PY" ] || PY=python3
R="${ROOT}/lib/github-render.py"
FIX="${ROOT}/tests/fixtures"
fails=0

check() { # check <description> <haystack> <needle>
    case "$2" in
        *"$3"*) printf 'ok   %s\n' "$1" ;;
        *) printf 'FAIL %s\n       expected to find: %s\n' "$1" "$3"; fails=$((fails+1)) ;;
    esac
}
refute() {
    case "$2" in
        *"$3"*) printf 'FAIL %s\n       expected NOT to find: %s\n' "$1" "$3"; fails=$((fails+1)) ;;
        *) printf 'ok   %s\n' "$1" ;;
    esac
}

out="$("$PY" "$R" issue-index --owner o --repo r --kind issue --detail-dir issues < "$FIX/github-issues.json")"
check "index shows the repo"            "$out" "# Open Issues — o/r"
check "index counts items"              "$out" "**Count:** 2 open issues"
check "index groups by first label"     "$out" "## INFRASTRUCTURE"
check "index links to the detail file"  "$out" "(issues/42.md)"
check "index shows assignees"           "$out" "**Assigned:** alice"
check "unlabeled items get a section"   "$out" "## UNLABELED"
refute "index does not inline full body" "$out" "PARAGRAPH_THAT_SHOULD_BE_TRUNCATED"

out="$("$PY" "$R" item-detail --owner o --repo r --kind issue < "$FIX/github-issue-detail.json")"
check "detail shows the title"          "$out" "# #42 — Fix the widget"
check "detail includes the full body"   "$out" "full body text here"
check "detail includes comments"        "$out" "## Comments (1)"
check "detail attributes the comment"   "$out" "### @bob —"

out="$("$PY" "$R" discussions --owner o --repo r < "$FIX/github-discussions.json")"
check "discussions group by category"   "$out" "## GENERAL"
check "discussions show comment count"  "$out" "**Comments:** 4"
check "answered discussions are marked" "$out" "**Answered**"

out="$("$PY" "$R" discussion-detail --owner o --repo r < "$FIX/github-discussion-detail.json")"
check "detail shows the category"       "$out" "**Category:** Group decision making thread"
check "detail marks answered"           "$out" "**Answered**"
check "detail includes opening post"    "$out" "opening post body"
check "detail counts comments"          "$out" "## Comments (2)"
check "detail marks the answer comment" "$out" "marked as answer"
check "nested reply is quoted"          "$out" "> **@alexuvlab"
check "multi-line reply stays quoted"   "$out" "> with two lines"

out="$("$PY" "$R" board --project-number 9 --project-name org-kanban < "$FIX/github-board.json")"
check "board names the project"         "$out" "# Project #9 — org-kanban"
check "board groups by status"          "$out" "## Blocked"
check "board counts per column"         "$out" "**Count:** 1"
check "board items with no status"      "$out" "## No Status"

# A PR index must not be mislabeled as issues — the two share a renderer.
out="$("$PY" "$R" issue-index --owner o --repo r --kind pr --detail-dir pull-requests < "$FIX/github-issues.json")"
check "pr index says pull requests"     "$out" "# Open Pull Requests"
check "pr index links to pr details"    "$out" "(pull-requests/42.md)"
refute "pr index is not called issues"  "$out" "open issues"

if [ "$fails" -eq 0 ]; then printf '\nAll github-render tests passed.\n'; else printf '\n%d test(s) failed.\n' "$fails"; fi
exit "$fails"
