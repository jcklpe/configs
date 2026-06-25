# LifeOS Tools To-Do

Status: archived. Future enhancement threads have been moved to `docs/lifeos-tools-v2.md`.

Conceptual doc: `docs/archive/lifeos-tools.md`.

## Background

We need a small LifeOS helper script in `configs/` that pulls live Trello and Google Calendar data into Markdown files inside the private LifeOS vault.

The repo-wide secrets/env pattern is already settled in `docs/decisions/0001-secrets-and-local-env.md`: real local secret files may live in the working tree if ignored; tracked examples with fake values sit beside them.

## Project Organization

Planned initial folder:

```text
lifeos-tools/
  lifeos.sh
  .gitignore
  .env.example
  google-token.example.json
  README.md
```

Real local files that should exist only on a machine:

```text
lifeos-tools/.env
lifeos-tools/google-token.json
```

Potential later files:

```text
lifeos-tools/google-credentials.example.json
lifeos-tools/google-credentials.json
```

## General Principles

- Prefer Bash until a specific part clearly earns another language.
- Keep files flat and obvious.
- Load secrets at command runtime, not from global shell startup.
- Commit examples with fake values.
- Add ignore rules before creating real secret files.
- Keep sync read-only; keep Trello writes as explicit commands.
- Keep commands manual and on-demand.

## Current State Overview

- `lifeos-tools/` exists.
- `lifeos-tools/lifeos.sh` implements the first local/Trello slice.
- Trello read/write commands have passed live QA against the Life board.
- Trello sync now includes a second shared logistics board through comma-separated `TRELLO_BOARD_IDS`.
- Google Calendar auth/list/sync has passed live QA against the configured calendar set.
- `lifeos` is available as the stable command wrapper after shell startup loads `path.sh`.
- `lifeos-tools/AGENT.md` is symlinked into the local LifeOS vault at `runbooks/lifeos-tools.md`.
- Root `.gitignore` now covers common env/token/credential patterns.
- `lifeos-tools/.gitignore` covers tool-local env/token/credential files.
- `jq` and `python3` are now required install dependencies for this repo.
- Secrets/env decision is archived and durable.
- This spike has been promoted out of `docs/scratch/`.

## Future / Not Blocking

Future enhancement threads are preserved in `docs/lifeos-tools-v2.md` and `docs/lifeos-tools-v2.todo.md`.

## Calendar Implementation Prep

- Use the read-only scopes:
  - `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
  - `https://www.googleapis.com/auth/calendar.events.readonly`
- Treat `GOOGLE_CALENDAR_IDS=primary` as the default first config, then add selected calendars as a comma-separated list when the LifeOS context needs them.
- Keep real `google-credentials.json` and `google-token.json` ignored in `lifeos-tools/`.
- Keep fake `.example.json` files tracked beside the real files.
- Prefer Bash plus `curl`/`jq` for Calendar API reads after auth exists.
- Use `lifeos-tools/google-calendar-auth.py` for OAuth/token lifecycle.
- Use `lifeos-tools/google-calendar-render.py` for combined Markdown rendering, description cleanup, and event date expansion.
- Do not add Google Calendar write commands unless the write scope is deliberately narrowed and the OAuth scope is updated.

## Ready For Human QA

- No remaining Trello write QA for the current command set.
- No remaining Trello sync QA for the current configured multi-board set.
- No remaining Google Calendar QA for the current configured calendar set.

## Done

- Added docs workflow and scratch/archive/decision folders.
- Settled repo-wide secrets/env hygiene in `docs/decisions/0001-secrets-and-local-env.md`.
- Archived the secrets/env scratch spike.
- Drafted the LifeOS conceptual spike.
- Promoted the LifeOS spike docs out of `docs/scratch/`.
- Confirmed first implementation language: Bash in `lifeos-tools/lifeos.sh`.
- Confirmed first command name: use `./lifeos.sh ...` before adding any global `lifeos` command.
- Made `jq` the required JSON parser for LifeOS tooling.
- Created `lifeos-tools/`.
- Created `lifeos-tools/.gitignore` with ignores for `.env`, token JSON, credentials JSON, cache/temp files, and generated snapshots.
- Created `lifeos-tools/.env.example` with fake values for planned env vars.
- Created `lifeos-tools/google-credentials.example.json`.
- Created `lifeos-tools/google-token.example.json`.
- Created `lifeos-tools/README.md` with setup/run notes.
- Created `lifeos-tools/lifeos.sh` with a portable Bash command dispatcher.
- Implemented `./lifeos.sh help`.
- Implemented `.env` loading for `lifeos.sh`.
- Implemented redacted config status for diagnostics.
- Implemented `./lifeos.sh doctor`.
- Implemented `./lifeos.sh open`.
- Implemented `./lifeos.sh context`.
- Implemented Trello auth checks without printing key/token.
- Implemented `./lifeos.sh trello list-boards`.
- Defined initial Trello Markdown output shape in code.
- Implemented `./lifeos.sh trello sync`.
- Implemented initial `./lifeos.sh sync` with Trello support before Calendar was implemented.
- Added `jq` to Homebrew, Fedora dnf, and NixOS package installs.
- Added `python3` to Homebrew, Fedora dnf, and NixOS package installs.
- QA confirmed Trello API key/token works with `./lifeos.sh trello list-boards`.
- QA confirmed Trello sync writes `$LIFEOS_VAULT_PATH/sources/trello.md`.
- Filtered out cards whose lists are archived/closed so they do not render under `Unknown list`.
- Added Trello card descriptions to the Markdown sync output.
- Added Trello card comments from `commentCard` actions to the Markdown sync output.
- Added `TRELLO_WRITE_TOKEN` to `.env.example`.
- Implemented `./lifeos.sh trello list-lists`.
- Implemented `./lifeos.sh trello add-card`.
- Implemented `./lifeos.sh trello move-card`.
- Implemented `./lifeos.sh trello rename-card`.
- Implemented `./lifeos.sh trello set-desc`.
- Implemented `./lifeos.sh trello comment`.
- QA confirmed `./lifeos.sh trello list-lists` works.
- Captured LifeOS-agent feedback: keep sync as context, use explicit write commands, add dry-run/before-after behavior, and expose a stable command for other agents.
- Added `./lifeos.sh trello sync --qa` and `--output FILE` for local/private QA snapshots.
- QA confirmed `./lifeos.sh trello sync --qa` writes `lifeos-tools/trello-qa.md`, which is ignored by git.
- Rechecked the Trello Life board list taxonomy after the user renamed lists.
- Live QA confirmed `./lifeos.sh trello add-card` creates a card in `On Deck`.
- Live QA confirmed `./lifeos.sh trello comment` adds a comment to the test card.
- Live QA confirmed `./lifeos.sh trello set-desc` replaces a test card description from a file.
- Live QA confirmed `./lifeos.sh trello rename-card` renames the test card.
- Live QA confirmed `./lifeos.sh trello move-card` moves the test card to the open `Done` list.
- Live QA confirmed `./lifeos.sh trello sync --qa` reflects the final written Trello state.
- Added `lifeos-tools/lifeos` as the stable global command wrapper.
- Added `lifeos-tools/` to `PATH` from `path.sh`.
- Added `lifeos-tools/AGENT.md` with agent-facing usage notes.
- Symlinked `lifeos-tools/AGENT.md` into the local LifeOS vault at `runbooks/lifeos-tools.md`.
- Confirmed Google Cloud setup: Calendar API enabled, OAuth consent configured, desktop app credentials downloaded.
- Stored Calendar client credentials at `GOOGLE_CALENDAR_CREDENTIALS_PATH`.
- Added `lifeos-tools/google-calendar-auth.py` as the small OAuth/token helper.
- Implemented `lifeos calendar auth`.
- Stored generated Calendar token data at `GOOGLE_CALENDAR_TOKEN_PATH`.
- Implemented Calendar access-token refresh from the stored refresh token.
- Implemented `lifeos calendar list-calendars`.
- Defined initial Calendar Markdown output shape.
- Implemented `lifeos calendar sync`, including `--qa` and `--output FILE`.
- QA confirmed `lifeos calendar auth` writes ignored `google-token.json`.
- QA confirmed `lifeos calendar list-calendars` can read available calendars.
- QA confirmed `lifeos calendar sync --qa` writes ignored `calendar-qa.md`.
- QA confirmed `lifeos calendar sync` writes `$LIFEOS_VAULT_PATH/sources/calendar.md`.
- QA confirmed `lifeos sync` refreshes both Trello and Calendar snapshots.
- Configured Calendar sync for the primary calendar plus selected work, community, shared, imported, and group calendars.
- Changed default Calendar snapshot to one combined date-grouped agenda across all synced calendars.
- Added Calendar event-line labels so each event identifies its source calendar.
- Added inline Calendar event locations.
- Added direct Calendar meeting/conference links when provided by the API.
- Added cleaned bounded Calendar description blocks with truncation.
- Added reliable duplicate-event merging with combined calendar labels.
- Added inline summary/location whitespace normalization for imported calendars.
- QA confirmed `lifeos calendar sync --qa` renders all configured calendars.
- QA confirmed `lifeos calendar sync` writes the multi-calendar snapshot to `$LIFEOS_VAULT_PATH/sources/calendar.md`.
- Added fixture coverage for one-day all-day, multi-day all-day, normal timed, cross-midnight timed, multi-calendar same-date, location, plain description, HTML description, long truncated description, meeting/RSVP links, and empty-calendar Calendar cases.
- Fixed Calendar rendering so all-day events honor Google Calendar's inclusive `start.date` and exclusive `end.date`.
- Fixed Calendar rendering so multi-day all-day events appear under every blocked date with continuation metadata.
- Fixed Calendar rendering so timed events crossing midnight appear under every affected date.
- QA confirmed the Houston multi-day event appears on June 27 in both `calendar-qa.md` and `$LIFEOS_VAULT_PATH/sources/calendar.md`.
- Captured Calendar write assessment: keep current sync read-only, avoid broad edits/deletes, and consider future create-only reminder support on a dedicated writable calendar.
- Added a second shared Trello logistics board to the local synced board list.
- QA confirmed `lifeos trello sync --qa` renders both the Life board and the shared logistics board.
- QA confirmed `lifeos trello sync` writes the multi-board snapshot to `$LIFEOS_VAULT_PATH/sources/trello.md`.
- Updated `lifeos-tools/AGENT.md` so agents know to use `list-boards`, `list-lists BOARD_ID`, and `--board BOARD_ID` for non-default board writes.
