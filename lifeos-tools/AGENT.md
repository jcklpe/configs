# LifeOS Tools Agent Guide

Use the local `lifeos` command to refresh LifeOS source context and make deliberate Trello updates.

## Core Rule

`sources/trello.md` is a generated context snapshot, not a write-back database. Read it to understand Trello state, but do not edit it to change Trello. Use explicit `lifeos trello ...` commands for writes, then refresh the snapshot.

## Quick Checks

```sh
lifeos doctor
lifeos trello list-lists
lifeos trello sync
lifeos calendar sync
lifeos google accounts
lifeos open-austin-org sync
```

`lifeos trello sync` writes the current Trello snapshot to:

```text
$LIFEOS_VAULT_PATH/sources/trello.md
```

For local QA or inspection without updating the LifeOS vault snapshot:

```sh
lifeos trello sync --qa
```

That writes:

```text
~/configs/lifeos-tools/trello-qa.md
```

`lifeos calendar sync` writes the current Google Calendar snapshot to:

```text
$LIFEOS_VAULT_PATH/sources/calendar.md
```

For local Calendar QA or inspection without updating the LifeOS vault snapshot:

```sh
lifeos calendar sync --qa
```

That writes:

```text
~/configs/lifeos-tools/calendar-qa.md
```

`lifeos gmail sync --all` writes bounded read-only Gmail snapshots to:

```text
$LIFEOS_VAULT_PATH/sources/gmail/
```

For local Gmail QA without updating the LifeOS vault:

```sh
lifeos gmail sync --all --qa
```

That writes ignored files under:

```text
~/configs/lifeos-tools/gmail-qa/
```


## Open Austin Org GitHub Snapshot

```sh
lifeos open-austin-org path
lifeos open-austin-org sync
lifeos open-austin-org sync --qa
lifeos open-austin-org create-issue --title "Task title" --body "Context" --label infrastructure --assign-me
```

`lifeos open-austin-org sync` runs the existing local org repo sync at `$OPEN_AUSTIN_ORG_REPO_PATH` or `~/work/org`, then copies only generated `snapshot/` Markdown into:

```text
$LIFEOS_VAULT_PATH/sources/open-austin-org/
```

Use this when LifeOS needs broad Open Austin GitHub issue/project context. The source of truth remains GitHub and the local org tooling repo. LifeOS receives generated context only.

The expected snapshot includes `issues.md`, `issues/*.md`, `labels.md`, `board-org-kanban.md`, `board-open-roles.md`, and `weekly-summary.md` when present.

Do not copy or inspect the org repo `.env`, `.git`, `.github`, tools, workflows, or token/config files. Do not make GitHub writes from LifeOS without explicit user approval and the org repo write-safety rules.


### Creating GitHub Issues

Use this only when Open Austin work needs to be public / org-visible in GitHub. Private strategy, personal bandwidth planning, or sensitive context belongs in LifeOS or Trello instead.

```sh
lifeos open-austin-org create-issue --title "Task title" --body "Context" --label infrastructure --assign-me
lifeos open-austin-org create-issue --title "Task title" --body-file /tmp/issue.md --label board --assign-me --execute
```

The command is dry-run by default and prints the plan. It creates an issue only with `--execute`. After creating an issue it refreshes `sources/open-austin-org/` unless `--no-sync` is passed.

Allowed fields: title, body/body-file, labels, assignees, repo override. Do not add comments, close/reopen issues, move project items, or bulk-edit GitHub state unless Aslan explicitly approves that specific action. Comments and issue writes notify real people or change public org state.

Before using `--execute`, the user should have approved the exact issue title/body/labels/assignees.

## Trello Reads

```sh
lifeos trello list-boards
lifeos trello list-lists
lifeos trello sync
```

The generated snapshot groups cards by board heading. If multiple boards are configured, `list-lists` without an argument uses the first configured board. Use `lifeos trello list-boards`, then `lifeos trello list-lists BOARD_ID` when targeting a specific non-default board. For writes to a non-default board, pass `--board BOARD_ID`.

Run `list-lists` before using list names if the board taxonomy may have changed. Prefer card URLs or card IDs for card operations.

## Trello Writes

Create a card:

```sh
lifeos trello add-card --list "On Deck" --name "Task name" --desc "Optional description" [--board BOARD_ID]
```

Move a card:

```sh
lifeos trello move-card --card CARD_ID_OR_URL --list Done [--board BOARD_ID]
```

Rename a card:

```sh
lifeos trello rename-card --card CARD_ID_OR_URL --name "New task name"
```

Replace a description from a file:

```sh
lifeos trello set-desc --card CARD_ID_OR_URL --file /tmp/card-desc.md
```

Add a comment:

```sh
lifeos trello comment --card CARD_ID_OR_URL --text "Comment text"
```

After any write:

```sh
lifeos trello sync
```

## Google Calendar

```sh
lifeos calendar auth
lifeos calendar list-calendars
lifeos calendar sync
```

`calendar sync` is read-only. It uses comma-separated `GOOGLE_CALENDAR_IDS` from `~/configs/lifeos-tools/.env`, with `primary` as the default. Run `list-calendars` to inspect available calendar IDs before expanding the configured set.

The snapshot uses `## Combined Agenda` as one date-grouped agenda across all synced calendars. Every event line includes `calendar: <calendar name>` so agents can tell which calendar produced the event. Event locations appear inline as `location: ...`. Descriptions are cleaned and bounded so long imported event text does not dominate the snapshot.

Calendars listed in `LIFEOS_CALENDAR_NO_DESCRIPTION` (in `.env`) have their event descriptions omitted as noise; all other calendars keep theirs. Matching is against the calendar summary, case-insensitive. An event that also appears on a non-listed (high-signal) calendar keeps its description.

Multi-day all-day events appear under every blocked date. Continuation lines include the covered date range and the exclusive Google Calendar end date so availability checks are safe. Timed events crossing midnight also appear under every affected date.

## Google Calendar Writes

```sh
lifeos calendar create-event --title "Dinner with Lindsey" --start 2026-06-25T18:00 --attendee lindsey
lifeos calendar create-event --title "Trip" --start 2026-07-01 --execute
lifeos calendar update-event --event EVENT_ID --location "New place" --attendee mom --execute
```

Writes are **dry-run by default**: the command prints the full plan and changes nothing. It only writes with `--execute`. Before using `--execute`, the user should have approved the exact title, time, calendar, attendees, and whether to notify.

Safety model, all enforced by the tool:

- **Allowlisted calendars only.** Writes are rejected unless the target `--calendar` is in `LIFEOS_CALENDAR_WRITABLE_IDS` (default `primary`). Reads still see every calendar; writes cannot touch shared/work/partner calendars. There is no `delete-event`.
- **Attendee invites do not email anyone by default.** `sendUpdates=none` unless `--notify` is passed. Only pass `--notify` when the user explicitly wants real people emailed. This is the real blast radius — adding an attendee with `--notify` sends a live calendar invite.
- **Name resolution order.** `--attendee VALUE` resolves as: (1) a value containing `@` is a literal email; (2) otherwise the local alias map `people-aliases.json` (case-insensitive) is checked — this is where frequent invitees like `lindsey` live, because common first names are ambiguous or unresolvable in Google Contacts; (3) otherwise Google Contacts (People API). Ambiguous People API matches (more than one contact) and no-match names both fail with the candidate list; they never guess who gets invited. Always confirm the resolved name → email shown in the dry-run plan before `--execute`.
- **update-event merges attendees by default** (adds to the existing list). Pass `--replace-attendees` to replace the whole list instead.
- **Recurring edits default to the single occurrence.** `update-event --event INSTANCE_ID` edits only that one occurrence. Pass `--series` to edit every occurrence (the tool resolves the instance to its series master). The plan's `Scope:` line states which one. Create recurring events with `create-event ... --recurrence "RRULE:FREQ=WEEKLY;BYDAY=MO"` (repeatable). `--recurrence` on update requires `--series`.

Times: `--start`/`--end` as `YYYY-MM-DD` makes an all-day event; `YYYY-MM-DDTHH:MM` makes a timed event. Timed events default their zone to the target calendar's time zone unless `--tz` is given. Missing `--end` defaults to +1 day (all-day, exclusive) or +1 hour (timed).

After a write, run `lifeos calendar sync` to refresh the LifeOS snapshot.

### Disambiguating an attendee

When `--attendee NAME` is ambiguous (several contacts) or has no match, the write command stops and lists candidates rather than guessing. Do not silently drop the attendee or pick one yourself. Instead:

```sh
lifeos people resolve NAME --json   # candidates as [{name,email}], for you to present
lifeos people add-alias NAME EMAIL  # remember the chosen person for next time
lifeos people list-aliases          # show the current alias map
```

Flow: run `people resolve NAME --json`, show the candidates to the user, let them pick, then re-run the create/update with the chosen email (or the alias once saved). Offer to `add-alias` so the same bare name resolves directly afterward. Aliases live in the gitignored `people-aliases.json`; a value with `@` always skips lookup.

## Availability Questions

When answering availability questions, read `sources/calendar.md` in this order:

1. Check `## Combined Agenda` for the date or range.
2. Treat `My Schedule` as primary availability.
3. Treat Lindsey's calendar as important planning context, not automatically a conflict.
4. Treat Open Austin, work, and Partiful calendars as likely obligations unless context says otherwise.
5. Treat Austin Design Hub as social/discovery context unless the event is also on `My Schedule` or the user says they plan to attend.
6. If an event is ambiguous, say so rather than assuming it blocks the date.

## Gmail And Drive

```sh
lifeos google accounts
lifeos google auth ALIAS
lifeos gmail sync ALIAS
lifeos gmail sync --all
lifeos drive accounts
lifeos drive search ALIAS "query text"
lifeos drive list ALIAS FOLDER_ID
lifeos drive meta ALIAS FILE_URL_OR_ID
lifeos drive read ALIAS FILE_URL_OR_ID
```

Gmail snapshots are generated context, not a mailbox control surface. Do not send, reply, archive, delete, label, or mark messages read/unread with `lifeos`.

Gmail sync is inbox-only and bounded: the default per-account query is `in:inbox newer_than:30d -label:Newsletters`. Archived mail, mail older than 30 days, and anything labeled `Newsletters` are excluded by design. Per-account queries live in ignored `google-accounts.json`.

Drive commands are on-demand reads. Do not clone Drive into LifeOS, recursively index whole Drives, or generate broad Drive summaries. Use `drive search`, then `drive meta` or `drive read` on a specific file. `drive read` supports Google Docs text and bounded Google Sheets previews first.

## Safety Notes

- Do not print or inspect `~/configs/lifeos-tools/.env`.
- Do not print or inspect Google token files or `google-accounts.json`.
- Do not hard-delete Trello cards.
- Description replacement overwrites the full Trello description. Prefer comments for additive notes.
- Trello write commands do not yet have dry-run or before/after output. Open Austin org issue creation and Google Calendar event writes are dry-run by default and require `--execute`.
- Google Calendar event writes (`create-event` / `update-event`) are allowed but constrained: allowlisted calendars only, no delete, and no attendee email-out unless `--notify` is passed. See "Google Calendar Writes" above.
- Do not add Gmail or Drive write commands.
