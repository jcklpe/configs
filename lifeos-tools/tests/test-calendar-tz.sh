#!/usr/bin/env bash
##- Test the calendar default-time-zone resolution ladder. Offline: the metadata lookup is stubbed.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# The lib modules expect the dispatcher's globals.
CONFIGS="$(cd "${TOOL_DIR}/.." && pwd)"
SECRETS_DIR="${TOOL_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"
LIB_DIR="${TOOL_DIR}/lib"
QA_DIR="${TOOL_DIR}/qa"
export CONFIGS SECRETS_DIR ENV_FILE LIB_DIR QA_DIR

# shellcheck source=/dev/null
. "${LIB_DIR}/common.sh"
# shellcheck source=/dev/null
. "${LIB_DIR}/google.sh"

WARN_OUT="${TMPDIR:-/tmp}/lifeos-calendar-tz-warn.txt"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

##- Rung 3: the machine's zone must be a real IANA identifier, not an abbreviation.
# `date +%Z` would give CDT here, which Google rejects. Guard against a regression to it.
system_tz="$(_system_tz || true)"
[ -n "$system_tz" ] || fail "_system_tz returned nothing; no /etc/timezone, no /etc/localtime symlink, no \$TZ"
case "$system_tz" in
    [A-Z][A-Z]|[A-Z][A-Z][A-Z]|[A-Z][A-Z][A-Z][A-Z]|[A-Z][A-Z][A-Z][A-Z][A-Z])
        fail "_system_tz returned '${system_tz}', which looks like a zone abbreviation rather than an IANA name" ;;
esac

##- Rung 2: a successful metadata read wins, and is silent.
_calendar_get() { printf '{"timeZone": "Europe/Berlin"}'; }
got="$(_calendar_default_tz primary 2>"$WARN_OUT")"
[ "$got" = "Europe/Berlin" ] || fail "expected Europe/Berlin from the calendar lookup, got '${got}'"
[ ! -s "$WARN_OUT" ] || fail "the successful lookup path must not warn, but wrote: $(cat "$WARN_OUT")"

##- Rung 2 must beat rung 3: a calendar pinned to another zone is legitimate (travel, shared calendars).
[ "$got" != "$system_tz" ] || fail "test is degenerate: pick a stub zone that differs from the machine zone"

##- Rung 3: lookup failure falls back to the machine zone, loudly.
_calendar_get() { return 1; }
got="$(_calendar_default_tz primary 2>"$WARN_OUT")"
[ "$got" = "$system_tz" ] || fail "expected the system zone '${system_tz}' after a failed lookup, got '${got}'"
grep -F -- "WARN:" "$WARN_OUT" >/dev/null || fail "a fallback to the machine zone must warn on stderr"

##- Rung 4: no lookup and no system zone means UTC, loudly.
_system_tz() { return 1; }
got="$(_calendar_default_tz primary 2>"$WARN_OUT")"
[ "$got" = "UTC" ] || fail "expected UTC as the last resort, got '${got}'"
grep -F -- "WARN:" "$WARN_OUT" >/dev/null || fail "the UTC fallback must warn on stderr"

##- An empty timeZone field is a failed read, not a valid zone.
_calendar_get() { printf '{}'; }
_system_tz() { printf 'America/Chicago'; }
got="$(_calendar_default_tz primary 2>"$WARN_OUT")"
[ "$got" = "America/Chicago" ] || fail "an empty timeZone must fall through to the machine zone, got '${got}'"

rm -f "$WARN_OUT"
printf 'ok: calendar time-zone ladder\n'
