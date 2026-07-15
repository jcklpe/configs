---
name: lifeos-cli
description: "Use when starting to operate the lifeos CLI, running lifeos doctor, or setting up Google or Microsoft account auth — the entry point and cross-cutting rules for the LifeOS source-sync and write tooling. Points to the per-service skills for Trello, Google Calendar/Gmail/Drive, Microsoft 365, Open Austin, and other implemented services."
---

# LifeOS CLI
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-cli/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

Use the local `lifeos` command to refresh LifeOS source context and make deliberate, bounded writes to Trello, Google Calendar, and Open Austin GitHub. This is the entry point; per-service detail lives in the service skills below.

## Core Rule
Generated source snapshots (`sources/trello.md`, `sources/calendar.md`, and the rest) are context, not write-back databases. Read them to understand external state; never edit them to change the external system. Use explicit `lifeos <service> ...` commands for writes, then refresh the snapshot.

## Service Skills
- **`lifeos-trello`** — Trello reads, writes, and task-chain links.
- **`lifeos-calendar`** — Google Calendar reads/writes, attendee resolution, availability reading.
- **`lifeos-gmail`** — bounded read-only Gmail snapshots.
- **`lifeos-drive`** — on-demand Google Drive reads and the dry-run doc import.
- **`lifeos-m365`** — delegated Microsoft 365 mail reads plus gated calendar and Outlook contact reads/writes.
- **`lifeos-open-austin`** — Open Austin GitHub snapshot and issue creation.

## Health Check
```sh
lifeos doctor
```
Checks `.env`, the required commands (`curl`, `jq`, `python3`), the vault path, and per-service credentials.

## Google Account Setup (Gmail and Drive)
Gmail and Drive share an account-alias system. (Google Calendar has its own auth — see `lifeos-calendar`.)

```sh
lifeos google accounts        # list configured account aliases
lifeos google auth ALIAS      # authorize an alias
```

Alias config lives in the gitignored `google-accounts.json` (copy `google-accounts.example.json`). Each alias carries its own Gmail/Drive settings and token file.

## Microsoft 365 Account Setup
Microsoft 365 uses a separate ignored `m365-accounts.json` and per-alias token cache. Copy `m365-accounts.example.json`, configure the registered public-client application and enabled services, then run:

```sh
lifeos setup
lifeos m365 accounts
lifeos m365 auth ALIAS
lifeos m365 profile ALIAS
```

See `lifeos-m365` for the delegated permission boundary and write-safety model.

## Snapshot And QA Pattern
Most `sync` commands write a snapshot into `$LIFEOS_VAULT_PATH/sources/`. Passing `--qa` instead writes a local copy under `~/configs/lifeos-tools/qa/` (gitignored) for inspection without touching the vault. After any write, re-run that service's `sync` to refresh the snapshot.

## Cross-Cutting Safety
- Do not print or inspect `~/configs/lifeos-tools/secrets/.env`, Google or Microsoft token files, `google-accounts.json`, or `m365-accounts.json`.
- Actions that touch real people or public state are gated per service — calendar `--notify` sends live invites, Open Austin issue creation is public. See the service skills.
- Per-service safety notes live in each service skill.
