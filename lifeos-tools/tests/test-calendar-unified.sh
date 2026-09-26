#!/usr/bin/env bash
##- Test the unified Google + Microsoft 365 agenda: normalization, cross-provider merge, and the loud failure line. Offline; all data is invented.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-unified-test.XXXXXX")"
OUT="${WORK}/agenda.md"

fail() {
    printf 'FAIL: %s\n\nAgenda:\n' "$*" >&2
    cat "$OUT" >&2 2>/dev/null || true
    exit 1
}

cat > "${WORK}/google-cal.json" <<'EOF'
{"id": "personal@example.com", "summary": "Personal", "primary": true, "timeZone": "America/Chicago"}
EOF
cat > "${WORK}/google-events.json" <<'EOF'
{"items": [
  {"id": "g1", "iCalUID": "shared-uid-1@example.com", "summary": "Coffee chat",
   "start": {"dateTime": "2026-10-09T09:15:00-05:00"}, "end": {"dateTime": "2026-10-09T10:00:00-05:00"}},
  {"id": "g2", "summary": "Standup",
   "start": {"dateTime": "2026-10-12T10:00:00-05:00"}, "end": {"dateTime": "2026-10-12T10:30:00-05:00"}}
]}
EOF
cat > "${WORK}/m365.json" <<'EOF'
{"calendars": [{"id": "primary", "graphId": "graph-cal-1", "name": "Calendar", "events": [
  {"id": "m1", "iCalUId": "shared-uid-1@example.com", "subject": "Coffee chat",
   "start": {"dateTime": "2026-10-09T14:15:00.0000000", "timeZone": "UTC"},
   "end": {"dateTime": "2026-10-09T15:00:00.0000000", "timeZone": "UTC"},
   "body": {"content": "Intro chat"}, "webLink": "https://outlook.example/m1"},
  {"id": "m2", "iCalUId": "other-uid@example.com", "subject": "Standup",
   "start": {"dateTime": "2026-10-12T15:00:00.0000000", "timeZone": "UTC"},
   "end": {"dateTime": "2026-10-12T15:30:00.0000000", "timeZone": "UTC"},
   "body": {"content": ""}},
  {"id": "m3", "iCalUId": "teams-uid@example.com", "subject": "Team sync",
   "start": {"dateTime": "2026-10-13T21:30:00.0000000", "timeZone": "UTC"},
   "end": {"dateTime": "2026-10-13T22:00:00.0000000", "timeZone": "UTC"},
   "isOnlineMeeting": true, "onlineMeeting": {"joinUrl": "https://teams.microsoft.com/l/meetup-join/example"},
   "body": {"content": "Agenda: review drafts\n\n________________________________________________________________________________\nMicrosoft Teams meeting\nJoin: https://teams.microsoft.com/meet/000\nMeeting ID: 000\nFor assistance with Teams, please contact the service desk."}},
  {"id": "m4", "iCalUId": "cancel-uid@example.com", "subject": "Cancelled review", "isCancelled": true,
   "start": {"dateTime": "2026-10-14T15:00:00.0000000", "timeZone": "UTC"},
   "end": {"dateTime": "2026-10-14T16:00:00.0000000", "timeZone": "UTC"}},
  {"id": "m5", "iCalUId": "allday-uid@example.com", "subject": "Campus closed", "isAllDay": true,
   "start": {"dateTime": "2026-12-24T00:00:00.0000000", "timeZone": "UTC"},
   "end": {"dateTime": "2026-12-25T00:00:00.0000000", "timeZone": "UTC"}}
]}]}
EOF

pairs="$(python3 "${TOOL_DIR}/lib/m365-calendar-normalize.py" --input "${WORK}/m365.json" --timezone America/Chicago --alias school --outdir "$WORK")"
# shellcheck disable=SC2086
python3 "${TOOL_DIR}/lib/google-calendar-render.py" "${WORK}/google-cal.json" "${WORK}/google-events.json" $pairs > "$OUT"

grep -F -- '- 09:15-10:00 - Coffee chat | calendar: Personal, school (Microsoft 365): Calendar' "$OUT" >/dev/null \
    || fail "shared-UID invitation should render once, carrying both calendar labels"
[ "$(grep -c 'Coffee chat' "$OUT")" -eq 1 ] || fail "shared-UID invitation rendered more than once"
[ "$(grep -c -- '- 10:00-10:30 - Standup' "$OUT")" -eq 2 ] || fail "look-alike events without a shared UID must stay separate"
grep -F -- '- 16:30-17:00 - Team sync' "$OUT" >/dev/null || fail "UTC 21:30 should render as 16:30 Central (CDT)"
grep -F 'https://teams.microsoft.com/l/meetup-join/example' "$OUT" >/dev/null || fail "Teams join link should be kept"
grep -F 'Agenda: review drafts' "$OUT" >/dev/null || fail "the human part of the description should be kept"
if grep -F 'For assistance with Teams' "$OUT" >/dev/null; then fail "Teams boilerplate should be stripped"; fi
if grep -F 'Cancelled review' "$OUT" >/dev/null; then fail "cancelled events should be omitted"; fi
grep -A2 '^### 2026-12-24' "$OUT" | grep -F -- '- all day - Campus closed' >/dev/null || fail "all-day event should stay on its calendar date"

##- Failure paths print a MISSING line and return non-zero instead of silently shrinking the agenda.
CONFIGS="$(cd "${TOOL_DIR}/.." && pwd)"; SECRETS_DIR="${WORK}"; ENV_FILE="${WORK}/.env"; LIB_DIR="${TOOL_DIR}/lib"; QA_DIR="${WORK}"
export CONFIGS SECRETS_DIR ENV_FILE LIB_DIR QA_DIR
# shellcheck source=/dev/null
. "${LIB_DIR}/common.sh"
# shellcheck source=/dev/null
. "${LIB_DIR}/google.sh"
# shellcheck source=/dev/null
. "${LIB_DIR}/m365.sh"
render_args=()
_m365_calendar_ids() { printf 'primary\n'; }
_m365_calendar_fetch() { return 1; }
if line="$(_calendar_add_m365 school 2026-10-01T00:00:00Z 2026-11-01T00:00:00Z America/Chicago)"; then fail "fetch failure should return non-zero"; fi
case "$line" in *"school: MISSING"*"does not include school"*) ;; *) fail "fetch failure line was: $line" ;; esac
if line="$(_calendar_add_m365 school 2026-10-01T00:00:00Z 2026-11-01T00:00:00Z "")"; then fail "missing time zone should return non-zero"; fi
case "$line" in *"school: MISSING"*"time zone"*) ;; *) fail "missing time zone line was: $line" ;; esac

##- Long horizon: compact lines, and the boundary rule that keeps it disjoint from the near-term file.
cat > "${WORK}/lh-events.json" <<'EOF'
{"items": [
  {"id": "b1", "summary": "Before boundary", "location": "Somewhere", "description": "detail",
   "start": {"dateTime": "2026-10-25T20:00:00-05:00"}, "end": {"dateTime": "2026-10-25T21:00:00-05:00"}},
  {"id": "b2", "summary": "After boundary",  "location": "Somewhere", "description": "detail",
   "start": {"dateTime": "2026-10-26T09:00:00-05:00"}, "end": {"dateTime": "2026-10-26T10:00:00-05:00"}},
  {"id": "b3", "summary": "All-day on boundary local day", "start": {"date": "2026-10-25"}, "end": {"date": "2026-10-26"}},
  {"id": "b4", "summary": "All-day after", "start": {"date": "2026-10-26"}, "end": {"date": "2026-10-29"}}
]}
EOF
LH="${WORK}/lh.md"
# Boundary 2026-10-26T04:49Z is 2026-10-25 23:49 Central: the near-term file owns 10/25.
python3 "${TOOL_DIR}/lib/google-calendar-render.py" --compact --start-at 2026-10-26T04:49:00Z --tz America/Chicago "${WORK}/google-cal.json" "${WORK}/lh-events.json" > "$LH"
grep -Fx -- '- 09:00-10:00 - After boundary | calendar: Personal' "$LH" >/dev/null || { cat "$LH"; fail "compact timed line wrong or carries extra detail"; }
grep -Fx -- '- all day - All-day after (through 2026-10-28) | calendar: Personal' "$LH" >/dev/null || { cat "$LH"; fail "multi-day all-day should be one line with its last date"; }
if grep -F 'Before boundary' "$LH" >/dev/null; then fail "events before the boundary belong to the near-term file"; fi
if grep -F 'All-day on boundary local day' "$LH" >/dev/null; then fail "an all-day event on the boundary's local day belongs to the near-term file"; fi
if grep -E 'location|Description|detail' "$LH" >/dev/null; then fail "long-horizon lines must not carry location or descriptions"; fi

##- Recurring series collapse by recurrence ID only; a same-titled one-off stays dated.
cat > "${WORK}/series-events.json" <<'EOF'
{"items": [
  {"id": "r1", "recurringEventId": "gym-series", "summary": "Gym", "start": {"dateTime": "2026-11-02T12:00:00-06:00"}, "end": {"dateTime": "2026-11-02T13:00:00-06:00"}},
  {"id": "r2", "recurringEventId": "gym-series", "summary": "Gym", "start": {"dateTime": "2026-11-04T12:00:00-06:00"}, "end": {"dateTime": "2026-11-04T13:00:00-06:00"}},
  {"id": "r3", "recurringEventId": "gym-series", "summary": "Gym", "start": {"dateTime": "2026-11-09T12:00:00-06:00"}, "end": {"dateTime": "2026-11-09T13:00:00-06:00"}},
  {"id": "s1", "summary": "Gym", "start": {"dateTime": "2026-11-05T18:00:00-06:00"}, "end": {"dateTime": "2026-11-05T19:00:00-06:00"}}
]}
EOF
SE="${WORK}/series.md"
python3 "${TOOL_DIR}/lib/google-calendar-render.py" --compact --start-at 2026-10-26T04:49:00Z --tz America/Chicago "${WORK}/google-cal.json" "${WORK}/series-events.json" > "$SE"
grep -Fx -- '- Gym — Mon, Wed, 12:00-13:00 — 3 occurrences, 2026-11-02 to 2026-11-09 | calendar: Personal' "$SE" >/dev/null || { cat "$SE"; fail "a recurring series should collapse to one summary line"; }
grep -Fx -- '- 18:00-19:00 - Gym | calendar: Personal' "$SE" >/dev/null || { cat "$SE"; fail "a same-titled one-off must stay as its own dated line"; }
[ "$(grep -c -- '- 12:00-13:00 - Gym' "$SE")" -eq 0 ] || fail "series occurrences should not also appear as dated lines"

##- Paging: every page is fetched and merged.
_calendar_get() {
    case "$*" in
        *pageToken=p2*) printf '{"items": [{"id": "e3"}]}' ;;
        *) printf '{"items": [{"id": "e1"}, {"id": "e2"}], "nextPageToken": "p2"}' ;;
    esac
}
_calendar_fetch_events cal 2026-10-01T00:00:00Z 2026-12-01T00:00:00Z "${WORK}/paged.json" "items(id),nextPageToken" || fail "paged fetch failed"
[ "$(jq '.items | length' "${WORK}/paged.json")" -eq 3 ] || fail "paging should merge all 3 items across 2 pages"
_calendar_get() { printf '{"items": [], "nextPageToken": "again"}'; }
if LIFEOS_CALENDAR_MAX_PAGES=3 _calendar_fetch_events cal a b "${WORK}/runaway.json" "items(id),nextPageToken" 2>/dev/null; then fail "a runaway fetch must fail loudly, not truncate"; fi

printf 'unified calendar tests passed\n'
