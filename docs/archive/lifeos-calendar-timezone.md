# LifeOS Calendar Time Zone
Fix the default time-zone resolution for `lifeos calendar create-event` / `update-event`, which silently fell back to UTC and would have written timed events seven hours off.

## The Bug
`_calendar_default_tz` in `lifeos-tools/lib/google.sh` resolves a timed event's zone from the target calendar when `--tz` is not supplied. It read `GET /calendars/{id}`, which **returns 403 under the token's current scope**. `_calendar_get` is `curl -fsS`, so the failure was silent; the function fell through to `/etc/timezone`, which **does not exist on macOS**, and then to the hardcoded `printf 'UTC'`.

Net effect on this machine: every timed event created or moved without an explicit `--tz` was planned in UTC while the user, the calendar, and the machine are all `America/Chicago`. A noon event would have been written at 07:00 local.

Discovered 2026-08-19 by the LifeOS vault agent while adding UT orientation events. The dry-run plan printed `Time zone: UTC`, which is the only reason it was caught before an `--execute`. **The dry-run gate is what saved this**, and that is worth remembering as evidence for the dry-run-by-default design.

`GET /users/me/calendarList/{id}` returns the same `timeZone` field and **does** work under the current scope. Verified:

```
$ _calendar_get "/users/me/calendarList/primary" --data-urlencode "fields=timeZone"
{ "timeZone": "America/Chicago" }
```

## Goals
- Resolve the calendar's real zone through an endpoint the current token can actually read.
- Detect the machine's zone portably (macOS included) so the failure message can suggest a concrete value.
- Never write a timed event on a guessed zone. Fail loudly instead, with an error that names the workaround.
- Keep an offline regression test so the fallback ladder does not rot.

## Non-Goals
- **Do not widen the OAuth scope.** Reading calendar metadata through `calendarList` is sufficient and strictly less privileged than requesting more scope. A scope change would force a reauthorization for no functional gain.
- Do not touch the Microsoft 365 write path. `m365-write.py` takes a Windows-style zone name (`Central Standard Time`) and has its own resolution story; whether it shares this class of bug is a separate question, noted in the to-do doc.
- Do not change the meaning of `--tz` when it is supplied explicitly. Explicit always wins.
- Do not retroactively audit or repair previously written events. Only one timed-event write predates this fix on the affected path, and it was corrected in the same session by passing `--tz`.

## Design: The Resolution Ladder
Two rungs, and then a stop:

1. **Explicit `--tz`** — always wins, no lookup.
2. **The calendar's own zone** via `GET /users/me/calendarList/{id}`. The normal path.
3. **Failure.** If the zone cannot be read, the command stops and writes nothing.

### Why it fails instead of guessing
**Reversed 2026-08-19 at the user's direction.** The first implementation had two more rungs — the machine's zone, then `UTC` — each emitting a warning. The argument for that was continuity: a hard failure turns a rare wrong-hour risk into a common cannot-write-at-all outage, so making the macOS rung correct seemed to shrink the blast radius more than failing would.

The user rejected the premise, correctly. A guessed zone is **silent data corruption**: the event is written, it looks entirely normal, and nothing downstream can detect that it is seven hours off. A warning on stderr does not fix that, because warnings are exactly what gets scrolled past in a long agent transcript — and the whole reason this bug survived was that its symptom was invisible. Meanwhile the "outage" objection turns out to be hollow, because **the failure is one flag away from resolution**: the error names the exact `--tz` value to pass. So writing is never actually blocked; it just stops being automatic in the one situation where automatic is unsafe.

The general rule this settles for the repo: **when a write cannot be made correctly, stop and surface it — do not proceed on a guess.** Prefer a loud stop that hands over the workaround to a quiet success that might be wrong.

`_system_tz` survives the reversal, demoted. It no longer supplies a value; it only supplies a **hint inside the error message** ("e.g. `--tz America/Chicago` (this machine's zone)"), which is what keeps the stop actionable rather than merely obstructive.

## Constraints
- **bash 3.2.** No associative arrays, no `${var,,}`, no `mapfile`. Applies to everything in `lib/`.
- Zone detection must not assume GNU coreutils. macOS `readlink` has no `-f`; use the plain symlink read and strip the prefix, or `date +%Z` only as a last-resort display value (never as a zone identifier — `CDT` is not a valid IANA name).
- Tests are offline. They may not make network calls, so the ladder needs to be exercised by stubbing the lookup rather than by hitting Google.

## Relationship To Other Work
The calendar write surface itself was settled in `docs/decisions/0002-lifeos-calendar-writes.md`, which does not mention time zones at all — the gap this spike closes. The user-facing skill `lifeos-tools/skills/lifeos-calendar/SKILL.md` already documented the intended behavior ("zoned to the calendar's time zone unless `--tz`"), so the **documentation was correct and the implementation was wrong**. That is the unusual shape here: no doc fix was needed for accuracy, only a note about verifying the plan's zone line.
