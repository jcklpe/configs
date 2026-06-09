# LifeOS Tools V2

Status: scratch spike. This is a parking lot for future LifeOS tooling ideas after the Trello, Calendar, Gmail, and Drive v1 work is closed.

Companion to-do: `docs/scratch/lifeos-tools-v2.todo.md`.

## Purpose

Preserve useful next-step ideas without keeping the v1 spike docs open forever. Nothing here is committed product direction. Treat this as a future planning surface for work that may earn its own active spike later.

The v1 baseline is:

- `lifeos` is the stable local CLI entrypoint.
- Trello sync and explicit Trello writes work.
- Google Calendar sync is read-only and combined across selected calendars.
- Gmail snapshots work across configured Google account aliases.
- Drive search/list/meta/read is on-demand and read-only.
- Secrets, OAuth credentials, tokens, QA outputs, and generated private snapshots stay ignored or outside git.

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

Calendar should stay read-only by default. Calendar writes have more blast radius than Trello writes because events can involve guests, shared calendars, imported calendars, recurring events, and notification side effects.

Potential improvements:

- Add a read-only `calendar find` command that returns calendar ID, event ID, title, start/end, and link.
- Add access-role visibility so writable/read-only calendars are obvious.
- Decide whether to create a dedicated writable `LifeOS Reminders` calendar.
- If Calendar writes are added, start with create-only reminder events on that dedicated calendar.
- Require preview before any Calendar write.
- Never create guest events or modify attendee lists from this tool.
- Avoid broad Calendar edit/delete commands across arbitrary synced calendars.
- Decide whether generated Calendar snapshots should include event IDs or keep IDs behind lookup commands.
- Add filtering controls only if the configured calendar set becomes noisy.

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
- Calendar: sync, list calendars, find events.
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
- Dedicated LifeOS Calendar reminder creation.
- Drive read expansion.
- LifeOS setup helper.
- Agent callable wrapper.
