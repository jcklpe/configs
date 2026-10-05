# LifeOS Trello Checklists — To Do
Concept: [lifeos-trello-checklists.md](lifeos-trello-checklists.md).

## Current State
- 2026-10-05: commands, snapshot rendering, offline tests, and docs built; live round trip passed after one fix (below).

## To Do
- [x] Dry-run default: no. Checklist writes are direct, matching every other Trello write; approval belongs to the calling workflow (decided 2026-10-05 when Aslan said to proceed).
- [x] Render checklists in `trello sync`: each non-empty checklist lists its items under the card as `- [x]` / `- [ ]` in Trello position order; the existing `| checklists: Name 1/3` progress stays on the card line. The sync already fetched `checklists=all`, so no new API call.
- [x] `trello add-checklist --card CARD --name NAME [--item TEXT]...`
- [x] `trello add-checklist-item --card CARD --checklist NAME_OR_ID --text TEXT [--text TEXT]...`
- [x] `trello check-item` / `uncheck-item --card CARD --item NAME_OR_ID [--checklist NAME_OR_ID]`. Ambiguous or missing names fail, list candidates, and write nothing.
- [x] Offline tests: `tests/test-trello-checklists.sh` (stubbed API) and new cases in `tests/test-trello-renderers.sh`. Mutation-checked: removing the ambiguity check, forcing `complete` on uncheck, and hardcoding `Snoozed` each fail a test.
- [x] `lifeos help`, README, and the `lifeos-trello` skill.
- [x] 2026-10-05: live round trip on a real card: `add-checklist` with an item, `add-checklist-item`, `check-item`, `uncheck-item --checklist`, each confirmed in `sync` output (progress 1/2, then 0/2, items rendered with state). Left the checklist in place as real sub-tasks.

## Found in use (2026-10-05)
- [x] `add-checklist` failed live with a 400: `POST /checklists` rejects a card short link in `idCard`, though other card endpoints accept one. It now resolves the reference to the full card ID first (`_trello_card_id`), and the stubbed test asserts the full ID is sent.
- [x] The `start: MISSING` marker only checked a list literally named `Snoozed`, so a second board with a differently named snooze list got no warning. Added `TRELLO_SNOOZE_LISTS` (comma-separated, default `Snoozed`), documented in `.env.example` and the skill, with renderer tests.

## Ready For Human QA
- None yet.

## Done
- [x] Spike opened (2026-10-05).
