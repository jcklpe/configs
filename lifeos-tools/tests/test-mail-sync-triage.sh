#!/usr/bin/env bash
##- Test the mail-sync additions for triage offline: HTML-only bodies render as text, Gmail web links, unsubscribe headers (Gmail and Microsoft 365), Gmail rate-limit backoff, --all continuing past a failing account, and the one-off --query guard. Network calls are stubbed.

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
grep -F "internetMessageHeaders" "${LIB_DIR}/m365.sh" >/dev/null || fail "M365 mail sync requests internetMessageHeaders"

##- --all continues past a failing account
jq '.accounts += [.accounts[0] + {alias:"secondary", token_path:"google-secondary-token.json"}]' "${SECRETS_DIR}/google-accounts.example.json" > "$WORK/two-accounts.json"
GOOGLE_ACCOUNTS_PATH="$WORK/two-accounts.json"
export GOOGLE_ACCOUNTS_PATH
_vault_ready() { return 0; }
_ensure_sources_dir() { return 0; }
_gmail_sources_dir() { printf '%s\n' "${WORK}/gmail"; }
mkdir -p "${WORK}/gmail"
_gmail_sync_alias() {
    printf '%s|%s|%s\n' "$1" "${3:-}" "${4:-}" >> "${WORK}/synced.log"
    [ "$1" = "personal" ] && { _err "simulated failure"; return 1; }
    printf 'ok\n' > "$2"
}
if _gmail_sync --all > "${WORK}/all.out" 2> "${WORK}/all.err"; then fail "--all reports failure when one account fails"; fi
grep -F "secondary|" "${WORK}/synced.log" >/dev/null || fail "--all keeps going after a failing account"
grep -F "failed for: personal" "${WORK}/all.err" >/dev/null || fail "--all names the failing account"
[ -f "${WORK}/gmail/secondary.md" ] || fail "the healthy account's snapshot is written"

##- --query is for one-off output only
if _gmail_sync personal --query "in:inbox" > /dev/null 2> "${WORK}/err.txt"; then fail "--query without --output is refused"; fi
grep -F "one-off" "${WORK}/err.txt" >/dev/null || fail "--query refusal explains why"
: > "${WORK}/synced.log"
_gmail_sync secondary --query "in:inbox" --max-results 500 --output "${WORK}/oneoff.md" > /dev/null
grep -F "secondary|in:inbox|500" "${WORK}/synced.log" >/dev/null || fail "--query and --max-results reach the sync"
if _gmail_sync --all --query "in:inbox" > /dev/null 2>&1; then fail "--all with --query needs --qa"; fi

printf 'OK: mail sync triage tests passed\n'
