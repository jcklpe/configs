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

Calendar sync is read-only. It uses comma-separated `GOOGLE_CALENDAR_IDS` from `~/configs/lifeos-tools/.env`, with `primary` as the default. Run `list-calendars` to inspect available calendar IDs before expanding the configured set.

The snapshot uses `## Combined Agenda` as one date-grouped agenda across all synced calendars. Every event line includes `calendar: <calendar name>` so agents can tell which calendar produced the event. Event locations appear inline as `location: ...`. Descriptions are cleaned and bounded so long imported event text does not dominate the snapshot.

Multi-day all-day events appear under every blocked date. Continuation lines include the covered date range and the exclusive Google Calendar end date so availability checks are safe. Timed events crossing midnight also appear under every affected date.

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

Drive commands are on-demand reads. Do not clone Drive into LifeOS, recursively index whole Drives, or generate broad Drive summaries. Use `drive search`, then `drive meta` or `drive read` on a specific file. `drive read` supports Google Docs text and bounded Google Sheets previews first.

## Safety Notes

- Do not print or inspect `~/configs/lifeos-tools/.env`.
- Do not print or inspect Google token files or `google-accounts.json`.
- Do not hard-delete Trello cards.
- Description replacement overwrites the full Trello description. Prefer comments for additive notes.
- Current write commands do not yet have dry-run or before/after output.
- Do not add Google Calendar write commands.
- Do not add Gmail or Drive write commands.
