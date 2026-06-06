# LifeOS Tools

Small local helpers for pulling live Trello and Google Calendar data into the private LifeOS vault as Markdown.

The vault and real secrets are local-only. This folder commits public-safe scripts and fake example files.

## Setup

Copy the example env file and fill in local values:

```sh
cp lifeos-tools/.env.example lifeos-tools/.env
```

Required local tools:

- `bash`
- `curl`
- `jq`
- `python3`

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

## Secrets

Real files such as `.env`, `google-token.json`, and OAuth credential JSON are ignored by git. Keep fake `.example` files tracked beside them.

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
lifeos calendar auth
lifeos calendar list-calendars
lifeos calendar sync
lifeos calendar sync --qa
lifeos sync
```

Agent-facing usage notes live in `lifeos-tools/AGENT.md`. On this machine, the LifeOS vault has a local symlink at `runbooks/lifeos-tools.md` pointing back to that tracked file.

To recreate that symlink on a configured machine:

```sh
. ~/configs/lifeos-tools/.env
mkdir -p "$LIFEOS_VAULT_PATH/runbooks"
ln -sf "$HOME/configs/lifeos-tools/AGENT.md" "$LIFEOS_VAULT_PATH/runbooks/lifeos-tools.md"
```

Google Calendar auth/list/sync is implemented. `google-credentials.json` stores the downloaded desktop-app OAuth client, and `google-token.json` stores generated access/refresh token data. Both real files are ignored; fake examples are tracked beside them.

Calendar sync currently uses `GOOGLE_CALENDAR_IDS`, with `primary` as the default. `lifeos calendar sync` writes to `$LIFEOS_VAULT_PATH/sources/calendar.md`; `lifeos calendar sync --qa` writes an ignored local snapshot to `lifeos-tools/calendar-qa.md`.

Trello sync currently includes open-list cards with names, URLs, due dates, labels, checklist progress, descriptions, and comments.

Trello write commands require `TRELLO_WRITE_TOKEN` in `.env`. Sync remains read-only and uses `TRELLO_TOKEN`.

Recommended write QA flow:

```sh
lifeos trello list-lists
lifeos trello sync --qa
lifeos trello add-card --list "On Deck" --name "LifeOS write test" --desc "Temporary test card"
lifeos trello sync --qa
```

`--qa` writes a gitignored local snapshot to `lifeos-tools/trello-qa.md`. Use the created card URL from command output or from that QA snapshot for move/rename/comment/description tests, then move it to `Done` when finished.
