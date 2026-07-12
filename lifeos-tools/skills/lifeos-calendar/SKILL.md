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

The snapshot is one date-grouped `## Combined Agenda` across all synced calendars. Every event line carries `calendar: <name>` and inline `location: ...`. Calendars listed in `LIFEOS_CALENDAR_NO_DESCRIPTION` have descriptions omitted as noise (case-insensitive summary match); an event also appearing on a non-listed calendar keeps its description. Multi-day all-day events appear under every blocked date with the covered range and the exclusive Google end date; timed events crossing midnight appear under every affected date.

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
5. Treat Austin Design Hub as social/discovery context unless the event is also on `My Schedule` or the user says they plan to attend.
6. If an event is ambiguous, say so rather than assuming it blocks the date.
