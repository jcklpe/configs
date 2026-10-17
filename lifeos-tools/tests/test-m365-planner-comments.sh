#!/usr/bin/env bash
##- Offline task-comment safety tests: permissions, duplicates, first-thread links and uncertain outcomes.
set -eu
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIGS="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/planner-comments-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
. "$LIB_DIR/common.sh"
. "$LIB_DIR/m365-planner.sh"
LIFEOS_MAIL_AUDIT_LOG="$WORK/audit.jsonl"
refute() { if "$@"; then printf 'Expected failure: %s\n' "$*" >&2; exit 1; fi; }
_m365_require_enabled() { :; }
_m365_planner_require_plan_allowed() { [ "$2" = plan-1 ]; }
_m365_planner_require_write() { [ "$WRITE_ENABLED" -eq 1 ]; }
_m365_auth_provider() { printf graph-powershell; }
_m365_powershell_auth() { printf '%s' "$SCOPES"; }
_m365_graph_base() { printf https://graph.microsoft.com/v1.0; }
_m365_uri_encode() { jq -rn --arg x "$1" '$x|@uri'; }
_mail_audit_log_path() { printf '%s' "$LIFEOS_MAIL_AUDIT_LOG"; }
_mail_audit_append() { cat >> "$LIFEOS_MAIL_AUDIT_LOG"; }
WRITE_ENABLED=1 FAIL_CREATE=0 FAIL_REPLY=0 FAIL_LINK=0 READ_FAIL=0 PAGING=0
SCOPES='{"effective_scopes":["Group.ReadWrite.All"]}'
reset_fixture() {
    rm -rf "$WORK/planner-comments"
    printf '%s' '{"id":"task-1","planId":"plan-1","title":"Fixture","bucketId":"park","percentComplete":0,"assignments":{"user-1":{}},"appliedCategories":{"category2":true},"conversationThreadId":null,"@odata.etag":"etag"}' > "$WORK/task"
    printf '%s' '{"value":[]}' > "$WORK/posts"
    : > "$WORK/writes"
    FAIL_CREATE=0 FAIL_REPLY=0 FAIL_LINK=0 READ_FAIL=0 PAGING=0
}
_m365_get() {
    case "$2" in
        */planner/tasks/task-1) cat "$WORK/task" ;;
        */planner/plans/plan-1) printf '%s' '{"id":"plan-1","container":{"type":"group","containerId":"group-1"}}' ;;
        */groups/group-1/threads/thread-1/posts*)
            [ "$READ_FAIL" -eq 0 ] || return 1
            if [ "$PAGING" -eq 1 ]; then printf '%s' '{"value":[],"@odata.nextLink":"https://graph.microsoft.com/v1.0/groups/group-1/threads/thread-1/posts?$skip=1"}'; else cat "$WORK/posts"; fi ;;
        *) printf 'Unexpected GET %s\n' "$2" >&2; return 1 ;;
    esac
}
_m365_write() {
    printf '%s %s\n' "$1" "$3" >> "$WORK/writes"
    case "$3" in
        */groups/group-1/threads)
            printf '%s' "$4" | jq '{value:[(.posts[0] + {id:"post-1"})]}' > "$WORK/posts"
            [ "$FAIL_CREATE" -eq 0 ] || return 1
            printf '%s' '{"id":"thread-1"}' ;;
        */groups/group-1/threads/thread-1/reply)
            [ "$FAIL_REPLY" -ne 1 ] || return 1
            jq --argjson p "$4" '.value += [($p.post + {id:"post-2"})]' "$WORK/posts" > "$WORK/newposts"
            mv "$WORK/newposts" "$WORK/posts"
            [ "$FAIL_REPLY" -ne 2 ] || return 1
            printf '{}' ;;
        *) return 1 ;;
    esac
}
_m365_http() {
    printf '%s %s\n' "$1" "$3" >> "$WORK/writes"
    [ "${6:-}" = 'If-Match: etag' ] || return 1
    [ "$FAIL_LINK" -eq 0 ] || return 1
    jq --argjson p "$4" '. + $p' "$WORK/task" > "$WORK/newtask"
    mv "$WORK/newtask" "$WORK/task"
}
printf 'Historical action.\nRequest sent; awaiting response.\n' > "$WORK/comment"
printf 'A different follow-up.' > "$WORK/reply"
reset_fixture
SCOPES='{"effective_scopes":["Tasks.ReadWrite"]}'
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null 2>&1
[ ! -s "$WORK/writes" ]
SCOPES='{"effective_scopes":["Group.ReadWrite.All"]}'
_m365_planner_dispatch comments ut --task task-1 --json | jq -e '.thread_id == null and .posts == []' >/dev/null
out="$(_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment")"
printf '%s' "$out" | grep -F 'DRY RUN' >/dev/null
[ ! -s "$WORK/writes" ]
WRITE_ENABLED=0
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null 2>&1
[ ! -s "$WORK/writes" ]
WRITE_ENABLED=1
out="$(_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute)"
printf '%s' "$out" | grep -F 'confirmed by readback' >/dev/null
[ "$(wc -l < "$WORK/writes" | tr -d ' ')" = 2 ]
jq -e '.conversationThreadId == "thread-1" and .appliedCategories.category2 and .percentComplete == 0 and .bucketId == "park" and .assignments["user-1"] == {}' "$WORK/task" >/dev/null
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute | grep -q 'No change'
[ "$(wc -l < "$WORK/writes" | tr -d ' ')" = 2 ]
# The service can return HTML; whitespace wrapping does not create a duplicate.
jq '.value[0].body={contentType:"html",content:"<p>Historical action.</p><p>Request sent; awaiting response.</p>"}' "$WORK/posts" > "$WORK/newposts"
mv "$WORK/newposts" "$WORK/posts"
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute | grep -q 'No change'
_m365_planner_dispatch comments ut --task task-1 | grep -q 'Historical action.'
# Existing-thread reply is one POST and no task relink.
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/reply" --execute >/dev/null
[ "$(wc -l < "$WORK/writes" | tr -d ' ')" = 3 ]
# Known created thread survives a failed task link; retry links without a second post.
reset_fixture
FAIL_LINK=1
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null 2>&1
FAIL_LINK=0
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null
[ "$(grep -c '^POST' "$WORK/writes")" = 1 ]
# Initial post readback can fail before the task link; recover the retained thread without reposting.
reset_fixture
READ_FAIL=1
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null 2>&1
READ_FAIL=0
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null
[ "$(grep -c '^POST' "$WORK/writes")" = 1 ]
# A creation whose result is uncertain never silently creates another thread.
reset_fixture
FAIL_CREATE=1
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null 2>&1
FAIL_CREATE=0
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null 2>&1
[ "$(grep -c '^POST' "$WORK/writes")" = 1 ]
# A reply that applied before transport failure is recovered by readback, never reposted.
reset_fixture
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null
FAIL_REPLY=2
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/reply" --execute >/dev/null 2>&1
FAIL_REPLY=0
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/reply" --execute | grep -q 'No change'
[ "$(grep -c '^POST' "$WORK/writes")" = 2 ]
# A reply not visible after a failed attempt remains blocked, even if transport is healthy.
reset_fixture
_m365_planner_dispatch comment ut --task task-1 --file "$WORK/comment" --execute >/dev/null
FAIL_REPLY=1
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/reply" --execute >/dev/null 2>&1
FAIL_REPLY=0
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/reply" --execute >/dev/null 2>&1
[ "$(grep -c '^POST' "$WORK/writes")" = 2 ]
PAGING=1
refute _m365_planner_dispatch comments ut --task task-1 --json >/dev/null 2>&1
PAGING=0
READ_FAIL=1
refute _m365_planner_dispatch comments ut --task task-1 --json >/dev/null 2>&1
# Literal angle brackets in text/plain bodies are preserved.
printf 'Literal <tag> &amp; text' > "$WORK/literal"
printf '%s' '{"value":[{"id":"literal","body":{"contentType":"text","content":"Literal <tag> &amp; text"}}]}' | "$LIFEOS_PY" "$LIB_DIR/m365-planner-comments.py" match "$WORK/literal" | jq -e '. == ["literal"]' >/dev/null
printf '   \n' > "$WORK/blank"
refute _m365_planner_dispatch comment ut --task task-1 --file "$WORK/blank" --execute >/dev/null 2>&1
printf 'm365 planner comment tests passed\n' 
