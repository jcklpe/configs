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
- For Calendar, consider read-only `calendar find` (event ID lookup to pair with the shipped writes). Most useful remaining calendar item.
- For Calendar, decide whether a successful write should auto-run `calendar sync`.
- For Calendar, decide whether snapshots should expose event IDs inline or keep them behind `calendar find`.

Calendar writes shipped (`create-event` / `update-event`, attendees, allowlist, dry-run, `--series`). See `docs/decisions/0002-lifeos-calendar-writes.md`. These earlier items are now obsolete: dedicated `LifeOS Reminders` calendar (superseded by the writable-calendar allowlist), access-role visibility (already in `list-calendars`), and "keep writes create-only" (deliberately reversed).
- For Gmail, decide whether `lifeos sync` should include Gmail or keep it manual.
- For Gmail, add fixture coverage for truncation and multiple recipients if renderer work continues.
- For Drive, consider explicit `--max-*` controls.
- For Drive, consider configured folder aliases if repeated searches are clumsy.
- For setup, add a helper for creating/updating the LifeOS vault runbook symlink after `.env` is configured.
- For agent exposure, decide whether a callable wrapper is actually needed or whether CLI access is enough.

## Not Now

- Do not add Gmail mutations.
- Do not add Drive-wide cloning or recursive indexing.
- Do not add `calendar delete-event`, and do not relax the writable-calendar allowlist or the `--notify`-gated email-out. (Calendar create/update are now allowed within those bounds; see `docs/decisions/0002-lifeos-calendar-writes.md`.)
- Do not replace the CLI with MCP/plugin tooling.
