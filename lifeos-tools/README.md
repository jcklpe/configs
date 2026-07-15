# LifeOS Tools
Small local helpers for pulling external source data into the private LifeOS vault as Markdown.

The vault and real secrets are local-only. This folder commits public-safe scripts and fake example files.

## Setup
Copy the example env file and fill in local values:

```sh
cp lifeos-tools/secrets/.env.example lifeos-tools/secrets/.env
```

Required local tools:

- `bash`, `curl`, `jq`
- `python3` (Microsoft delegated auth also uses MSAL from the managed environment)
- `uv` — manages the Python env (`.venv`) from `pyproject.toml` + `uv.lock`
- `pandoc` + `weasyprint` — only needed for `resume render`

These are installed by the configs installer (`install-script/functions/brew-installs.sh` on mac, `dnf-installs.sh` on Fedora). Then build the Python env:

```sh
cd ~/configs/lifeos-tools
./lifeos.sh setup     # runs `uv sync` to build .venv from pyproject.toml + uv.lock
```

Add a Python dependency later with `uv add <package>` (updates `pyproject.toml` + `uv.lock`); the CLI calls the venv's python automatically, falling back to system `python3` if `.venv` is absent.

Run commands from this folder:

```sh
cd ~/configs/lifeos-tools
./lifeos.sh help
./lifeos.sh doctor
```

After shell startup loads `~/configs/path.sh`, the stable command is available from any directory:

```sh
lifeos help
lifeos doctor
```

## Layout
- `lifeos.sh` — the CLI dispatcher (bootstrap, top-level commands, and the command `case`).
- `lib/` — the implementation: feature modules (`trello.sh`, `google.sh`, `m365.sh`, `open-austin-org.sh`, `resume.sh`) over shared `common.sh`, plus render/auth/write helpers and the vendored `resume-theme/`. `lib/*.sh` is sourced; the `.py` files are invoked by path.
- `pyproject.toml` / `uv.lock` — Python env manifest + lockfile (managed by `uv`; the `.venv` is git-ignored and rebuilt by `./lifeos.sh setup`).
- `secrets/` — real secrets and their `.example` templates.
- `qa/` — `--qa` snapshot output.
- `tests/` — offline renderer tests and fixtures.

## Secrets
Real files (`.env`, Google/Microsoft token files, OAuth credential JSON, `google-accounts.json`, `m365-accounts.json`, `people-aliases.json`) live in `secrets/` and are ignored by git. Fake `.example` templates are tracked beside them in the same folder.

## Commands
```sh
lifeos help
lifeos doctor
lifeos open
lifeos context
lifeos trello list-boards
lifeos trello list-lists
lifeos trello sync
lifeos trello sync --qa
lifeos trello sync --output /tmp/trello.md
lifeos trello add-card --list "On Deck" --name "Call dentist"
lifeos trello move-card --card https://trello.com/c/abc123 --list Done
lifeos trello rename-card --card https://trello.com/c/abc123 --name "New title"
lifeos trello set-desc --card https://trello.com/c/abc123 --file /tmp/card-desc.md
lifeos trello comment --card https://trello.com/c/abc123 --text "Called today."
lifeos trello supersede --from https://trello.com/c/abc123 --to https://trello.com/c/def456
lifeos trello supersede --create --from https://trello.com/c/abc123 --list "On Deck" --name "Follow up after vendor reply"
lifeos trello chain --card https://trello.com/c/abc123
lifeos calendar auth
lifeos calendar list-calendars
lifeos calendar find "Dinner"
lifeos calendar find "Dinner" --from 2026-07-01 --to 2026-07-31 --json
lifeos calendar sync
lifeos calendar sync --qa
lifeos calendar create-event --title "Dinner" --start 2026-06-25T18:00 --attendee lindsey --execute
lifeos calendar update-event --event EVENT_ID --location "New venue" --execute
lifeos calendar update-event --event EVENT_ID --series --location "New venue" --execute
lifeos people resolve lindsey --json
lifeos people add-alias lindsey lindsey@example.com
lifeos google accounts
lifeos google auth personal
lifeos gmail sync personal --qa
lifeos gmail sync --all
lifeos drive accounts
lifeos drive search open-austin "landlord mapper"
lifeos drive meta open-austin https://docs.google.com/document/d/abc123/edit
lifeos drive read open-austin https://docs.google.com/spreadsheets/d/abc123/edit
lifeos drive import-doc open-austin /tmp/brief.html --title "Workshop brief" --folder FOLDER_ID --execute
lifeos m365 accounts
lifeos m365 auth ut
lifeos m365 profile ut
lifeos m365 mail sync ut --qa
lifeos m365 calendar list-calendars ut
lifeos m365 calendar find ut "Orientation"
lifeos m365 calendar sync ut --qa
lifeos m365 calendar create-event ut --title "Coffee" --start 2026-08-20T10:00
lifeos m365 calendar update-event ut --event EVENT_ID --location "UTA"
lifeos m365 contacts list ut
lifeos m365 contacts find ut "Name"
lifeos m365 contacts sync ut --qa
lifeos m365 contacts create ut --display-name "Name" --email name@example.com
lifeos m365 contacts update ut --contact CONTACT_ID --company "Organization"
lifeos open-austin-org path
lifeos open-austin-org sync
lifeos open-austin-org sync --qa
lifeos open-austin-org create-issue --title "Task title" --body "Context" --label infrastructure --assign-me
lifeos open-austin-org create-issue --title "Task title" --body-file /tmp/issue.md --label board --assign-me --execute
lifeos sync
```

Agent-facing usage notes live in the `lifeos-cli` skill (`lifeos-tools/skills/lifeos-cli/SKILL.md`), co-located with the tool and symlinked into `~/.claude/skills/` and `~/.codex/skills/` by the installer, so local agents get it globally.

## Microsoft 365
Microsoft 365 is a separate delegated Graph integration for bounded Inbox reads, calendar reads and gated event create/update writes, and Outlook contact reads and gated contact create/update writes. It does not send or mutate mail, expose delete commands, read the UT organization directory, or request application-wide access.

Copy the ignored account configuration and fill in the registered application's public client ID:

```sh
cp lifeos-tools/secrets/m365-accounts.example.json lifeos-tools/secrets/m365-accounts.json
lifeos setup
lifeos m365 accounts
lifeos m365 auth ut
lifeos m365 profile ut
```

Register the local application in Microsoft Entra as a public mobile/desktop client with a `http://localhost` redirect and delegated `User.Read`, `Mail.Read`, `Calendars.ReadWrite`, and `Contacts.ReadWrite` permissions. Do not create a client secret or add application permissions. Enable public-client flows if `--no-browser` device-code authorization will be used. If UT prevents app registration or consent, stop at that tenant gate instead of adding broader permissions.

Mail snapshots are read-only and bounded by the alias's days, count, and body limits. Calendar sync uses Graph calendar views over the normal LifeOS date window. Contact sync reads only the user's default Outlook Contacts folder and does not recurse through additional contact folders. Production snapshots go to `$LIFEOS_VAULT_PATH/sources/m365/`; `--qa` snapshots go to ignored `lifeos-tools/qa/m365/`.

Calendar and contact writes are dry-run by default and require `--execute`. There are no delete commands. Calendar writes are restricted to configured writable calendar IDs. Because Microsoft can send invitations or meeting updates for attendee-bearing events, those writes also require `--notify` as an explicit acknowledgement; unlike the Google API, Graph does not expose it here as a suppress-delivery switch. During contact updates, supplied email or phone values replace that complete field array. See the `lifeos-m365` skill for the full safety model.


## Open Austin Org Snapshots
`lifeos open-austin-org sync` refreshes the local Open Austin org tooling repo and copies only its generated `snapshot/` Markdown into the LifeOS vault at `$LIFEOS_VAULT_PATH/sources/open-austin-org/`.

Default repo path:

```text
$HOME/work/org
```

Override with `OPEN_AUSTIN_ORG_REPO_PATH` in `.env` if needed.

This command does not copy the full repo, `.env`, `.git`, `.github`, tools, workflows, or source scripts into LifeOS. The org repo owns GitHub API/sync behavior; LifeOS receives generated context only.

`lifeos open-austin-org sync --qa` writes to ignored `lifeos-tools/open-austin-org-qa/` instead of the vault.


### GitHub Issue Creation
`lifeos open-austin-org create-issue` creates public Open Austin GitHub issues through `gh`, but is dry-run by default. Use it when work needs to be visible in the org repo rather than only tracked privately in Trello/LifeOS.

Examples:

```sh
lifeos open-austin-org create-issue --title "Task title" --body "Context" --label infrastructure --assign-me
lifeos open-austin-org create-issue --title "Task title" --body-file /tmp/issue.md --label board --assignee jcklpe --execute
```

Options:

- `--title TEXT` is required.
- `--body TEXT` or `--body-file FILE` supplies the issue body.
- `--label LABEL` can be repeated.
- `--assign-me` resolves the current GitHub user during execution.
- `--assignee LOGIN` can be repeated.
- `--repo OWNER/REPO` overrides the default `open-austin/org`.
- `--execute` is required to create the issue. Without it, the command prints a dry-run plan.
- `--no-sync` skips the post-create LifeOS source refresh.

After a successful create, the command refreshes `sources/open-austin-org/` unless `--no-sync` is passed.

Google Calendar auth/list/sync plus event create/update is implemented. `google-credentials.json` stores the downloaded desktop-app OAuth client, and `google-token.json` stores generated access/refresh token data. Both real files are ignored; fake examples are tracked beside them. The calendar token carries the `calendar.events` (read+write) and Contacts read scopes; re-run `lifeos calendar auth` after pulling this change to re-consent, and enable the People API for the same Google project so attendee-name lookups work.

`lifeos calendar create-event` and `update-event` are **dry-run by default** and only write with `--execute`. Writes are restricted to the calendars in `LIFEOS_CALENDAR_WRITABLE_IDS` (default `primary`); there is no delete. Attendees are not emailed unless `--notify` is passed (`sendUpdates=none` by default). `--attendee VALUE` resolves in order: a literal `email@host`, then the local `people-aliases.json` map (case-insensitive short names for frequent invitees), then Google Contacts via the People API; ambiguous or unmatched People API names fail with candidates rather than guessing. Copy `people-aliases.example.json` to the ignored `people-aliases.json` to set up aliases like `lindsey`. `update-event` merges new attendees into the existing list unless `--replace-attendees` is given, and edits only the single occurrence of a recurring event unless `--series` is passed (which retargets the series master). Create recurring events with repeatable `--recurrence "RRULE:..."`. When an attendee name is ambiguous or unmatched, the write stops with candidates; `lifeos people resolve NAME --json` lists them and `lifeos people add-alias NAME EMAIL` records a pick in the gitignored `people-aliases.json`. See the `lifeos-calendar` skill for the full safety model.

Calendar sync uses comma-separated `GOOGLE_CALENDAR_IDS`, with `primary` as the default. `lifeos calendar sync` writes a combined date-grouped agenda to `$LIFEOS_VAULT_PATH/sources/calendar.md`; `lifeos calendar sync --qa` writes an ignored local snapshot to `lifeos-tools/calendar-qa.md`.

`lifeos calendar find QUERY` searches the configured calendars over the normal sync window and prints calendar ID, event ID, title, start/end, location, and link. Use it before `update-event` when you need the exact event ID. Narrow with `--from YYYY-MM-DD`, `--to YYYY-MM-DD`, `--calendar CALENDAR_ID`, or pass `--json` for machine-readable output.

Event lines include `calendar: <calendar name>`, inline `location: ...` when present, direct meeting links when available, and cleaned bounded descriptions. Multi-day all-day events and timed events crossing midnight are expanded under every affected date so agents do not mistake continuation days as free.

Descriptions for noisy calendars can be omitted via `LIFEOS_CALENDAR_NO_DESCRIPTION` in `.env` (comma-separated calendar names, matched against the calendar summary, case-insensitive). All other calendars keep their descriptions. An event shared with a high-signal calendar keeps its description. Verify exact names with `lifeos calendar list-calendars`.

Google Gmail/Drive alias config lives in ignored `google-accounts.json`, copied from tracked `google-accounts.example.json`. Each alias has its own ignored token file, such as `google-personal-token.json`.

Gmail sync is read-only and writes bounded Markdown snapshots to `$LIFEOS_VAULT_PATH/sources/gmail/`, or to ignored `lifeos-tools/gmail-qa/` when using `--qa`. The default per-account query (`in:inbox newer_than:30d -label:Newsletters`) syncs only current inbox mail from the last 30 days and excludes anything labeled `Newsletters`; archived mail is not synced.

Drive read commands are on-demand. They search/list/inspect files and can read Google Docs as text or Google Sheets as a bounded table preview. They do not clone Drive into LifeOS.

`lifeos drive import-doc` is the only Drive write path. It imports a local `.html`, `.md`, `.txt`, `.rtf`, `.doc`, or `.docx` source file as a native Google Doc. It is **dry-run by default** and only writes with `--execute`. The target account must have `"drive": { "write_enabled": true }` in ignored `google-accounts.json`; after enabling that flag, re-run `lifeos google auth ALIAS` so the token receives the `drive.file` scope.

Examples:

```sh
# preview only
lifeos drive import-doc open-austin /tmp/design-cop-brief.html --title "Design CoP ResearchOps Hackpack Workshop"

# create in a specific Drive folder
lifeos drive import-doc open-austin /tmp/design-cop-brief.html --title "Design CoP ResearchOps Hackpack Workshop" --folder FOLDER_ID --execute
```

Trello sync currently includes open-list cards with names, URLs, due dates, labels, checklist progress, descriptions, and comments.

Trello write commands require `TRELLO_WRITE_TOKEN` in `.env`. Sync remains read-only and uses `TRELLO_TOKEN`.

### Task chains: `supersede` and `chain`
Multi-step work is modeled as a chain of linked cards, not one mutating card. When work hits a
gate (a wait on someone, a future date, a handoff, a prerequisite), supersede the current card
with a successor instead of editing it forever. `supersede` writes the bidirectional link as a
pair of labeled comments — `🔗 Continues in:` on the predecessor and `🔗 Continues from:` on the
successor — in one operation, so the link can't be left half-applied:

```sh
# link two existing cards
lifeos trello supersede --from PRED_CARD --to SUCC_CARD
# create the successor and link it in one step
lifeos trello supersede --create --from PRED_CARD --list "On Deck" --name "Next leg" [--desc TEXT | --desc-file FILE]
# print the whole chain from any member card (forward + back); --json for tooling
lifeos trello chain --card ANY_CARD
```

The successor's back-link is written first and the predecessor's forward-link second; if the
second write fails it reports a loud `PARTIAL:` error. Re-running is idempotent — it only adds
whichever link is missing. `supersede` does not move the predecessor to a Done list; do that
separately with `move-card` if you want it. The judgment of *when* to split a card stays manual.

Recommended write QA flow:

```sh
lifeos trello list-lists
lifeos trello sync --qa
lifeos trello add-card --list "On Deck" --name "LifeOS write test" --desc "Temporary test card"
lifeos trello sync --qa
```

`--qa` writes a gitignored local snapshot to `lifeos-tools/trello-qa.md`. Use the created card URL from command output or from that QA snapshot for move/rename/comment/description tests, then move it to `Done` when finished.

## Validation
Run every offline renderer, formatter, pagination, body-builder, and dry-run-gate fixture:

```sh
for test in tests/test-*.sh; do bash "$test" || exit; done
```

These tests use synthetic data and do not require live Google, Microsoft, Trello, or GitHub credentials.
