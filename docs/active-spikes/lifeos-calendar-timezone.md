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
- Make the system-zone fallback work on macOS, the primary machine.
- Make any fallback **loud**, so a silently wrong zone can never again look like a normal run.
- Keep an offline regression test so the fallback ladder does not rot.

## Non-Goals
- **Do not widen the OAuth scope.** Reading calendar metadata through `calendarList` is sufficient and strictly less privileged than requesting more scope. A scope change would force a reauthorization for no functional gain.
- Do not touch the Microsoft 365 write path. `m365-write.py` takes a Windows-style zone name (`Central Standard Time`) and has its own resolution story; whether it shares this class of bug is a separate question, noted in the to-do doc.
- Do not change the meaning of `--tz` when it is supplied explicitly. Explicit always wins.
- Do not retroactively audit or repair previously written events. Only one timed-event write predates this fix on the affected path, and it was corrected in the same session by passing `--tz`.

## Design: The Resolution Ladder
Four rungs, most specific first:

1. **Explicit `--tz`** — always wins, no lookup, no warning.
2. **The calendar's own zone** via `GET /users/me/calendarList/{id}`. The normal path.
3. **The machine's zone**, detected portably: `/etc/timezone` where it exists (Linux), else the `/etc/localtime` symlink target (macOS and most modern Linux), else `TZ` if set.
4. **`UTC`** as the last resort.

Rungs 3 and 4 emit a warning to stderr naming the zone used and why. Rung 2 is silent because it is the intended path.

### Why warn rather than fail
Failing closed on rung 3 is defensible — a wrong zone is silent data corruption, which is exactly the failure class this spike exists to fix. It was not chosen because the fallback ladder is a deliberate existing affordance and a hard failure would break `create-event` on any machine where the metadata read is unavailable, turning a rare wrong-zone risk into a common cannot-write-at-all outage. Making rung 3 actually correct on the primary OS reduces the practical blast radius far more than failing would, and the warning plus the dry-run plan's `Time zone:` line means a human sees the zone before any write lands. Revisit if a fallback ever produces a wrong write despite the warning.

## Constraints
- **bash 3.2.** No associative arrays, no `${var,,}`, no `mapfile`. Applies to everything in `lib/`.
- Zone detection must not assume GNU coreutils. macOS `readlink` has no `-f`; use the plain symlink read and strip the prefix, or `date +%Z` only as a last-resort display value (never as a zone identifier — `CDT` is not a valid IANA name).
- Tests are offline. They may not make network calls, so the ladder needs to be exercised by stubbing the lookup rather than by hitting Google.

## Relationship To Other Work
The calendar write surface itself was settled in `docs/decisions/0002-lifeos-calendar-writes.md`, which does not mention time zones at all — the gap this spike closes. The user-facing skill `lifeos-tools/skills/lifeos-calendar/SKILL.md` already documented the intended behavior ("zoned to the calendar's time zone unless `--tz`"), so the **documentation was correct and the implementation was wrong**. That is the unusual shape here: no doc fix was needed for accuracy, only a note about verifying the plan's zone line.
