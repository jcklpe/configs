# LifeOS Trello Checklists — To Do
Concept: [lifeos-trello-checklists.md](lifeos-trello-checklists.md).

## Current State
- 2026-10-05: commands, snapshot rendering, offline tests, and docs built. Full offline suite green. Live round trip not yet run.

## To Do
- [x] Dry-run default: no. Checklist writes are direct, matching every other Trello write; approval belongs to the calling workflow (decided 2026-10-05 when Aslan said to proceed).
- [x] Render checklists in `trello sync`: each non-empty checklist lists its items under the card as `- [x]` / `- [ ]` in Trello position order; the existing `| checklists: Name 1/3` progress stays on the card line. The sync already fetched `checklists=all`, so no new API call.
- [x] `trello add-checklist --card CARD --name NAME [--item TEXT]...`
- [x] `trello add-checklist-item --card CARD --checklist NAME_OR_ID --text TEXT [--text TEXT]...`
- [x] `trello check-item` / `uncheck-item --card CARD --item NAME_OR_ID [--checklist NAME_OR_ID]`. Ambiguous or missing names fail, list candidates, and write nothing.
- [x] Offline tests: `tests/test-trello-checklists.sh` (stubbed API) and new cases in `tests/test-trello-renderers.sh`. Mutation-checked: removing the ambiguity check, forcing `complete` on uncheck, and hardcoding `Snoozed` each fail a test.
- [x] `lifeos help`, README, and the `lifeos-trello` skill.
- [ ] Live round trip on a real card: create a checklist, add an item, tick it, untick it, confirm with `sync`.

## Found in use (2026-10-05)
- [x] The `start: MISSING` marker only checked a list literally named `Snoozed`, so a second board with a differently named snooze list got no warning. Added `TRELLO_SNOOZE_LISTS` (comma-separated, default `Snoozed`), documented in `.env.example` and the skill, with renderer tests.

## Ready For Human QA
- None yet.

## Done
- [x] Spike opened (2026-10-05).
