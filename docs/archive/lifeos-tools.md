# LifeOS Tools

Status: archived. Trello and multi-calendar Google Calendar sync are implemented, live-QA'd, documented, and available to LifeOS through the stable `lifeos` command.

Companion to-do: `docs/archive/lifeos-tools.todo.md`.

## Purpose

Build a small terminal helper in `configs/` that pulls live data from Trello and Google Calendar, converts that data into Markdown, and writes the result into the private local LifeOS vault so agents can read it as part of LifeOS context.

The question is not whether this tool should exist. It should. The question is how to implement it simply, in the style of this dotfiles repo, without turning it into a packaged application or leaking private data into git.

## Project Boundary

This repo owns the public-safe helper tooling.

The LifeOS vault owns private LifeOS content.

The local checkout may contain ignored secrets and tokens beside the tool, following the repo-wide convention in `docs/decisions/0001-secrets-and-local-env.md`.

The tool should not commit or generate private source snapshots inside this repo.

## Preferred Shape

Start simple:

```text
lifeos-tools/
  lifeos.sh
  .env.example
  .env
  google-token.example.json
  google-token.json
  README.md
```

Real secret-bearing files are ignored. Example files with fake values are tracked.

Do not start with a Python package layout, `bin/`, or nested `lifeos_tools/` directory. If Google OAuth or API parsing becomes too painful in Bash, add the smallest helper needed at that point.

## Tool Style

Prefer a Bash-first command script because this is dotfiles tooling, not an application package.

Use existing command-line tools where reasonable:

- `curl` for HTTP requests
- `jq` for API JSON parsing
- `python3` only if a specific piece is significantly clearer or safer outside Bash

If a dependency becomes required, document it and add it to the appropriate install path later.

## Command Surface

Target commands:

```sh
lifeos help
lifeos doctor
lifeos open
lifeos context
lifeos trello list-boards
lifeos trello list-lists [board_id]
lifeos trello sync [--qa | --output FILE]
lifeos trello add-card --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
lifeos trello move-card --card CARD_ID_OR_URL --list LIST [--board BOARD_ID]
lifeos trello rename-card --card CARD_ID_OR_URL --name NAME
lifeos trello set-desc --card CARD_ID_OR_URL --file FILE
lifeos trello comment --card CARD_ID_OR_URL (--text TEXT | --file FILE)
lifeos calendar auth
lifeos calendar list-calendars
lifeos calendar sync [--qa | --output FILE]
lifeos sync
```

The direct `cd ~/configs/lifeos-tools && ./lifeos.sh ...` form remains a fallback.

## Configuration

Primary configuration should come from `lifeos-tools/.env`, with `lifeos-tools/.env.example` committed as the migration template.

Expected variables:

```sh
LIFEOS_VAULT_PATH=
TRELLO_API_KEY=
TRELLO_TOKEN=
TRELLO_WRITE_TOKEN=
TRELLO_BOARD_IDS=
GOOGLE_CALENDAR_CREDENTIALS_PATH=
GOOGLE_CALENDAR_TOKEN_PATH=
GOOGLE_CALENDAR_IDS=
LIFEOS_DAYS_BACK=14
LIFEOS_DAYS_AHEAD=30
```

Shell environment values may override `.env` values if that is easy to implement cleanly.

Trello writes use `TRELLO_WRITE_TOKEN`; read-only sync uses `TRELLO_TOKEN`.

## Vault Outputs

The first useful sync outputs are:

```text
$LIFEOS_VAULT_PATH/sources/trello.md
$LIFEOS_VAULT_PATH/sources/calendar.md
```

Expected context files:

```text
$LIFEOS_VAULT_PATH/README.md
$LIFEOS_VAULT_PATH/CURRENT.md
$LIFEOS_VAULT_PATH/now.md
$LIFEOS_VAULT_PATH/weekly-review.md
```

Gmail and Drive source expansion is tracked separately in archived `docs/archive/lifeos-google-sources.md`.

## Trello Behavior

Trello sync support is read-only. Trello writes are handled by explicit write commands.

`trello list-boards` should fetch visible boards and print:

- board name
- board ID
- URL
- closed/archived state

`trello sync` should require comma-separated `TRELLO_BOARD_IDS` and write a human-readable Markdown snapshot grouped by board and list. By default it writes to `$LIFEOS_VAULT_PATH/sources/trello.md`; `--qa` writes a gitignored local snapshot to `lifeos-tools/trello-qa.md`; `--output FILE` writes to a caller-chosen path for inspection or wrapper tooling.

The current local setup syncs the Life board and a shared logistics board. Agents should read the board heading in the generated snapshot before assuming which board a card belongs to.

Include, where available:

- card name
- list name
- description
- comments
- labels
- due date
- checklist progress
- card URL

Do not write back to Trello.

## Trello Write Behavior

Trello write commands are explicit commands, not edits to the generated Markdown sync file.

Supported write operations:

- list board lists
- create a card
- move a card to another list
- rename a card
- replace a card description from a file
- add a comment from inline text or a file

Write commands require `TRELLO_WRITE_TOKEN`. The normal sync token can remain read-only.

The generated `sources/trello.md` file is context, not a write-back database. Agents should read it to understand current Trello state, then call explicit `lifeos trello ...` commands for changes.

With multiple configured boards, write commands should pass `--board BOARD_ID` when targeting any non-default board. Use `lifeos trello list-boards` and `lifeos trello list-lists BOARD_ID` before name-based list operations on a specific board.

Future Trello write-safety ideas are preserved in `docs/lifeos-tools-v2.md` so this v1 spike can close cleanly.

Description edits need extra care because they can clobber human-written context. Prefer `comment` for additive notes. For description changes, use file-based replacement now; later consider section-aware replacement or a diff preview before applying.

Bulk edits are out of scope for now. If added later, they should first produce a proposed change plan instead of immediately writing.

## Agent Exposure

The stable agent-facing entrypoint is `lifeos`, provided by `lifeos-tools/lifeos` and exposed by adding `lifeos-tools/` to `PATH` from `path.sh`. Avoid loading secrets in shell startup; the command continues loading `lifeos-tools/.env` at runtime.

Agent-facing usage notes live in `lifeos-tools/AGENT.md`. On this machine, the LifeOS vault has a local symlink at `runbooks/lifeos-tools.md` pointing back to that tracked file.

Any future MCP/plugin-style surface should be tracked as v2 work and wrap the stable CLI behavior rather than replacing it.

## Google Calendar Behavior

Google Calendar support is currently read-only.

Calendar uses small `python3` helpers for OAuth/token lifecycle and event date expansion. Calendar API reads stay in the Bash CLI with `curl` and `jq`.

Implemented setup:

- use a Google Cloud OAuth client for a desktop/installed app
- enable the Google Calendar API for the project
- request narrow read-only Calendar scopes:
  - `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
  - `https://www.googleapis.com/auth/calendar.events.readonly`
- keep the downloaded client credentials in ignored `lifeos-tools/google-credentials.json`
- keep the generated access/refresh token data in ignored `lifeos-tools/google-token.json`
- commit fake neighbor examples only: `google-credentials.example.json` and `google-token.example.json`

Calendar command flow:

```sh
lifeos calendar auth
lifeos calendar list-calendars
lifeos calendar sync
```

`calendar auth` performs the one-time local OAuth flow and writes/updates `GOOGLE_CALENDAR_TOKEN_PATH`.

`calendar list-calendars` prints calendar names and IDs.

`calendar sync` uses configured calendar IDs, or primary calendar if none are configured, and writes a human-readable Markdown snapshot. The current local setup syncs the primary calendar plus selected work, community, shared, imported, and group calendars. By default it writes to `$LIFEOS_VAULT_PATH/sources/calendar.md`; `--qa` writes a gitignored local snapshot to `lifeos-tools/calendar-qa.md`; `--output FILE` writes to a caller-chosen path for inspection or wrapper tooling.

The default snapshot shape is one combined date-grouped agenda:

```text
# Google Calendar

Last refreshed: ...
Today: ...
Window: ...
Calendar IDs: ...

## Combined Agenda

### 2026-06-06

- 15:30-18:00 - Event name | calendar: Calendar Name | location: Place | meeting: https://... | https://...
```

Do not emit separate per-calendar event sections in the default LifeOS snapshot. Source labels belong on event lines; reasoning about hard/soft/possible conflicts belongs in the LifeOS runbook/agent layer, not in the source snapshot.

When the same Google event reliably appears from multiple calendars, merge it into one event line and combine the calendar labels. If identity is not reliable, preserve separate lines rather than hiding source ambiguity.

Include:

- last refreshed timestamp
- calendar IDs synced
- today
- upcoming 7 days
- upcoming 30 days
- past `LIFEOS_DAYS_BACK` days
- calendar identity on each event line
- inline location when present
- direct meeting/conference links when available
- cleaned, bounded description blocks when present
- reliable duplicate-event merging with combined calendar labels
- all-day events
- timed events
- multi-day all-day events expanded under every blocked date
- timed events crossing midnight expanded under every affected date
- event links when available

Do not write back to Google Calendar in the current implementation.

Implementation notes:

- Use Bash plus `curl`/`jq` for Calendar API calls once a valid access token exists.
- Use `lifeos-tools/google-calendar-auth.py` for OAuth/token lifecycle.
- Use `lifeos-tools/google-calendar-render.py` for combined Markdown rendering, description cleanup, and event date expansion where Python is clearer and safer than `jq`.
- Refresh expired access tokens automatically when `google-token.json` has a refresh token.
- If auth fails, print the next local setup step without printing token contents.
- Treat `GOOGLE_CALENDAR_IDS=primary` as the default first useful config.

## Google Calendar Write Assessment

Calendar writes should not mirror the Trello write model without tighter boundaries. Calendar data can involve guests, shared calendars, imported calendars, calendars where this account is read-only, recurring events, external invitations, and notification side effects. A generic "edit or delete any visible event" tool would create too much blast radius for a low-frequency workflow.

Current stance:

- Keep `calendar sync` read-only.
- Do not add broad Calendar edit/delete commands.
- Treat one-off cleanup, such as removing an obsolete application deadline, as better handled manually in Google Calendar unless this becomes common.
- If Calendar writes become useful, track that as v2 work. Start with event creation on a dedicated, private, writable LifeOS-owned calendar rather than arbitrary edits across all synced calendars.

## Doctor Behavior

`doctor` should be practical and direct:

- confirm `.env` exists or point to `.env.example`
- confirm `LIFEOS_VAULT_PATH` is set
- confirm the vault path exists
- confirm expected LifeOS context files exist
- confirm `sources/` exists or explain what will be written there
- confirm Trello values are present without printing them
- confirm Google credential/token paths are configured without printing token contents
- confirm required local commands are available

Do not turn `doctor` into a policy lecture. It should answer: "Can I run this tool, and what do I need to fix?"

## Current Implementation Notes

The first slice uses `lifeos-tools/lifeos.sh` with Bash, `curl`, `jq`, and a small `python3` helper for Google OAuth/token lifecycle.

Implemented:

- `help`
- `doctor`
- `open`
- `context`
- `trello list-boards`
- `trello list-lists`
- `trello sync`, including `--qa` and `--output FILE`
- `trello add-card`
- `trello move-card`
- `trello rename-card`
- `trello set-desc`
- `trello comment`
- `calendar auth`
- `calendar list-calendars`
- `calendar sync`, including `--qa` and `--output FILE`
- `sync` with Trello and Calendar support
- documented Calendar write constraints and future write boundary

Live QA confirmed:

- Trello sync can render multiple configured boards in one generated snapshot
- Trello sync includes the Life board and the shared logistics board in `$LIFEOS_VAULT_PATH/sources/trello.md`
- Trello card creation in `On Deck`
- Trello comment write
- Trello description replacement from a file
- Trello card rename
- Trello card move to the open `Done` list
- `trello sync --qa` reflecting final written state
- Google Calendar OAuth token generation
- Google Calendar list-calendars
- Google Calendar configured calendar set sync to `calendar-qa.md`
- Google Calendar configured calendar set sync to `$LIFEOS_VAULT_PATH/sources/calendar.md`
- Google Calendar combined date-grouped agenda output
- Google Calendar event-line calendar labels
- Google Calendar inline event locations
- Google Calendar cleaned bounded description blocks
- Google Calendar multi-day all-day event expansion, including continuation dates
- Google Calendar timed cross-midnight event expansion
- Combined `lifeos sync` refreshing Trello and Calendar snapshots

Future enhancement threads have been moved to `docs/lifeos-tools-v2.md`.

## Archive Readiness

This spike has met its promotion criteria:

- Trello sync updates the private vault snapshot on demand.
- Trello write commands have been live-QA'd on a disposable card.
- Trello sync supports multiple configured boards.
- Google Calendar sync has a settled read-only auth approach and updates the private vault snapshot on demand.
- `lifeos` is available as the stable agent-facing command.
- Durable setup and agent usage notes are in `lifeos-tools/README.md` and `lifeos-tools/AGENT.md`.

## Non-Goals

- No cron.
- No webhooks.
- No daemon.
- No implicit Trello writes by editing the generated Markdown snapshot.
- No broad writes to Google Calendar.
- No Calendar edits/deletes across arbitrary synced calendars.
- No private vault content in this repo.
- No committed generated Trello or Calendar snapshots in this repo.
- No package-style hierarchy unless a future implementation need earns it.

## Future Threads

Future v2 ideas are preserved in `docs/lifeos-tools-v2.md` rather than left as unresolved work in this archive-ready spike.

## Promotion Criteria

This spike was ready to archive when:

- Trello sync can update the private vault snapshot on demand
- Trello write commands have been live-QA'd on a disposable card
- Google Calendar sync has a settled auth approach and can update the private vault snapshot on demand
- `lifeos` is available as the stable agent-facing command
- durable setup notes are folded into `README.md`, `AGENTS.md`, or a decision record as needed

All criteria are satisfied as of the current local implementation.
