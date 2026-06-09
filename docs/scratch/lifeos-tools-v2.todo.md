# LifeOS Tools V2 To-Do

Status: scratch to-do. Not active work.

Conceptual doc: `docs/scratch/lifeos-tools-v2.md`.

## Candidate Work Items

- Decide which v2 theme, if any, should become the next active spike.
- For Trello write safety, define the exact output shape for `--dry-run` and before/after state.
- For Trello write safety, add stale-card re-fetch before mutation.
- For Trello write safety, decide whether writes should auto-sync afterward.
- For Trello write expansion, consider `set-due`.
- For Trello write expansion, consider `archive-card`; do not add hard delete.
- For Calendar, decide whether to create a dedicated writable `LifeOS Reminders` calendar.
- For Calendar, consider read-only `calendar find`.
- For Calendar, add access-role visibility before any write work.
- For Calendar, keep future writes create-only unless a separate spike justifies broader behavior.
- For Gmail, decide whether `lifeos sync` should include Gmail or keep it manual.
- For Gmail, add fixture coverage for truncation and multiple recipients if renderer work continues.
- For Drive, consider explicit `--max-*` controls.
- For Drive, consider configured folder aliases if repeated searches are clumsy.
- For setup, add a helper for creating/updating the LifeOS vault runbook symlink after `.env` is configured.
- For agent exposure, decide whether a callable wrapper is actually needed or whether CLI access is enough.

## Not Now

- Do not add Gmail mutations.
- Do not add Drive-wide cloning or recursive indexing.
- Do not add broad Google Calendar edits/deletes.
- Do not replace the CLI with MCP/plugin tooling.
