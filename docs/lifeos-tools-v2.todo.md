# LifeOS Tools V2 To-Do
Status: **active.** The Trello Task Chains / `supersede` theme is **shipped and human-QA'd**
(section below). All other items remain candidate/parking-lot work, not active.

Conceptual doc: `docs/lifeos-tools-v2.md`.

## Shipped: Trello Task Chains (`supersede` + `chain`)
Live smoke test passed (LifeOS agent, real Trello board, 2026-06-25). In scope for this
iteration, all complete:

- [x] Write feasibility/design notes (conceptual doc "Active Theme" section).
- [x] `_trello_supersede` — `--from`/`--to`, pre-flight both cards, write successor back-link
  first then predecessor forward-link, idempotent skip if link already present, loud `PARTIAL:`
  on second-write failure.
- [x] `supersede --create` variant — create successor via the `add-card` path (`--list`,
  `--name`, `--board`, `--desc`/`--desc-file`), capture new id, then link.
- [x] `_trello_chain` — walk back to head then forward to tail, print ordered chain, mark the
  queried card, `--json` output, cycle/hop guard.
- [x] Helpers: `_trello_link_comment` / `_trello_link_target` / `_trello_write_link` parse and
  write the `Continues in:` / `Continues from:` marker comments.
- [x] Wire both into the `trello)` dispatcher and the `_usage` block.
- [x] Update `lifeos-tools/README.md` and `lifeos-tools/AGENT.md` (Trello Writes section + the
  "prefer comments" / no-dry-run caveats).

Validation done (offline, no live writes):

- [x] `bash -n lifeos-tools/lifeos.sh` — syntax clean.
- [x] Arg-parsing / error-path checks (missing flags, `--create`+`--to`, `--list` without
  `--create`, unknown options) — all reject before any network call.
- [x] Stubbed-network unit tests: `chain` walks back+forward from a middle card, `--json` shape,
  single-card "no links" case; `supersede` happy path issues exactly two writes (successor
  back-link first, predecessor forward-link second), idempotent re-run skips both, partial
  failure prints `PARTIAL:`, pre-flight failure writes nothing.

Human QA:

- [x] Live smoke test against a real Trello board via the LifeOS agent (2026-06-25): `supersede`
  writes the `🔗 Continues in:` / `🔗 Continues from:` comments on the correct cards, `chain`
  prints the chain from any member, idempotent re-run adds no duplicates, and `supersede --create`
  creates and links the successor. Confirmed working.

Out of scope this iteration (parking lot; pull in only on request): move predecessor to Done
list, `--dry-run`/preview, auto-`sync` after write, vault-side writes.

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
