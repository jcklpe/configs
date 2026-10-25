#!/usr/bin/env bash
##- Test the mail-sync additions for triage offline: HTML-only bodies render as text, Gmail web links, unsubscribe headers (Gmail and Microsoft 365), Gmail rate-limit backoff, retired --all behavior, and explicit one-off --query routing. Network calls are stubbed.

set -eu

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
CONFIGS="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
SECRETS_DIR="${SCRIPT_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"
QA_DIR="${SCRIPT_DIR}/qa"
LIFEOS_PY="${SCRIPT_DIR}/.venv/bin/python"
[ -x "$LIFEOS_PY" ] || LIFEOS_PY=python3

. "${LIB_DIR}/common.sh"
. "${LIB_DIR}/google.sh"
. "${LIB_DIR}/m365.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-mail-sync-triage-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
b64() { printf '%s' "$1" | "$LIFEOS_PY" -c 'import base64,sys; print(base64.urlsafe_b64encode(sys.stdin.buffer.read()).decode().rstrip("="))'; }

bash "${SCRIPT_DIR}/../agent-hands/skills/use-gmail/tests/test-transport-render.sh"

##- Microsoft 365 renderer
cat > "${WORK}/m365.json" <<'EOF'
{"value": [
  {"id": "x1", "subject": "Newsletter", "receivedDateTime": "2026-09-29T10:00:00Z", "from": {"emailAddress": {"address": "news@example.com"}},
   "body": {"contentType": "html", "content": "<html><head><style>p { color: red; }</style></head><body><p>Hello readers.</p></body></html>"},
   "webLink": "https://outlook.office365.com/owa/?ItemID=x1",
   "internetMessageHeaders": [{"name": "List-Unsubscribe", "value": "<https://example.com/m365/u>"}, {"name": "List-Unsubscribe-Post", "value": "List-Unsubscribe=One-Click"}]},
  {"id": "x2", "subject": "Personal", "receivedDateTime": "2026-09-28T10:00:00Z", "from": {"emailAddress": {"address": "a@example.com"}},
   "body": {"contentType": "text", "content": "Hi."}, "internetMessageHeaders": [{"name": "Received", "value": "by mx"}]}
]}
EOF
"$LIFEOS_PY" "${LIB_DIR}/m365-render.py" mail --alias ut --email me@example.edu --refreshed now --days 30 --max-results 150 --body-limit 8000 --input "${WORK}/m365.json" > "${WORK}/m365.md"
grep -F "Hello readers." "${WORK}/m365.md" >/dev/null || fail "M365 HTML body renders"
grep -F "color: red" "${WORK}/m365.md" >/dev/null && fail "M365 style content must not render"
grep -F -- "- Unsubscribe: <https://example.com/m365/u> (one-click supported)" "${WORK}/m365.md" >/dev/null || fail "M365 unsubscribe header"
[ "$(grep -c -- '- Unsubscribe:' "${WORK}/m365.md")" -eq 1 ] || fail "M365 unsubscribe only when present"
grep -F "internetMessageHeaders" "${SCRIPT_DIR}/../agent-hands/skills/use-outlook-mail/scripts/operations.sh" >/dev/null || fail "M365 mail export requests internetMessageHeaders"

##- Retired aggregation stops before any provider export.
_gmail_export() { printf '%s\n' "$@" > "$WORK/export-args"; }
if _gmail_sync --all > "$WORK/out" 2> "$WORK/err"; then fail "--all must be retired"; fi
[ ! -e "$WORK/export-args" ] || fail "retired --all must not invoke an export"
grep -F 'retired' "$WORK/err" >/dev/null || fail "retirement needs a diagnostic"
_gmail_sync secondary --query "in:inbox" --max-results 500 --output "$WORK/oneoff.md"
printf '%s\n' secondary --query "in:inbox" --max-results 500 --output "$WORK/oneoff.md" > "$WORK/expected"
cmp "$WORK/export-args" "$WORK/expected" || fail "explicit query/count/output arguments must reach the owning export unchanged"
printf 'OK: mail compatibility and triage renderer checks passed\n'
