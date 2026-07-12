---
name: lifeos-gmail
description: "Use when syncing bounded read-only Gmail snapshots through the lifeos CLI (lifeos gmail sync). Inbox-only, 30-day-bounded, read-only — never send, reply, archive, delete, label, or mark read. Uses the shared Google account aliases (set up via lifeos-cli)."
---

# LifeOS Gmail
## Local Precedence
If the current repo already has `lifeos-tools/skills/lifeos-gmail/SKILL.md`, read and follow the repo-local skill first. Treat this as fallback seed material.

Gmail uses the shared Google account-alias system — set up aliases with `lifeos google accounts` / `lifeos google auth ALIAS` (see `lifeos-cli`).

## Sync
```sh
lifeos gmail sync ALIAS
lifeos gmail sync --all
```

Writes bounded read-only snapshots into `$LIFEOS_VAULT_PATH/sources/gmail/`, or, with `--qa`, into `~/configs/lifeos-tools/qa/gmail-qa/` (gitignored) for local inspection.

Sync is inbox-only and bounded: the default per-account query is `in:inbox newer_than:30d -label:Newsletters`. Archived mail, mail older than 30 days, and anything labeled `Newsletters` are excluded by design. Per-account queries live in the gitignored `google-accounts.json`.

## Safety
Gmail snapshots are generated context, not a mailbox control surface. Do not send, reply, archive, delete, label, or mark messages read/unread with `lifeos`. Gmail is read-only; do not add Gmail write commands.
