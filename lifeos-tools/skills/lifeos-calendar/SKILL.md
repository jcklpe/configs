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

### Explicit data exports and compatibility
`lifeos calendar export-data SOURCE_LABEL --from INSTANT --to INSTANT --output FILE [--calendar ID]` uses the existing standalone Google calendar credentials and calendar selection. `SOURCE_LABEL` identifies that credential source in the export; it does not choose a different account. The Microsoft counterpart is `lifeos m365 calendar export-data ALIAS` with the same options. Bounds require offsets or `Z`, with an exclusive end. Outputs are complete schema-versioned JSON for [render-calendar-agenda](../../../agent-hands/skills/render-calendar-agenda/SKILL.md); failed or capped retrieval preserves old output. Use fresh private temporary filenames per refresh.

For new compositions, the calling workflow explicitly selects providers, expected sources, calendars, windows, timezone, and output paths. Personal availability meaning and workspace refresh procedures belong in that workspace, reached through `operate-lifeos` when relevant. This public guide does not define them.

`calendar sync` remains a temporary compatibility route with its existing configuration, two output files, and enabled-account composition. Its missing-source headers must be checked; it can publish a partial agenda, and successful command completion is not proof that every intended account was included. `--google-only` is a diagnostic subset, not a complete combined agenda. Final retirement waits for callers to migrate; new workflows should use explicit data exports and the neutral renderer.

## Writes
Before any write the user has not already approved item by item, present the proposed changes as an approval slate using the `draft-approval-slate` skill.

```sh
lifeos calendar create-event --title "Dinner" --start 2026-06-25T18:00 --attendee person@example.com
lifeos calendar create-event --title "Trip" --start 2026-07-01 --execute
lifeos calendar update-event --event EVENT_ID --location "New place" --attendee person@example.com --execute
```

Writes are **dry-run by default** — the command prints the full plan and changes nothing without `--execute`. Before `--execute`, the user should have approved the exact title, time, calendar, attendees, and whether to notify. Safety model, all tool-enforced:

- **Allowlisted calendars only.** Writes are rejected unless `--calendar` is in `LIFEOS_CALENDAR_WRITABLE_IDS` (default `primary`). Read selection is separate; writes cannot touch a calendar outside the configured writable list. There is no `delete-event`.
- **No attendee email-out by default.** `sendUpdates=none` unless `--notify` is passed. This is the real blast radius — adding an attendee with `--notify` sends a live invite. Pass it only when the user explicitly wants real people emailed.
- **Attendee resolution never guesses.** `--attendee VALUE` resolves as: (1) a value with `@` is a literal email; (2) otherwise the local alias map `people-aliases.json` (case-insensitive); (3) otherwise Google Contacts (People API). Ambiguous or unmatched People API names stop the write and list candidates rather than picking. Confirm the resolved name → email in the plan before `--execute`.
- **update-event merges attendees** by default; pass `--replace-attendees` to replace the list.
- **Recurring edits default to the single occurrence.** `update-event --event INSTANCE_ID` edits only that occurrence; `--series` retargets the series master (the plan's `Scope:` line says which). Create recurring events with `--recurrence "RRULE:FREQ=WEEKLY;BYDAY=MO"` (repeatable); `--recurrence` on update requires `--series`.

Availability: `--transparency transparent` marks an event **Free**; `--transparency opaque` marks it **Busy**. Both create and update accept it. Omission preserves Google's Busy default on create and the stored value on update. This setting changes whether the event blocks time; it does not change event visibility or sharing.

Personal reminder: `--popup-minutes 0` requests one popup at event start; integers through `40320` specify minutes before start. Both create and update accept it. An explicit value replaces the event's reminder overrides with one popup and disables calendar-default reminders for that event. Omission uses defaults on create and preserves existing reminders on update. `--notify` remains separate: it controls attendee email updates, not the authenticated user's popup reminder. Saving a popup setting does not establish that a client/device will display it.

When either option is explicit, the dry-run shows the requested settings, and an executed write fetches the saved event and verifies only those settings. A readback failure returns `PARTIAL` after the accepted write; inspect that event before retrying, and never automatically recreate it. Existing single-instance versus `--series` targeting applies to these fields too.

```sh
lifeos calendar create-event --title "Example event" --start 2030-01-02T09:00 --tz Etc/UTC --transparency transparent --popup-minutes 0
lifeos calendar update-event --event EVENT_ID --transparency opaque
```

Times: `YYYY-MM-DD` makes an all-day event, `YYYY-MM-DDTHH:MM` a timed one (zoned to the calendar's time zone unless `--tz`). Missing `--end` defaults to +1 day (all-day, exclusive) or +1 hour (timed). Refresh the affected caller's agenda after a write, following its owning workflow.

The zone for a timed event comes from `--tz` if given, otherwise from the target calendar. **If it cannot be read, the command fails rather than guessing** — a wrong zone writes a real event at the wrong hour and looks entirely normal afterward, so there is no safe default (policy `docs/policies/0006-writes-fail-rather-than-guess.md`). The error names the exact `--tz` value to pass, so a failure is one flag from resolved; it also points at the likely cause, which is worth fixing rather than routing around forever. Zones are IANA names (`America/Chicago`), never abbreviations (`CDT`). Still read the plan's `Time zone:` line before `--execute`.

## Disambiguating An Attendee
When `--attendee NAME` is ambiguous or unmatched, the write stops and lists candidates. Do not silently drop the attendee or pick one yourself:

```sh
lifeos people resolve NAME --json   # candidates as [{name,email}], for you to present
lifeos people add-alias NAME EMAIL  # remember the chosen person for next time
lifeos people list-aliases          # show the current alias map
```

Flow: `people resolve NAME --json`, show candidates to the user, let them pick, then re-run with the chosen email (or the alias once saved). Offer to `add-alias` so the same bare name resolves next time. Aliases live in the gitignored `people-aliases.json`; a value with `@` skips lookup.

## Availability interpretation
The tool returns events and source-coverage evidence. Whether a shared calendar blocks time, represents tentative plans, or provides discovery context belongs to the caller's private workflow. Do not infer attendance or a free day from event presence/absence alone, and disclose missing sources before making schedule claims.
