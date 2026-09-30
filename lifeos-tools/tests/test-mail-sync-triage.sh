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

##- Gmail renderer
STYLE_HTML='<html><head><title>Promo 97678_TEMP</title><style>/* RESET */ body { margin: 0; }</style></head><body><p>Card offer inside.</p><script>track()</script></body></html>'
PLAIN_HTML='<html><head><style type="text/css">.mbi_box { border: solid 1px; }</style></head><body><p>Your claim was denied.</p></body></html>'
cat > "${WORK}/gmail.json" <<EOF
{"messages": [
  {"id": "m1", "threadId": "t1", "labelIds": ["INBOX"], "payload": {"mimeType": "multipart/alternative",
    "headers": [{"name": "Subject", "value": "Style promo"}, {"name": "From", "value": "promo@example.com"}, {"name": "Date", "value": "Tue, 29 Sep 2026 10:00:00 +0000"},
                {"name": "List-Unsubscribe", "value": "<https://example.com/u/1>,\n <mailto:unsub@example.com>"}, {"name": "List-Unsubscribe-Post", "value": "List-Unsubscribe=One-Click"}],
    "parts": [{"mimeType": "text/html", "body": {"data": "$(b64 "$STYLE_HTML")"}}]}},
  {"id": "m2", "threadId": "t2", "labelIds": ["INBOX"], "payload": {"mimeType": "text/plain",
    "headers": [{"name": "Subject", "value": "Denial notice"}, {"name": "From", "value": "notices@example.com"}, {"name": "Date", "value": "Mon, 28 Sep 2026 10:00:00 +0000"}],
    "body": {"data": "$(b64 "$PLAIN_HTML")"}}},
  {"id": "m3", "threadId": "t3", "labelIds": ["INBOX"], "payload": {"mimeType": "text/plain",
    "headers": [{"name": "Subject", "value": "Plain note"}, {"name": "From", "value": "friend@example.com"}, {"name": "Date", "value": "Sun, 27 Sep 2026 10:00:00 +0000"}],
    "body": {"data": "$(b64 'Plain text with <angle> words stays as is.')"}}}
]}
EOF
"$LIFEOS_PY" "${LIB_DIR}/google-gmail-render.py" personal person@example.com "in:inbox" 150 8000 "2026-09-30 00:00:00 UTC" "${WORK}/gmail.json" > "${WORK}/gmail.md"
grep -F "Card offer inside." "${WORK}/gmail.md" >/dev/null || fail "HTML body text renders"
grep -F -e "RESET" -e "margin: 0" -e "track()" -e "97678_TEMP" "${WORK}/gmail.md" >/dev/null && fail "style, script, and title content must not render"
grep -F "Your claim was denied." "${WORK}/gmail.md" >/dev/null || fail "HTML inside a text/plain part renders as text"
grep -F ".mbi_box" "${WORK}/gmail.md" >/dev/null && fail "CSS inside a text/plain HTML part must not render"
grep -F "Plain text with <angle> words stays as is." "${WORK}/gmail.md" >/dev/null || fail "ordinary plain text is untouched"
grep -F -- "- Link: https://mail.google.com/mail/u/?authuser=person@example.com#all/t1" "${WORK}/gmail.md" >/dev/null || fail "Gmail web link"
grep -F -- "- Unsubscribe: <https://example.com/u/1>, <mailto:unsub@example.com> (one-click supported)" "${WORK}/gmail.md" >/dev/null || fail "Gmail unsubscribe header with one-click flag"
[ "$(grep -c -- '- Unsubscribe:' "${WORK}/gmail.md")" -eq 1 ] || fail "unsubscribe line only when the header exists"

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

##- Gmail rate-limit backoff
_google_access_token() { printf 'token\n'; }
sleep() { printf 'slept %s\n' "$1" >> "${WORK}/sleeps.log"; }
CALLS="${WORK}/calls"
printf '0\n' > "$CALLS"
# Stub curl: fail the first two calls with a rate limit, then succeed. Writes the body to the -o file and prints the status like -w.
curl() {
    local out="" n
    while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
    n=$(( $(cat "$CALLS") + 1 )); printf '%s\n' "$n" > "$CALLS"
    if [ "$n" -le "${RATE_LIMITED_CALLS:-2}" ]; then
        printf '%s' '{"error":{"code":403,"message":"Quota exceeded for Total Query Cost","errors":[{"reason":"rateLimitExceeded"}]}}' > "$out"; printf '403'
    else
        printf '%s' '{"messages":[{"id":"ok"}]}' > "$out"; printf '200'
    fi
}
RATE_LIMITED_CALLS=2
[ "$(_gmail_get personal https://gmail.example/list 2>/dev/null | jq -r '.messages[0].id')" = "ok" ] || fail "retries through rate limits"
[ "$(grep -c slept "${WORK}/sleeps.log")" -eq 2 ] || fail "backs off once per rate-limited attempt"
grep -F "slept 4" "${WORK}/sleeps.log" >/dev/null || fail "backoff doubles"

printf '0\n' > "$CALLS"
RATE_LIMITED_CALLS=99
LIFEOS_GMAIL_MAX_RETRIES=2
if _gmail_get personal https://gmail.example/list > "${WORK}/out.txt" 2> "${WORK}/err.txt"; then fail "gives up after max retries"; fi
[ -s "${WORK}/out.txt" ] && fail "nothing on stdout after a failure"
grep -F "rateLimitExceeded" "${WORK}/err.txt" >/dev/null || fail "names Google's reason"
grep -F "Quota exceeded for Total Query Cost" "${WORK}/err.txt" >/dev/null || fail "surfaces Google's message"
grep -F "NEXT:" "${WORK}/err.txt" >/dev/null || fail "names a remedy"
unset LIFEOS_GMAIL_MAX_RETRIES

printf '0\n' > "$CALLS"
curl() {
    local out=""
    while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
    printf '%s' '{"error":{"code":403,"message":"Request had insufficient authentication scopes.","errors":[{"reason":"insufficientPermissions"}]}}' > "$out"; printf '403'
}
: > "${WORK}/sleeps.log"
if _gmail_get personal https://gmail.example/list > /dev/null 2> "${WORK}/err.txt"; then fail "non-rate-limit 403 fails"; fi
[ -s "${WORK}/sleeps.log" ] && fail "non-rate-limit errors are not retried"
grep -F "lifeos google auth personal" "${WORK}/err.txt" >/dev/null || fail "scope errors point at re-auth"

##- --all continues past a failing account
GOOGLE_ACCOUNTS_PATH="${SECRETS_DIR}/google-accounts.example.json"
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
grep -F "open-austin|" "${WORK}/synced.log" >/dev/null || fail "--all keeps going after a failing account"
grep -F "failed for: personal" "${WORK}/all.err" >/dev/null || fail "--all names the failing account"
[ -f "${WORK}/gmail/open-austin.md" ] || fail "the healthy account's snapshot is written"

##- --query is for one-off output only
if _gmail_sync personal --query "in:inbox" > /dev/null 2> "${WORK}/err.txt"; then fail "--query without --output is refused"; fi
grep -F "one-off" "${WORK}/err.txt" >/dev/null || fail "--query refusal explains why"
: > "${WORK}/synced.log"
_gmail_sync open-austin --query "in:inbox" --max-results 500 --output "${WORK}/oneoff.md" > /dev/null
grep -F "open-austin|in:inbox|500" "${WORK}/synced.log" >/dev/null || fail "--query and --max-results reach the sync"
if _gmail_sync --all --query "in:inbox" > /dev/null 2>&1; then fail "--all with --query needs --qa"; fi

printf 'OK: mail sync triage tests passed\n'
