# LifeOS Calendar Time Zone — To Do
## Background
`lifeos calendar create-event` planned timed events in UTC instead of the calendar's `America/Chicago`, because `_calendar_default_tz` reads `GET /calendars/{id}` (403 under the current token scope) and both fallbacks then failed on macOS. Conceptual context and the chosen resolution ladder: `docs/active-spikes/lifeos-calendar-timezone.md`.

## Project Organization
- Implementation: `lifeos-tools/lib/google.sh` (`_calendar_default_tz`, ~line 997).
- Both `_calendar_create_event` (~1337) and `_calendar_update_event` (~1466) call it, so one fix covers both paths.
- Test: `lifeos-tools/tests/test-calendar-tz.sh` (new), following the offline style of `tests/test-m365-write.sh`.
- Run the suite: `cd lifeos-tools && for test in tests/test-*.sh; do bash "$test" || exit; done`

## General Principles
- bash 3.2 only. No GNU-only flags (`readlink -f` is unavailable on macOS).
- Tests stay offline — stub the metadata lookup, never call Google.
- Explicit `--tz` must remain untouched and unwarned.
- A fallback must be visible on stderr. Silence is the actual bug being fixed.

## Current State Overview
Root cause confirmed empirically:
- `GET /calendars/primary` → `curl: (56) ... 403`
- `GET /users/me/calendarList/primary?fields=timeZone` → `{"timeZone": "America/Chicago"}`
- `/etc/timezone` absent on this Mac; `/etc/localtime` → `/var/db/timezone/zoneinfo/America/Chicago`

## To Do
- (none)

## Ready for Human QA
- **Confirm a real timed event lands at the right hour.** The dry-run plan now reports `Time zone: America/Chicago` without `--tz`, but no `--execute` has been run through the fixed path. Next time a timed event is created for real, check the resulting event's start time in the Google Calendar UI. Everything up to the write is verified; only the round-trip is not.

## Done
- [x] Repoint `_calendar_default_tz` at `/users/me/calendarList/{id}`. — Done. `GET /calendars/{id}` returned `curl: (56) ... 403` under the current token; `GET /users/me/calendarList/{id}?fields=timeZone` returns `{"timeZone": "America/Chicago"}`. Left a comment at the call site warning against "simplifying" it back, since the old form looks more natural and fails silently.
- [x] Add portable system-zone detection: `/etc/timezone`, else the `/etc/localtime` symlink target, else `$TZ`. — Done as a new `_system_tz`. macOS has no `/etc/timezone`; `/etc/localtime` → `/var/db/timezone/zoneinfo/America/Chicago`, so the symlink target is stripped at `*/zoneinfo/`. Deliberately did **not** use `readlink -f` (unavailable on macOS) or `date +%Z` (yields `CDT`, not a valid IANA name — Google rejects it).
- [x] Warn on stderr whenever a fallback rung is used, naming the zone and the reason. — Done via `_warn`. Rung 2 stays silent because it is the intended path; rungs 3 and 4 warn. The silence was the actual defect: the old code reached hardcoded UTC on every call and looked like a normal run.
- [x] Add `tests/test-calendar-tz.sh` covering the ladder with the lookup stubbed. — Done, offline by shadowing `_calendar_get` and `_system_tz`. Five assertions: system zone is an IANA name and not an abbreviation; a successful lookup wins and does not warn; the stub zone differs from the machine zone so rung-2-beats-rung-3 is actually exercised rather than passing degenerately; lookup failure falls to the machine zone with a warning; total failure yields UTC with a warning; and an empty `timeZone` field counts as a failed read rather than a valid zone. Full suite (7 files) passes.
- [x] Note in `skills/lifeos-calendar/SKILL.md` that the plan's `Time zone:` line should be checked before `--execute`. — Done. Notable: the skill's existing description ("zoned to the calendar's time zone unless `--tz`") was already **correct** — the docs described intended behavior and the implementation was wrong, which is the reverse of the usual drift. So this is an added caution, not a correction.
- [x] Check whether the M365 write path shares this class of bug (out of scope to fix here; record the finding). — Done: **it does not.** `_m365_calendar_timezone` reads `.calendar.timezone` from the local M365 accounts config with a hardcoded `Central Standard Time` default — no network read, so no silent-403 path and no UTC fallback. Latent but not a bug: the hardcoded Central default would be wrong after a relocation. Left alone deliberately.
- Added, unplanned: discovered while verifying that `sources/trello.md` never renders a `start:` field, only `due:`. Snoozed cards are therefore visible in the vault snapshot but their **wake dates are not**, so a snooze cannot be audited from the vault — the `lifeos-trello` skill claims snoozed cards "stay visible in `sources/trello.md` (no separate register needed)," which is only half true. Not fixed here (out of scope, different subsystem); logged so it is not lost.

## Open Questions
- Should rung 3 (system zone) eventually fail closed instead of warning? Deferred; reasoning recorded in the conceptual doc. Revisit only if a warned fallback still produces a wrong write.

## Known Edge Cases
- A calendar whose Google-side zone differs from the machine's zone is legitimate (travel, a shared calendar pinned to another zone). Rung 2 must win over rung 3 for exactly this reason.
- `date +%Z` returns an abbreviation (`CDT`), which is **not** a valid IANA identifier and must never be used as the zone value.
- All-day events do not need a zone at all; `build_times` in `google-calendar-write.py` only requires `--tz` for timed events. The ladder must not start demanding a zone for date-only starts.
