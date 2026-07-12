# LifeOS Tools V2
Status: **active spike.** Promoted from scratch on 2026-06-25 to carry one concrete theme:
**Trello Task Chains and the `supersede` command** (see the section below). That theme is now
**shipped and human-QA'd** (live smoke test via the LifeOS agent, 2026-06-25); the spike stays
open as the home for the remaining parking-lot v2 ideas. Those stay out of scope until the user
pulls one in.

Companion to-do: `docs/active-spikes/lifeos-tools-v2.todo.md`.

## Purpose
Preserve useful next-step ideas without keeping the v1 spike docs open forever. Most of this
doc is not committed product direction — treat it as a planning surface. The active theme is
the Task Chains work below; everything else accretes here until it earns implementation.

The v1 baseline is:

- `lifeos` is the stable local CLI entrypoint.
- Trello sync and explicit Trello writes work.
- Google Calendar sync is read-only and combined across selected calendars.
- Google Calendar **writes** now exist: `create-event` / `update-event` with attendee invites (dry-run by default, writable-calendar allowlist, no delete). See `docs/decisions/0002-lifeos-calendar-writes.md`.
- A `people` command group resolves attendee names (local alias map → Google People API).
- Gmail snapshots work across configured Google account aliases.
- Drive search/list/meta/read is on-demand and read-only.
- Secrets, OAuth credentials, tokens, QA outputs, and generated private snapshots stay ignored or outside git.

## Active Theme: Trello Task Chains and `supersede`
### The convention this serves
In the LifeOS vault, multi-step work is modeled as a **chain of linked Trello cards** rather
than one card that mutates over its whole life. When work hits a **gate** — a wait on an
external party, a future date, a handoff, or a substantial prerequisite — the current card is
closed/moved and a **successor** card is created to carry the next leg. The discipline that
makes a chain navigable is **bidirectional links**: the predecessor names its successor, and
the successor names its predecessor.

Today those links are added by hand as comments. That is error-prone — a half-linked chain
has already shipped once (predecessor pointed forward, successor had no back-pointer). The
`supersede` command exists to make the bidirectional link a single mechanical operation so the
invariant cannot be half-applied.

**Boundary:** this is purely mechanical link-writing. The *judgment* of when to split a card
at a gate stays with the user and the vault agents. The CLI never decides to supersede; it only
executes a supersede the human/agent has already decided on. It writes to Trello only — no vault
files, no credentials in the vault (those stay in `lifeos-tools/.env`, per
`docs/decisions/0001-secrets-and-local-env.md`).

### Where the links live: comments, not the description
Decision: **the link record is a labeled comment**, not a description stanza.

- `comment` is append-only (`POST /cards/{id}/actions/comments`) — no read-modify-write, so two
  near-simultaneous supersedes can't clobber each other. `set-desc` is a **full overwrite**
  (`PUT desc=`); editing the description to add a line means GET → append → PUT, which races
  against any other description edit. The v2 notes already flag description edits as needing a
  safer section-aware approach (below), and the `lifeos-trello` skill already says "prefer comments for
  additive notes."
- A supersede is a point-in-time *event* ("work continued elsewhere as of this moment"). A
  timestamped, immutable comment is the semantically honest home for that, the same way a git
  commit records a transition rather than mutating a mutable field.
- The known downside — comments scroll away in a busy card — is mitigated by a **stable marker
  line** the `chain` command can parse back out, and by the fact that `trello sync` already
  renders comments into the vault snapshot.

Link comment format (stable, human-readable, machine-parseable):

```
🔗 Continues in: <successor card URL>      # written on the predecessor
🔗 Continues from: <predecessor card URL>  # written on the successor
```

`chain` matches on the literal phrases `Continues in:` / `Continues from:` and extracts the
trailing card id (URL or bare id, via the existing `_card_ref`). The full URL is stored so a
human can click it.

### Atomic-ish writes and partial-failure behavior
Two REST writes can't be a true transaction, so the command is ordered and idempotent instead:

1. **Pre-flight both cards** with a cheap `GET` (fetch name + url). A typo'd `--from`/`--to`
   fails here, before *any* write — most partial-failure cases never start.
2. **Write the successor's back-link first** (`Continues from:`). If this fails, nothing else is
   touched; the predecessor is never told it has a successor. Abort cleanly.
3. **Write the predecessor's forward-link second** (`Continues in:`). The forward link is the one
   a human follows down the chain, so it is written last: we never claim "this card continues in
   X" until X already points back. If *this* write fails after step 2 succeeded, report a loud
   `PARTIAL:` error naming the back-link that landed and the exact remediation (re-run, or add the
   one missing line manually).
4. **Idempotency:** before writing each link, check the target card's existing comments for a
   marker already pointing at the counterpart; skip if present. So re-running after a partial
   failure simply completes the missing side rather than duplicating links.

### Traversal: `trello chain`
`chain --card <id|url>` reconstructs and prints the whole chain from any member card:

- Walk **backward** following `Continues from:` to the head, then walk **forward** following
  `Continues in:` to the tail, collecting the ordered list.
- Cycle/runaway guarded (visited-set + hard hop cap) so a malformed chain can't loop forever.
- Prints each node as `name + url`, marks the queried card ("you are here"), and offers `--json`
  for later tooling. Reuses the most-recent matching marker per card, so a card re-superseded
  more than once follows its latest link.

### Command surface
```
lifeos trello supersede --from CARD --to CARD [--board BOARD_ID]
lifeos trello supersede --create --from CARD --list LIST --name NAME \
    [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
lifeos trello chain --card CARD [--json]
```

`supersede --create` makes the successor (same path as `add-card`) and links it in one step,
capturing the new card's id from the create response. `supersede` reuses `_trello_write` /
`_trello_get` / `_card_ref` / `_trello_resolve_list_id` and slots into the existing
`trello)` dispatcher and usage block — no new auth, no new config.

**Explicitly out of scope for this iteration** (the user may pull these in later): moving the
predecessor to a Done list (stays a separate `move-card` step), `--dry-run`/preview output,
auto-`sync` after write, and any vault-side writing. Those live in the parking-lot sections
below.

## Trello V2 Ideas
Trello writes work, but the safer agent-facing version would be more explicit about previews and results.

Potential improvements:

- Add `--dry-run` or `--preview` to write commands.
- Return before/after state for write commands.
- Re-fetch card state before edits to reduce stale-snapshot risk.
- Decide whether successful writes should auto-run `trello sync`.
- Add `set-due`.
- Add `archive-card`; do not add hard delete.
- Make description edits safer with a diff preview or section-aware replacement.
- If bulk edits are added, require a proposed change plan before writing.

The current generated Trello snapshot is not a write-back database. Keep that boundary.

## Calendar V2 Ideas
**Mostly shipped.** Calendar writes now exist with a tool-enforced safety model; see `docs/decisions/0002-lifeos-calendar-writes.md`. The conservative assumptions this section originally held — "stay read-only by default," "create-only on a dedicated reminders calendar," "never create guest events or modify attendee lists" — were deliberately retired. The decision record is authoritative if this scratch note drifts.

Done:

- Writes via `create-event` / `update-event`, dry-run by default (preview before write).
- Writable-calendar allowlist (`LIFEOS_CALENDAR_WRITABLE_IDS`) instead of a single dedicated reminders calendar.
- Guest events and attendee-list edits, with no email-out unless `--notify`.
- Single-occurrence vs `--series` recurring edits; `--recurrence` for creating series.
- Attendee name resolution (alias map → People API) with interactive disambiguation via `people resolve` / `add-alias`.
- Access role is already visible in `list-calendars` output.

Still open:

- Add a read-only `calendar find` command that returns calendar ID, event ID, title, start/end, and link, so the agent does not have to grep `sources/calendar.md` for an event ID before `update-event`. This is now the most useful next calendar item.
- Decide whether generated Calendar snapshots should include event IDs inline or keep IDs behind a `calendar find` lookup.
- Decide whether to auto-run `calendar sync` after a successful write (currently manual).
- Add filtering controls only if the configured calendar set becomes noisy.
- Consider richer time parsing / natural-language start times if the explicit `YYYY-MM-DDTHH:MM` form proves clumsy in practice.

## Gmail V2 Ideas
Gmail snapshots are intentionally bounded and read-only. Email is sensitive and noisy, so the default should stay conservative.

Potential improvements:

- Decide whether `lifeos sync` should include Gmail or whether Gmail should remain a deliberate manual sync.
- Add explicit per-account query tuning after real use shows which inbox slices are useful.
- Add raw metadata or JSON QA/debug output only if Markdown snapshots are insufficient.
- Add more fixture coverage for body truncation and multiple recipients.
- Consider whether generated Gmail snapshots need a combined index beyond the current account index.

Do not add Gmail mutations without a separate spike and a much higher safety bar.

## Drive V2 Ideas
Drive should remain on-demand, not a vault clone or background index.

Potential improvements:

- Add explicit `--max-*` controls for `drive read` if the default caps are not enough.
- Add richer Drive fixture coverage if renderer behavior becomes more complex.
- Add Slides read support if it becomes useful.
- Add richer Sheets extraction beyond bounded range previews.
- Add Google Docs comment reading only if LifeOS work needs it.
- Add support for configured folder aliases if repeated Drive searches become clumsy.

Do not recursively index whole Drives or generate giant Drive summaries.

## Agent Exposure V2 Ideas
The CLI is the durable boundary. MCP/plugin-style functions may be useful later, but should wrap the CLI behavior rather than becoming a separate source of truth.

Potential callable wrapper shape:

- Trello: list boards, list lists, get card, create card, move card, rename card, comment, archive card.
- Calendar: sync, list calendars, find events, create event, update event.
- People: resolve name, add alias, list aliases.
- Gmail: sync account, sync all.
- Drive: search, list folder, metadata, read file.

If this happens, keep the same safety properties:

- read-only by default
- explicit writes only
- dry-run/preview for write operations
- no token or credential exposure
- bounded outputs

## Setup / Install V2 Ideas
Potential improvements:

- Add a helper that creates or updates the LifeOS vault runbook symlink after `.env` is configured.
- Add a setup check that reports which local aliases are authenticated without printing secrets.
- Add migration notes for setting up a new machine from example files.

## Promotion Criteria
This scratch topic should become an active spike only when one concrete v2 theme is ready to implement. Do not promote everything here at once.

Good candidate active spikes:

- Trello write safety pass.
- Read-only `calendar find` (event ID lookup to pair with the shipped calendar writes).
- Drive read expansion.
- LifeOS setup helper.
- Agent callable wrapper.

(Calendar writes shipped — see `docs/decisions/0002-lifeos-calendar-writes.md`. The "dedicated LifeOS reminders calendar" candidate is superseded by the writable-calendar allowlist.)
