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

## Trello Reads

```sh
lifeos trello list-boards
lifeos trello list-lists
lifeos trello sync
```

Run `list-lists` before using list names if the board taxonomy may have changed. Prefer card URLs or card IDs for card operations.

## Trello Writes

Create a card:

```sh
lifeos trello add-card --list "On Deck" --name "Task name" --desc "Optional description"
```

Move a card:

```sh
lifeos trello move-card --card CARD_ID_OR_URL --list Done
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

Calendar sync is read-only. It uses `GOOGLE_CALENDAR_IDS` from `~/configs/lifeos-tools/.env`, with `primary` as the default. Run `list-calendars` to inspect available calendar IDs before expanding the configured set.

## Safety Notes

- Do not print or inspect `~/configs/lifeos-tools/.env`.
- Do not hard-delete Trello cards.
- Description replacement overwrites the full Trello description. Prefer comments for additive notes.
- Current write commands do not yet have dry-run or before/after output.
- Do not add Google Calendar write commands.
