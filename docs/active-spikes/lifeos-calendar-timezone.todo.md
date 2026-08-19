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
- There is no fallback. A zone that cannot be read is a hard failure, and the error must name both the `--tz` workaround and the likely cause. Silence was the original defect; guessing was the second version of it.

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
- Added, unplanned: **the warn-and-fall-back design was reversed at the user's direction.** He argued that silent data corruption should be surfaced rather than guessed around, and that a hard failure is acceptable so long as it "surfaces the issue in a way that can be troubleshot and gotten around" rather than breaking writes outright. That is correct and my original reasoning was wrong in an instructive way: I weighed "cannot write at all" as a serious cost without noticing that the failure is **one flag from resolved**, which makes the outage objection nearly hollow. Implemented as: rungs 3 and 4 deleted; the function now `return 1`s with an error naming the exact `--tz` value to use (sourced from `_system_tz`, demoted to a hint generator) plus the likely underlying cause. Verified both call sites already propagate via `tz="$(...)" || return 1`. The happy path still resolves `America/Chicago` silently.
- Added, unplanned: rewrote the offline test around the **failure** path — asserts nonzero exit, empty stdout, "Refusing to guess", that the error contains `--tz` and the machine's actual zone, that an empty `timeZone` field counts as a failed read, and that with no hint available it still shows an IANA-shaped example and warns against `CDT`. Dropped a comment that had promised a dispatcher-level propagation test: forcing the lookup to fail through `./lifeos.sh` trips the credentials check first, so it cannot be isolated offline. Recorded that limitation in the test file instead of leaving a claim the test did not keep.
- Added, unplanned: the reversal settled a rule broader than this spike, so it became `docs/decisions/0006-writes-fail-rather-than-guess.md` — any correctness-critical value in a `lifeos` write must be known or fatal, never defaulted; a `WARN:` is not a control because warnings get scrolled past; and the stop must name both the workaround and the likely cause. Also notes that dry-run-by-default (0002) is a review gate dependent on a human reading the plan, not a correctness guarantee — it caught this bug, but both layers are wanted.
- Added, unplanned: discovered while verifying that `sources/trello.md` never renders a `start:` field, only `due:`. Snoozed cards are therefore visible in the vault snapshot but their **wake dates are not**, so a snooze cannot be audited from the vault — the `lifeos-trello` skill claims snoozed cards "stay visible in `sources/trello.md` (no separate register needed)," which is only half true. Not fixed here (out of scope, different subsystem); logged so it is not lost.

## Open Questions
- (none)

## Known Edge Cases
- A calendar whose Google-side zone differs from the machine's zone is legitimate (travel, a shared calendar pinned to another zone). This is why the machine's zone is only ever an error-message hint and never a substituted value — it would be confidently wrong in exactly that case.
- `date +%Z` returns an abbreviation (`CDT`), which is **not** a valid IANA identifier and must never be used as the zone value, nor suggested as one in an error.
- All-day events do not need a zone at all; `build_times` in `google-calendar-write.py` only requires `--tz` for timed events. The resolution must not start demanding a zone for date-only starts — the call sites gate on `*T*` for this reason.
