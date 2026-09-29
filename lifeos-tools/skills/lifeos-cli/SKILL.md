---
name: lifeos-cli
description: "Use when starting to operate the lifeos CLI, running lifeos doctor, or setting up Google or Microsoft account auth — the entry point and cross-cutting rules for the LifeOS source-sync and write tooling. Points to the per-service skills for Trello, Google Calendar/Gmail/Drive/Docs, Microsoft 365, GitHub, Slack, Odoo, and other implemented services."
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
- **`lifeos-gmail`** — bounded Gmail snapshots, plus dry-run-gated archive, unarchive, and user-label changes (no delete or send).
- **`lifeos-drive`** — on-demand Google Drive reads and the dry-run doc import (creating a Doc).
- **`lifeos-docs`** — editing a Google Doc that already exists: one exact replacement, dry-run by default, revision-guarded.
- **`lifeos-m365`** — delegated Microsoft 365 mail reads, folder listing, and dry-run-gated archive and folder moves (no delete or send), plus gated calendar and Outlook contact reads/writes.
- **`lifeos-odoo`** — bounded Odoo Project discovery and task reads through account aliases.
- **`lifeos-slack`** — act in Slack as the user's own account (user OAuth token): post, reply, direct message, read threads, and read or write Slack Lists items, all dry-run first with identity check and readback; `lifeos slack sync` snapshots configured Lists into `sources/slack/`.
- **`lifeos-github`** — snapshots of configured repos (issues, PRs, Discussions, Projects v2 boards) into `sources/github/`, plus gated `create-issue` and board `move-card` writes.
- **`lifeos-resume`** — render a Markdown resume to a themed PDF.

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
lifeos google auth ALIAS --docs-write  # additionally authorize bounded tools to edit existing native Google Docs
lifeos google auth ALIAS --docs-comment  # additionally grant the full Drive scope so lifeos docs comment can comment on Docs
```

Alias config lives in the gitignored `google-accounts.json` (copy `google-accounts.example.json`). Each alias carries its own Gmail/Drive settings and token file.

`--docs-write` grants the token the Google Docs write scope through incremental authorization. It grants capability only; it does not authorize an edit. The specific tool and workflow performing a write must still be bounded, dry-run-first, and explicitly approved. The bounded editor is **`lifeos docs replace-once`** (dry-run by default, revision-guarded, one exact replacement) — see the `lifeos-docs` skill.

## Microsoft 365 Account Setup
Microsoft 365 uses a separate ignored `m365-accounts.json` and per-alias token cache. Copy `m365-accounts.example.json`, configure the registered public-client application and enabled services, then run:

```sh
lifeos setup
lifeos m365 accounts
lifeos m365 auth ALIAS
lifeos m365 profile ALIAS
```

See `lifeos-m365` for the delegated permission boundary and write-safety model.

## Odoo Account Setup
Odoo uses an ignored `odoo-accounts.json` and API keys supplied through environment variables named by each alias. Copy the example, configure the database routing fields, and set `ODOO_API_KEY` in the ignored `lifeos-tools/secrets/.env` file. Use a different variable name only when configuring multiple aliases with separate keys. Then run:

```sh
lifeos odoo accounts
lifeos doctor
lifeos odoo projects list ALIAS
```

See `lifeos-odoo` for the plan/API boundary and supported read commands.

## Snapshot And QA Pattern
Most `sync` commands write a snapshot into `$LIFEOS_VAULT_PATH/sources/`. Passing `--qa` instead writes a local copy under `~/configs/lifeos-tools/qa/` (gitignored) for inspection without touching the vault. After any write, re-run that service's `sync` to refresh the snapshot.

## Cross-Cutting Safety
- Do not print or inspect `~/configs/lifeos-tools/secrets/.env`, Google or Microsoft token files, API keys, `google-accounts.json`, `m365-accounts.json`, or `odoo-accounts.json`.
- Actions that touch real people or public state are gated per service — calendar `--notify` sends live invites, and Open Austin writes are handled through the public org repo. See the service skills.
- Per-service safety notes live in each service skill.

## Changing A Command's Behavior
Vault skills that rely on a specific `lifeos` behavior list it in an `assumes:` frontmatter field (for example `- lifeos trello sync writes sources/trello.md`). When a command's output, path, or capabilities change, search the vault's skills for `assumes:` lines and body text that mention the command, and flag any that describe the old behavior so they can be updated in the vault.
