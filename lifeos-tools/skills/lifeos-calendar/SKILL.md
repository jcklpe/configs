---
name: lifeos-calendar
description: "Use when reading or writing Google Calendar through the lifeos CLI: syncing the calendar snapshot, answering availability questions, or creating/updating events (dry-run by default). Covers the write-safety model (allowlisted calendars, no delete, --notify blast radius, layered attendee resolution via the people commands) and how to read availability."
---

# LifeOS Calendar
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-calendar/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

Calendar has its own auth, separate from the Gmail/Drive account aliases. See `lifeos-cli` for shared rules.

## Reads
```sh
lifeos calendar auth
lifeos calendar list-calendars
lifeos calendar find "Dinner"
lifeos calendar find "Dinner" --from 2026-07-01 --to 2026-07-31
lifeos calendar sync
```

`calendar find QUERY` is read-only and returns update-ready event IDs across the configured calendars and normal sync window by default. Use `--from YYYY-MM-DD`, `--to YYYY-MM-DD`, `--calendar CALENDAR_ID`, or `--json` when narrowing or scripting the lookup. Prefer `calendar find` over grepping `sources/calendar.md` when you need an event ID for `update-event`.

`calendar sync` is read-only and writes to `$LIFEOS_VAULT_PATH/sources/calendar.md` (or `~/configs/lifeos-tools/qa/calendar-qa.md` with `--qa`). It uses comma-separated `GOOGLE_CALENDAR_IDS` from the `.env`, defaulting to `primary`; run `list-calendars` to inspect IDs before expanding the set.

The snapshot is one date-grouped `## Combined Agenda` across all synced calendars, **including every enabled Microsoft 365 calendar** (labeled `<alias> (Microsoft 365): <name>`, times converted to the Google primary calendar's zone). A header block, `Microsoft 365 calendars:`, says per alias whether it was included or is `MISSING` and why; a MISSING line means the agenda is incomplete for that account, so do not answer availability from it without saying so. The same invitation delivered to both providers merges into one line with both calendar labels only when the iCalendar UIDs match; look-alike events stay as separate lines. `--google-only` skips Microsoft 365.

**Long horizon.** The same sync also writes `sources/calendar-long-horizon.md`: from where `calendar.md` ends to `LIFEOS_LONG_HORIZON_DAYS` (default 180) days out, same calendars including Microsoft 365, one line per event with no location, links, or descriptions. Recurring series with three or more occurrences collapse to one summary line each under `## Recurring Series` (weekdays, time, count, first and last date), grouped by recurrence ID rather than title; one-off events are listed by date under `## Long-Horizon Agenda`. An occurrence whose weekday-and-time slot appears only once in its series is treated as moved: it keeps its own dated line marked `(moved; this series is usually ...)`, and the series line says how many moved occurrences are listed below. A slot that recurs at least twice is part of the pattern, so a Mon/Wed series is not mistaken for moves. The near-term `calendar.md` always lists every occurrence in full. Nothing appears in both files: a timed event belongs to the long-horizon file only if it starts at or after the boundary, and an all-day event only if its date is after the boundary's local date. Read it for planning beyond the near-term window, deadlines, and "is anything already scheduled that far out"; use `calendar.md` for detail and conflicts. Google events are fetched with full paging; a fetch that exceeds `LIFEOS_CALENDAR_MAX_PAGES` (default 40) fails loudly instead of truncating. Every event line carries `calendar: <name>` and inline `location: ...`. Calendars listed in `LIFEOS_CALENDAR_NO_DESCRIPTION` have descriptions omitted as noise (case-insensitive summary match); an event also appearing on a non-listed calendar keeps its description. Multi-day all-day events appear under every blocked date with the covered range and the exclusive Google end date; timed events crossing midnight appear under every affected date.

## Writes
```sh
lifeos calendar create-event --title "Dinner" --start 2026-06-25T18:00 --attendee lindsey
lifeos calendar create-event --title "Trip" --start 2026-07-01 --execute
lifeos calendar update-event --event EVENT_ID --location "New place" --attendee mom --execute
```

Writes are **dry-run by default** — the command prints the full plan and changes nothing without `--execute`. Before `--execute`, the user should have approved the exact title, time, calendar, attendees, and whether to notify. Safety model, all tool-enforced:

- **Allowlisted calendars only.** Writes are rejected unless `--calendar` is in `LIFEOS_CALENDAR_WRITABLE_IDS` (default `primary`). Reads still see every calendar; writes cannot touch shared/work/partner calendars. There is no `delete-event`.
- **No attendee email-out by default.** `sendUpdates=none` unless `--notify` is passed. This is the real blast radius — adding an attendee with `--notify` sends a live invite. Pass it only when the user explicitly wants real people emailed.
- **Attendee resolution never guesses.** `--attendee VALUE` resolves as: (1) a value with `@` is a literal email; (2) otherwise the local alias map `people-aliases.json` (case-insensitive); (3) otherwise Google Contacts (People API). Ambiguous or unmatched People API names stop the write and list candidates rather than picking. Confirm the resolved name → email in the plan before `--execute`.
- **update-event merges attendees** by default; pass `--replace-attendees` to replace the list.
- **Recurring edits default to the single occurrence.** `update-event --event INSTANCE_ID` edits only that occurrence; `--series` retargets the series master (the plan's `Scope:` line says which). Create recurring events with `--recurrence "RRULE:FREQ=WEEKLY;BYDAY=MO"` (repeatable); `--recurrence` on update requires `--series`.

Times: `YYYY-MM-DD` makes an all-day event, `YYYY-MM-DDTHH:MM` a timed one (zoned to the calendar's time zone unless `--tz`). Missing `--end` defaults to +1 day (all-day, exclusive) or +1 hour (timed). Run `lifeos calendar sync` after a write.

The zone for a timed event comes from `--tz` if given, otherwise from the target calendar. **If it cannot be read, the command fails rather than guessing** — a wrong zone writes a real event at the wrong hour and looks entirely normal afterward, so there is no safe default (decision `docs/decisions/0006-writes-fail-rather-than-guess.md`). The error names the exact `--tz` value to pass, so a failure is one flag from resolved; it also points at the likely cause, which is worth fixing rather than routing around forever. Zones are IANA names (`America/Chicago`), never abbreviations (`CDT`). Still read the plan's `Time zone:` line before `--execute`.

## Disambiguating An Attendee
When `--attendee NAME` is ambiguous or unmatched, the write stops and lists candidates. Do not silently drop the attendee or pick one yourself:

```sh
lifeos people resolve NAME --json   # candidates as [{name,email}], for you to present
lifeos people add-alias NAME EMAIL  # remember the chosen person for next time
lifeos people list-aliases          # show the current alias map
```

Flow: `people resolve NAME --json`, show candidates to the user, let them pick, then re-run with the chosen email (or the alias once saved). Offer to `add-alias` so the same bare name resolves next time. Aliases live in the gitignored `people-aliases.json`; a value with `@` skips lookup.

## Availability Questions
Read `sources/calendar.md` in this order:

1. Check `## Combined Agenda` for the date or range.
2. Treat `My Schedule` as primary availability.
3. Treat Lindsey's calendar as important planning context, not automatically a conflict.
4. Treat Open Austin, work, and Partiful calendars as likely obligations unless context says otherwise.
   Treat Microsoft 365 calendars (school or work accounts) the same way. If the `Microsoft 365 calendars:` header marks an alias `MISSING`, say that the agenda is incomplete for that account before answering.
5. Treat Austin Design Hub as social/discovery context unless the event is also on `My Schedule` or the user says they plan to attend.
6. If an event is ambiguous, say so rather than assuming it blocks the date.
