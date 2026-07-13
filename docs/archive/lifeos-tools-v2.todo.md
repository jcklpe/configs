# LifeOS Tools V2 To-Do
Status: **archived 2026-07-13.** The Trello Task Chains / `supersede` theme shipped and passed human QA. Later `calendar find` also shipped. Remaining candidate work was moved to [../scratch/future-ideas.md](../scratch/future-ideas.md#lifeos-tools-v2-future-ideas).

Conceptual doc: `docs/archive/lifeos-tools-v2.md`.

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
- Moved to [../scratch/future-ideas.md](../scratch/future-ideas.md#lifeos-tools-v2-future-ideas). Promote one concrete theme into a new active spike when actual use shows it is worth implementing.

Calendar writes shipped (`create-event` / `update-event`, attendees, allowlist, dry-run, `--series`). See `docs/decisions/0002-lifeos-calendar-writes.md`. Earlier ideas about a dedicated `LifeOS Reminders` calendar, access-role visibility, and "keep writes create-only" are obsolete.

## Not Now
- Do not add Gmail mutations.
- Do not add Drive-wide cloning or recursive indexing.
- Do not add `calendar delete-event`, and do not relax the writable-calendar allowlist or the `--notify`-gated email-out. (Calendar create/update are now allowed within those bounds; see `docs/decisions/0002-lifeos-calendar-writes.md`.)
- Do not replace the CLI with MCP/plugin tooling.

## Done Since Task Chains
- [x] Added read-only `lifeos calendar find QUERY` for event ID lookup before `update-event`. It searches configured calendars over the normal sync window by default, supports `--from`, `--to`, `--calendar`, and `--json`, and prints calendar/event IDs plus start/end/link details. Validation: `bash -n lifeos-tools/lifeos.sh`, calendar render fixtures, and calendar find formatter fixture.
